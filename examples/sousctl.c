/*
 * sousctl ("sue kettle") — Local Tuya controller for Inkbird sous vide.
 *
 * Usage:
 *   sousctl [-v] [-c FILE] COMMAND [ARGS...]
 *
 *   sousctl status                   read all data points
 *   sousctl read                     read current temperature
 *   sousctl temp TEMP [TIME]         set target temperature
 *   sousctl ramp PHASE [PHASE ...]   multi-phase ramp
 *   sousctl off                      power off
 *
 * Temperature: NUMBER with optional C or F suffix (default: Celsius).
 *   Examples: 50C  122F  37.5
 *
 * Time: HH:MM, HH:MM:SS, or bare minutes.
 *   Examples: 1:30  0:45:00  45
 *
 * Each ramp PHASE is three arguments: START END TIME.
 * A hold is a ramp where START equals END.
 *
 *   sousctl -v ramp 25C 50C 30:00 50C 50C 30:00 --off
 *
 * Reads device credentials from $XDG_CONFIG_HOME/seatuya/config
 * (defaults to ~/.config/seatuya/config), INI-style:
 *
 *   [sousvide]
 *   device_id = <your device id>
 *   local_key = <your local key>
 *   ip        = <device IP or hostname>
 *   version   = 3.5
 *
 * Copyright (c) 2026, David Walther <david@clearbrookdistillery.com>
 * BSD-2-Clause
 */

#include <seatuya.h>

#include <ctype.h>
#include <math.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

/* ------------------------------------------------------------------ */
/*  Globals                                                            */
/* ------------------------------------------------------------------ */

static bool verbose = false;

static void
vlog(const char *fmt, ...)
{
	if (!verbose) return;
	time_t now = time(NULL);
	struct tm *lt = localtime(&now);
	fprintf(stderr, "[%02d:%02d:%02d] ",
	    lt->tm_hour, lt->tm_min, lt->tm_sec);
	va_list ap;
	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	va_end(ap);
}

/* ------------------------------------------------------------------ */
/*  Inkbird sous vide DPS mapping                                      */
/* ------------------------------------------------------------------ */

enum inkbird_dps {
	DPS_POWER        = 101,   /* bool: on/off                       */
	DPS_STATUS       = 102,   /* string: "working" / "stopping"     */
	DPS_TARGET_TEMP  = 103,   /* int: target temp * 10 (Celsius)    */
	DPS_CURRENT_TEMP = 104,   /* int: water temp * 10 (Celsius)     */
	DPS_TIMER        = 105,   /* int: timer duration in minutes     */
	DPS_TIME_LEFT    = 106,   /* int: remaining minutes             */
	DPS_FAULT         = 107,   /* int: fault code                    */
	DPS_TEMP_UNIT    = 108,   /* bool: true=C, false=F              */
	DPS_RECIPE       = 109,   /* int: recipe number                  */
	DPS_TEMP_CAL     = 110    /* int: calibration offset * 10       */
};

/* ------------------------------------------------------------------ */
/*  Config file reader                                                 */
/* ------------------------------------------------------------------ */

struct config {
	char device_id[128];
	char local_key[128];
	char ip[256];
	char version[8];
};

