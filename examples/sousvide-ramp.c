/*
 * sousvide-ramp -- Ramp an Inkbird sous vide from one temperature to another.
 *
 * Usage:
 *   sousvide-ramp [options]
 *
 * Reads device credentials from $XDG_CONFIG_HOME/seatuya/config
 * (defaults to ~/.config/seatuya/config), INI-style:
 *
 *   [sousvide]
 *   device_id = <your device id>
 *   local_key = <your local key>
 *   ip        = <device IP or hostname>
 *   version   = 3.3
 *
 * Default behaviour (no arguments):
 *   Start at 90 F, ramp to 145 F over 45 minutes.
 *
 * Options:
 *   -s TEMP   start temperature in Fahrenheit  (default: 90)
 *   -e TEMP   end temperature in Fahrenheit    (default: 145)
 *   -t MINS   ramp duration in minutes         (default: 45)
 *   -c FILE   config file path                 (default: ~/.seatuyarc)
 *   -n        dry run -- print steps, don't connect
 *
 * Copyright (c) 2026, David Walther <david@clearbrookdistillery.com>
 * BSD-2-Clause
 */

#include <seatuya.h>

#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

/* ------------------------------------------------------------------ */
/*  Inkbird sous vide DPS mapping (ISV-100W / ISV-200W)               */
/* ------------------------------------------------------------------ */

enum inkbird_dps {
	DPS_POWER        = 101,   /* bool: on/off                       */
	DPS_STATUS       = 102,   /* string: "working" / "stopping"     */
	DPS_TARGET_TEMP  = 103,   /* int: target temp * 10 (Celsius)    */
	DPS_CURRENT_TEMP = 104,   /* int: water temp * 10 (Celsius)     */
	DPS_TIMER        = 105,   /* int: timer duration in minutes     */
	DPS_TIME_LEFT    = 106,   /* int: remaining minutes             */
	DPS_TEMP_UNIT    = 108,   /* bool: true=C, false=F              */
	DPS_TEMP_CAL     = 110    /* int: calibration offset * 10       */
};

/* ------------------------------------------------------------------ */
/*  Config file reader                                                */
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
	strncpy(cfg->version, "3.3", sizeof(cfg->version) - 1);

	fp = fopen(path, "r");
	if (!fp) {
		fprintf(stderr, "error: cannot open %s: ", path);
		perror(NULL);
		return -1;
	}

	while (fgets(line, sizeof(line), fp)) {
		/* strip newline */
		char *nl = strchr(line, '\n');
		if (nl) *nl = '\0';

		/* skip comments and blanks */
		if (line[0] == '#' || line[0] == ';' || line[0] == '\0')
			continue;

		/* section header */
		if (line[0] == '[') {
			in_section = (strstr(line, "[sousvide]") != NULL);
			continue;
		}

		if (!in_section)
			continue;

		/* key = value */
		char *eq = strchr(line, '=');
		if (!eq) continue;
		*eq = '\0';

		/* trim key */
		char *key = line;
		while (*key == ' ' || *key == '\t') key++;
		char *ke = eq - 1;
		while (ke > key && (*ke == ' ' || *ke == '\t')) *ke-- = '\0';

		/* trim value */
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
		    "error: missing device_id, local_key, or ip in [sousvide] section of %s\n",
		    path);
		return -1;
	}

	return 0;
}

/* ------------------------------------------------------------------ */
/*  Temperature helpers                                               */
/* ------------------------------------------------------------------ */

static double
f_to_c(double f)
{
	return (f - 32.0) * 5.0 / 9.0;
}

/* Tuya DPS 103 expects Celsius * 10, as an integer */
static int
f_to_dps(double f)
{
	return (int)round(f_to_c(f) * 10.0);
}

/* ------------------------------------------------------------------ */
/*  Inkbird convenience wrappers                                      */
/* ------------------------------------------------------------------ */

static void
print_response(char *resp)
{
	if (resp) {
		printf("  response: %s\n", resp);
		tuya_free_string(resp);
	}
}

static void
power_on(tuya_device_t *dev)
{
	printf("  powering on\n");
	print_response(tuya_turn_on(dev, DPS_POWER));
}