static int
read_config(const char *path, struct config *cfg)
{
	FILE *fp;
	char line[512];
	int in_section = 0;

	memset(cfg, 0, sizeof(*cfg));
	strncpy(cfg->version, "3.5", sizeof(cfg->version) - 1);

	fp = fopen(path, "r");
	if (!fp) {
		fprintf(stderr, "error: cannot open %s: ", path);
		perror(NULL);
		return -1;
	}

	while (fgets(line, sizeof(line), fp)) {
		char *nl = strchr(line, '\n');
		if (nl) *nl = '\0';
		if (line[0] == '#' || line[0] == ';' || line[0] == '\0')
			continue;
		if (line[0] == '[') {
			in_section = (strstr(line, "[sousvide]") != NULL);
			continue;
		}
		if (!in_section)
			continue;

		char *eq = strchr(line, '=');
		if (!eq) continue;
		*eq = '\0';

		char *key = line;
		while (*key == ' ' || *key == '\t') key++;
		char *ke = eq - 1;
		while (ke > key && (*ke == ' ' || *ke == '\t')) *ke-- = '\0';

		char *val = eq + 1;
		while (*val == ' ' || *val == '\t') val++;

		if (strcmp(key, "device_id") == 0)
			strncpy(cfg->device_id, val, sizeof(cfg->device_id) - 1);
		else if (strcmp(key, "local_key") == 0)
			strncpy(cfg->local_key, val, sizeof(cfg->local_key) - 1);
		else if (strcmp(key, "ip") == 0)
			strncpy(cfg->ip, val, sizeof(cfg->ip) - 1);
		else if (strcmp(key, "version") == 0)
			strncpy(cfg->version, val, sizeof(cfg->version) - 1);
	}

	fclose(fp);

	if (!cfg->device_id[0] || !cfg->local_key[0] || !cfg->ip[0]) {
		fprintf(stderr,
		    "error: missing device_id, local_key, or ip in %s\n", path);
		return -1;
	}

	return 0;
}

/* ------------------------------------------------------------------ */
/*  Helpers                                                            */
/* ------------------------------------------------------------------ */

static const char *
progname(const char *argv0)
{
	const char *p = strrchr(argv0, '/');
	return p ? p + 1 : argv0;
}

static double
c_to_f(double c) { return c * 9.0 / 5.0 + 32.0; }

static double
f_to_c(double f) { return (f - 32.0) * 5.0 / 9.0; }

/*
 * Parse a temperature string.  Accepted forms:
 *    NUMBER       — default Celsius
 *    NUMBER C / c — Celsius
 *    NUMBER F / f — Fahrenheit
 * Returns Celsius * 10 (the native DP 103/104 unit).
 * On error, sets *ok to false.
 */
static int
parse_temp(const char *s, bool *ok)
{
	char unit = 0;
	double val;

	*ok = false;
	if (!s || !*s)
		return 0;

	/* scan value + optional unit suffix */
	char tail[8] = {0};
	if (sscanf(s, "%lf%7s", &val, tail) < 1)
		return 0;

	if (tail[0]) {
		unit = (char)toupper((unsigned char)tail[0]);
		if (tail[1])
			return 0;   /* garbage after unit */
	}

	/* default unit: Celsius */
	if (unit == 0 || unit == 'C')
		*ok = true;
	else if (unit == 'F') {
		val = f_to_c(val);
		*ok = true;
	}
	else
		return 0;   /* unknown unit */

	return (int)round(val * 10.0);
}

/*
 * Parse a duration string.  Accepted forms:
 *   bare integer        — minutes
 *   HH:MM               — hours and minutes
 *   HH:MM:SS            — hours, minutes, seconds
 * Returns total seconds.  On error, sets *ok to false.
 */
static int
parse_duration(const char *s, bool *ok)
{
	int h = 0, m = 0, sec = 0;
	int n;

	*ok = false;
	if (!s || !*s)
		return 0;

	n = sscanf(s, "%d:%d:%d", &h, &m, &sec);
	if (n == 3) {
		/* HH:MM:SS — validate m/sec < 60 */
		*ok = (m >= 0 && m < 60 && sec >= 0 && sec < 60 && h >= 0);
	} else if (n == 2) {
		/* M:SS — minutes unrestricted, validate seconds */
		sec = m;
		m = h;
		h = 0;
		*ok = (m >= 0 && sec >= 0 && sec < 60);
	} else if (n == 1 && strchr(s, ':') == NULL) {
		/* bare number: minutes */
		m = h;
		h = 0;
		*ok = (m >= 0);
	} else {
		return 0;
	}

	return h * 3600 + m * 60 + sec;
}

static void
print_response(char *resp)
{
	if (resp) {
		printf("  %s\n", resp);
		tuya_free_string(resp);
	}
}

static void
set_temp(tuya_device_t *d, int target_c_x10)
{
	double c = target_c_x10 / 10.0;
	vlog("setting target %.1f C / %.1f F\n", c, c_to_f(c));
	printf("  target: %.1f C / %.1f F\n", c, c_to_f(c));
	print_response(tuya_set_value_int(d, DPS_TARGET_TEMP, target_c_x10));
}

static void
power_off(tuya_device_t *d)
{
	printf("  powering off\n");
	print_response(tuya_turn_off(d, DPS_POWER));
}

/* ------------------------------------------------------------------ */
/*  Commands                                                           */
/* ------------------------------------------------------------------ */

static void
cmd_status(tuya_device_t *d)
{
	char *resp = tuya_status(d);
	if (!resp) {
		fprintf(stderr, "error: no response from device\n");
		return;
	}

	printf("ISV-300W status:\n");
	printf("  %s\n", resp);

	/*
	 * Quick numeric extraction for key DPs so the user doesn't need
	 * to decode JSON manually.  The response looks like:
	 * {"dps":{"101":true,"102":"working","103":500,...}}
	 */
	const char *dps = strstr(resp, "\"dps\"");
	if (dps) {
		int power = 0, target = 0, current = 0, timer = 0, remain = 0;
		int fault = 0, unit = 0, recipe = 0, cal = 0;
		char status[32] = {0};

		/* extract known keys with sscanf heuristics */
		const char *p = dps;
		while ((p = strchr(p, '"')) != NULL) {
			long dp_id = strtol(p + 1, NULL, 10);
			p = strchr(p + 1, ':');
			if (!p) break;
			p++;

			switch ((int)dp_id) {
			case 101: power = (strncmp(p, "true", 4) == 0); break;
			case 102:
				if (*p == '"') {
					p++;
					char *end = strchr(p, '"');
					if (end) {
						int len = (int)(end - p);
						if (len > 31) len = 31;
						memcpy(status, p, (size_t)len);
						status[len] = '\0';
						p = end + 1;
					}
				}
				break;
			case 103: target = (int)strtol(p, NULL, 10); break;
			case 104: current = (int)strtol(p, NULL, 10); break;
			case 105: timer = (int)strtol(p, NULL, 10); break;
			case 106: remain = (int)strtol(p, NULL, 10); break;
			case 107: fault = (int)strtol(p, NULL, 10); break;
			case 108: unit = (strncmp(p, "true", 4) == 0); break;
			case 109: recipe = (int)strtol(p, NULL, 10); break;
			case 110: cal = (int)strtol(p, NULL, 10); break;
			}
		}

		printf("\n");
		printf("  Power:          %s\n", power ? "ON" : "OFF");
		printf("  Status:         %s\n", status[0] ? status : "?");
		printf("  Current:        %.1f C / %.1f F\n",
		    current / 10.0, c_to_f(current / 10.0));
		printf("  Target:         %.1f C / %.1f F\n",
		    target / 10.0, c_to_f(target / 10.0));
		printf("  Timer:          %d min (remaining: %d)\n", timer, remain);
		printf("  Unit:           %s\n", unit ? "Celsius" : "Fahrenheit");
		printf("  Fault:          %d\n", fault);
		printf("  Recipe:         %d\n", recipe);
		printf("  Calibration:    %.1f C\n", cal / 10.0);
	}

	tuya_free_string(resp);
}

static void
cmd_read(tuya_device_t *d)
{
	char *resp = tuya_status(d);
	if (!resp) {
		fprintf(stderr, "error: no response from device\n");
		return;
	}

	/* extract DP 104 (current temp) */
	const char *p = strstr(resp, "\"104\"");
	if (p) {
		p = strchr(p, ':');
		if (p) {
			int val = (int)strtol(p + 1, NULL, 10);
			printf("%.1f C / %.1f F\n",
			    val / 10.0, c_to_f(val / 10.0));
		}
	}
	tuya_free_string(resp);
}