static void
set_temperature_f(tuya_device_t *dev, double temp_f)
{
	printf("  set target: %.1f F (%.1f C)\n", temp_f, f_to_c(temp_f));
	print_response(tuya_set_value_int(dev, DPS_TARGET_TEMP,
	    f_to_dps(temp_f)));
}

/* ------------------------------------------------------------------ */
/*  Main                                                              */
/* ------------------------------------------------------------------ */

static void
usage(const char *prog)
{
	fprintf(stderr,
	    "Usage: %s [-s start_F] [-e end_F] [-t minutes] [-c configfile] [-n]\n"
	    "\n"
	    "Ramp an Inkbird sous vide from start to end temperature.\n"
	    "Reads credentials from $XDG_CONFIG_HOME/seatuya/config [sousvide].\n"
	    "\n"
	    "Options:\n"
	    "  -s TEMP   start temperature in Fahrenheit  (default: 90)\n"
	    "  -e TEMP   end temperature in Fahrenheit    (default: 145)\n"
	    "  -t MINS   ramp duration in minutes         (default: 45)\n"
	    "  -c FILE   config file path\n"
	    "  -n        dry run\n",
	    prog);
}

int
main(int argc, char *argv[])
{
	double start_f = 90.0;
	double end_f = 145.0;
	int ramp_minutes = 45;
	bool dry_run = false;
	char config_path[512];
	int opt;

	/* XDG Base Directory: $XDG_CONFIG_HOME/seatuya/config */
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

	while ((opt = getopt(argc, argv, "s:e:t:c:nh")) != -1) {
		switch (opt) {
		case 's': start_f = atof(optarg); break;
		case 'e': end_f = atof(optarg); break;
		case 't': ramp_minutes = atoi(optarg); break;
		case 'c': strncpy(config_path, optarg, sizeof(config_path) - 1); break;
		case 'n': dry_run = true; break;
		default:
			usage(argv[0]);
			return (opt == 'h') ? 0 : 1;
		}
	}

	if (ramp_minutes < 1) {
		fprintf(stderr, "error: ramp duration must be at least 1 minute\n");
		return 1;
	}

	/*
	 * Ramp strategy: adjust temperature once per minute.
	 * Each step increments by (end - start) / ramp_minutes degrees.
	 */
	int steps = ramp_minutes;
	double step_f = (end_f - start_f) / steps;

	printf("sousvide-ramp: %.1f F -> %.1f F over %d minutes (%d steps of %.2f F)\n",
	    start_f, end_f, ramp_minutes, steps, step_f);

	if (dry_run) {
		printf("\n[dry run]\n");
		for (int i = 0; i <= steps; i++) {
			double temp = start_f + step_f * i;
			if (temp > end_f) temp = end_f;
			printf("  t=%3d min  target=%.1f F  (%.1f C)\n",
			    i, temp, f_to_c(temp));
		}
		return 0;
	}

	/* Read config */
	struct config cfg;
	if (read_config(config_path, &cfg) != 0)
		return 1;

	printf("device: %s @ %s (protocol %s)\n",
	    cfg.device_id, cfg.ip, cfg.version);

	/* Connect to device */
	printf("connecting to %s...\n", cfg.ip);
	tuya_device_t *dev = tuya_create(cfg.device_id, cfg.ip,
	    cfg.local_key, cfg.version);
	if (!dev) {
		fprintf(stderr, "error: failed to connect to %s\n", cfg.ip);
		return 1;
	}

	/* Query current status */
	printf("  querying status\n");
	print_response(tuya_status(dev));

	/* Power on and set initial temperature */
	power_on(dev);
	set_temperature_f(dev, start_f);

	/* Ramp loop: one adjustment per minute */
	for (int i = 1; i <= steps; i++) {
		double temp = start_f + step_f * i;
		if (temp > end_f) temp = end_f;

		printf("[%3d/%d min] ", i, steps);
		sleep(60);

		tuya_reconnect(dev);

		set_temperature_f(dev, temp);
	}

	printf("\nramp complete -- holding at %.1f F\n", end_f);

	tuya_disconnect(dev);
	tuya_destroy(dev);
	return 0;
}