static int
cmd_temp(tuya_device_t *d, int argc, char **argv)
{
	bool ok;
	int target;

	if (argc < 1) {
		fprintf(stderr, "usage: sousvide temp TEMP [HOLD_TIME]\n");
		return 1;
	}

	target = parse_temp(argv[0], &ok);
	if (!ok) {
		fprintf(stderr, "error: invalid temperature '%s'\n", argv[0]);
		return 1;
	}

	set_temp(d, target);

	if (argc >= 2) {
		int hold_secs = parse_duration(argv[1], &ok);
		if (!ok) {
			fprintf(stderr, "error: invalid duration '%s'\n", argv[1]);
			return 1;
		}
		printf("  holding for %d min %d sec...\n",
		    hold_secs / 60, hold_secs % 60);
		sleep(hold_secs);
	}

	return 0;
}

struct phase {
	int    start;        /* Celsius * 10 */
	int    end;          /* Celsius * 10 */
	int    duration_secs;
	bool   is_hold;      /* start == end */
};

static int
run_ramp(tuya_device_t *d, struct phase *phases, int nphases, bool poweroff)
{
	for (int pi = 0; pi < nphases; pi++) {
		struct phase *ph = &phases[pi];
		int steps    = ph->duration_secs / 60;
		int remainder = ph->duration_secs % 60;

		if (steps < 1 && remainder == 0)
			steps = 1;   /* at least one step */

		double step_d = (steps > 0)
		    ? (double)(ph->end - ph->start) / (double)steps
		    : 0.0;

		if (ph->is_hold) {
			printf("\n--- Hold at %.1f C for %d:%02d ---\n",
			    ph->start / 10.0,
			    ph->duration_secs / 60, ph->duration_secs % 60);
			vlog("phase %d: hold %.1f C for %d:%02d\n", pi + 1,
			    ph->start / 10.0,
			    ph->duration_secs / 60, ph->duration_secs % 60);
		} else {
			printf("\n--- Ramp %.1f -> %.1f C over %d:%02d"
			    " (%d steps of %.2f C) ---\n",
			    ph->start / 10.0, ph->end / 10.0,
			    ph->duration_secs / 60, ph->duration_secs % 60,
			    steps, step_d / 10.0);
			vlog("phase %d: ramp %.1f -> %.1f C over %d:%02d\n",
			    pi + 1, ph->start / 10.0, ph->end / 10.0,
			    ph->duration_secs / 60, ph->duration_secs % 60);
		}

		/* initial set */
		set_temp(d, ph->start);

		/* step loop — one adjustment per minute */
		for (int i = 1; i <= steps; i++) {
			int target = ph->start + (int)round(step_d * i);
			/* clamp to [min(start,end), max(start,end)] */
			int lo = (ph->start < ph->end) ? ph->start : ph->end;
			int hi = (ph->start < ph->end) ? ph->end   : ph->start;
			if (target < lo) target = lo;
			if (target > hi) target = hi;

			printf("[%3d/%d min] ", i, steps);
			sleep(60);
			tuya_reconnect(d);
			set_temp(d, target);
		}

		/* trailing seconds beyond the last full minute */
		if (remainder > 0) {
			printf("[holding %d sec] ", remainder);
			sleep(remainder);
		}
	}

	printf("\ndone.\n");

	if (poweroff) {
		power_off(d);
		tuya_disconnect(d);
		tuya_destroy(d);
		printf("device powered off.\n");
	}

	return 0;
}

/* ------------------------------------------------------------------ */
/*  Usage                                                              */
/* ------------------------------------------------------------------ */

static void
usage(const char *prog)
{
	fprintf(stderr,
"Usage: %s COMMAND [ARGS...]\n"
"\n"
"Local Tuya controller for Inkbird sous vide cookers.\n"
"Reads credentials from $XDG_CONFIG_HOME/seatuya/config [sousvide].\n"
"\n"
"Commands:\n"
"  status                 display all data points\n"
"  read                   read current temperature\n"
"  temp TEMP [HOLD]       set target temperature, optionally hold\n"
"  ramp PHASE [PHASE...]  one or more ramp/hold phases\n"
"  off                    power off\n"
"\n"
"Temperature: NUMBER with optional C or F suffix (default: Celsius).\n"
"  Examples:  50C   122F   37.5\n"
"\n"
"Time: HH:MM, HH:MM:SS, or bare integer (minutes).\n"
"  Examples:  1:30   0:45:00   45\n"
"\n"
"Each ramp PHASE is three arguments: START END TIME.\n"
"A hold is a ramp where START equals END.\n"
"  %s ramp 25C 50C 30:00 50C 50C 30:00 --off\n"
"\n"
"Global options:\n"
"  -c FILE    config file path\n"
"  -n         dry run (print schedule, no device connection)\n",
	    prog, prog);
}

/* ------------------------------------------------------------------ */
/*  Main                                                               */
/* ------------------------------------------------------------------ */

int
main(int argc, char **argv)
{
	const char *prog = progname(argv[0]);
	const char *cmd;
	int opt;
	char config_path[512];
	bool dry_run = false;
	bool poweroff = false;

	/* XDG config path */
	{
		const char *xdg = getenv("XDG_CONFIG_HOME");
		if (xdg && xdg[0])
			snprintf(config_path, sizeof(config_path),
			    "%s/seatuya/config", xdg);
		else
			snprintf(config_path, sizeof(config_path),
			    "%s/.config/seatuya/config",
			    getenv("HOME") ? getenv("HOME") : ".");
	}

	/*
	 * Parse global options, then skip them so the subcommand is
	 * always at the first non-option argument.  getopt permutes.
	 */
	while ((opt = getopt(argc, argv, "+c:nhv")) != -1) {
		switch (opt) {
		case 'c': strncpy(config_path, optarg,
			    sizeof(config_path) - 1); break;
		case 'n': dry_run = true; break;
		case 'v': verbose = true; break;
		default:
			usage(prog);
			return (opt == 'h') ? 0 : 1;
		}
	}

	if (optind >= argc) {
		usage(prog);
		return 1;
	}

	cmd = argv[optind];

	/* -------------------------------------------------------------- */
	/*  Status and read: no connection overhead, just query           */
	/* -------------------------------------------------------------- */

	if (strcmp(cmd, "status") == 0 || strcmp(cmd, "read") == 0) {
		struct config cfg;
		if (read_config(config_path, &cfg) != 0)
			return 1;

		tuya_device_t *d = tuya_create(cfg.device_id, cfg.ip,
		                       cfg.local_key, cfg.version);
		if (!d) {
			fprintf(stderr, "error: failed to connect to %s\n",
			    cfg.ip);
			return 1;
		}

		if (strcmp(cmd, "status") == 0)
			cmd_status(d);
		else
			cmd_read(d);

		tuya_disconnect(d);
		tuya_destroy(d);
		return 0;
	}

	/* -------------------------------------------------------------- */
	/*  Off: connect, power off, disconnect                           */
	/* -------------------------------------------------------------- */

	if (strcmp(cmd, "off") == 0) {
		struct config cfg;
		if (read_config(config_path, &cfg) != 0)
			return 1;

		tuya_device_t *d = tuya_create(cfg.device_id, cfg.ip,
		                       cfg.local_key, cfg.version);
		if (!d) {
			fprintf(stderr, "error: failed to connect to %s\n",
			    cfg.ip);
			return 1;
		}
		power_off(d);
		tuya_disconnect(d);
		tuya_destroy(d);
		return 0;
	}

	/* -------------------------------------------------------------- */
	/*  Temp: set target, optional hold                               */
	/* -------------------------------------------------------------- */

	if (strcmp(cmd, "temp") == 0) {
		int cargc = argc - optind - 1;
		char **cargv = &argv[optind + 1];

		struct config cfg;
		if (read_config(config_path, &cfg) != 0)
			return 1;

		tuya_device_t *d = tuya_create(cfg.device_id, cfg.ip,
		                       cfg.local_key, cfg.version);
		if (!d) {
			fprintf(stderr, "error: failed to connect to %s\n",
			    cfg.ip);
			return 1;
		}

		int r = cmd_temp(d, cargc, cargv);
		tuya_disconnect(d);
		tuya_destroy(d);
		return r;
	}

	/* -------------------------------------------------------------- */
	/*  Ramp: one or more phases, each START END TIME                 */
	/* -------------------------------------------------------------- */

	if (strcmp(cmd, "ramp") == 0) {
		int cargc = argc - optind - 1;
		char **cargv = &argv[optind + 1];

		/* check for --off at end */
		if (cargc > 0 && strcmp(cargv[cargc - 1], "--off") == 0) {
			poweroff = true;
			cargc--;
		}

		if (cargc < 3 || cargc % 3 != 0) {
			fprintf(stderr,
			    "error: ramp takes groups of"
			    " START END TIME [...]\n");
			return 1;
		}

		int nphases = cargc / 3;
		struct config cfg;
		if (read_config(config_path, &cfg) != 0)
			return 1;

		struct phase *phases = calloc((size_t)nphases,
		                              sizeof(*phases));
		if (!phases) {
			fprintf(stderr, "error: out of memory\n");
			return 1;
		}

		for (int i = 0; i < nphases; i++) {
			bool ok;
			phases[i].start = parse_temp(cargv[i * 3 + 0], &ok);
			if (!ok) {
				fprintf(stderr, "error: bad temperature '%s'\n",
				    cargv[i * 3 + 0]);
				free(phases);
				return 1;
			}
			phases[i].end = parse_temp(cargv[i * 3 + 1], &ok);
			if (!ok) {
				fprintf(stderr, "error: bad temperature '%s'\n",
				    cargv[i * 3 + 1]);
				free(phases);
				return 1;
			}
			phases[i].duration_secs =
			    parse_duration(cargv[i * 3 + 2], &ok);
			if (!ok || phases[i].duration_secs < 1) {
				fprintf(stderr, "error: bad duration '%s'\n",
				    cargv[i * 3 + 2]);
				free(phases);
				return 1;
			}
			phases[i].is_hold =
			    (phases[i].start == phases[i].end);
		}

		if (dry_run) {
			printf("[dry run]\n");
			for (int i = 0; i < nphases; i++) {
				struct phase *ph = &phases[i];
				if (ph->is_hold)
					printf("  hold  %.1f C  %d:%02d\n",
					    ph->start / 10.0,
					    ph->duration_secs / 60,
					    ph->duration_secs % 60);
				else
					printf("  ramp  %.1f -> %.1f C"
					    "  %d:%02d\n",
					    ph->start / 10.0,
					    ph->end / 10.0,
					    ph->duration_secs / 60,
					    ph->duration_secs % 60);
			}
			if (poweroff)
				printf("  off\n");
			free(phases);
			return 0;
		}

		tuya_device_t *d = tuya_create(cfg.device_id, cfg.ip,
		                       cfg.local_key, cfg.version);
		if (!d) {
			fprintf(stderr, "error: failed to connect to %s\n",
			    cfg.ip);
			free(phases);
			return 1;
		}

		/* power on, read initial status */
		print_response(tuya_turn_on(d, DPS_POWER));
		print_response(tuya_status(d));

		int r = run_ramp(d, phases, nphases, poweroff);
		if (!poweroff) {
			tuya_disconnect(d);
			tuya_destroy(d);
		}
		free(phases);
		return r;
	}

	/* -------------------------------------------------------------- */
	/*  Unknown command                                                */
	/* -------------------------------------------------------------- */

	fprintf(stderr, "error: unknown command '%s'\n", cmd);
	usage(prog);
	return 1;
}
