/*
 * sousvide-ramp — Ramp an Inkbird sous vide from one temperature to another.
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
 *   -n        dry run — print steps, don't connect
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

enum { MAX_BUF = 1024 };

/* ------------------------------------------------------------------ */
/*  Config file reader                                                */
/* ------------------------------------------------------------------ */

struct sousvide_config {
	char device_id[128];
	char local_key[128];
	char ip[256];
	char version[8];
};

static int
read_config(const char *path, struct sousvide_config *cfg)
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
/*  Device communication                                              */
/* ------------------------------------------------------------------ */

static int
send_command(seatuya_device_t *dev, const char *device_id,
             const char *local_key, const char *dps_json,
             enum seatuya_command cmd)
{
	unsigned char buf[MAX_BUF];
	char *payload;
	int len, n;
	char *response;

	payload = seatuya_generate_payload(dev, cmd, device_id, dps_json);
	if (!payload) {
		fprintf(stderr, "error: failed to generate payload\n");
		return -1;
	}

	len = seatuya_build_message(dev, buf, cmd, payload, local_key);
	seatuya_free_string(payload);
	if (len < 0) {
		fprintf(stderr, "error: failed to build message\n");
		return -1;
	}

	n = seatuya_send(dev, buf, len);
	if (n < 0) {
		fprintf(stderr, "error: send failed\n");
		return -1;
	}

	usleep(200000);

	n = seatuya_receive(dev, buf, MAX_BUF - 1, 0);
	if (n > 0) {
		response = seatuya_decode_message(dev, buf, n, local_key);
		if (response) {
			printf("  response: %s\n", response);
			seatuya_free_string(response);
		}
	}

	return 0;
}

static int
set_temperature_f(seatuya_device_t *dev, const char *device_id,
                  const char *local_key, double temp_f)
{
	char dps[64];
	int dps_val = f_to_dps(temp_f);

	printf("  set target: %.1f F (DPS %d = %d)\n",
	    temp_f, DPS_TARGET_TEMP, dps_val);

	snprintf(dps, sizeof(dps), "{\"%d\":%d}", DPS_TARGET_TEMP, dps_val);
	return send_command(dev, device_id, local_key, dps,
	    SEATUYA_CMD_CONTROL);
}

static int
power_on(seatuya_device_t *dev, const char *device_id,
         const char *local_key)
{
	char dps[64];
	printf("  powering on\n");
	snprintf(dps, sizeof(dps), "{\"%d\":true}", DPS_POWER);
	return send_command(dev, device_id, local_key, dps,
	    SEATUYA_CMD_CONTROL);
}

static int
query_status(seatuya_device_t *dev, const char *device_id,
             const char *local_key)
{
	printf("  querying status\n");
	return send_command(dev, device_id, local_key, NULL,
	    SEATUYA_CMD_DP_QUERY);
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
			printf("  t=%3d min  target=%.1f F  (DPS %d = %d)\n",
			    i, temp, DPS_TARGET_TEMP, f_to_dps(temp));
		}
		return 0;
	}

	/* Read config */
	struct sousvide_config cfg;
	if (read_config(config_path, &cfg) != 0)
		return 1;

	printf("device: %s @ %s (protocol %s)\n",
	    cfg.device_id, cfg.ip, cfg.version);

	/* Create device handle */
	seatuya_device_t *dev = seatuya_create(cfg.version);
	if (!dev) {
		fprintf(stderr, "error: unsupported protocol version: %s\n",
		    cfg.version);
		return 1;
	}

	/* Connect */
	printf("connecting to %s...\n", cfg.ip);
	if (!seatuya_connect(dev, cfg.ip)) {
		fprintf(stderr, "error: connection failed (errno %d)\n",
		    seatuya_get_last_error(dev));
		seatuya_destroy(dev);
		return 1;
	}

	/* Session negotiation (needed for protocol 3.4+) */
	if (seatuya_get_protocol(dev) >= SEATUYA_PROTO_V34) {
		printf("negotiating session...\n");
		if (!seatuya_negotiate_session(dev, cfg.local_key)) {
			fprintf(stderr, "error: session negotiation failed\n");
			seatuya_disconnect(dev);
			seatuya_destroy(dev);
			return 1;
		}
	}

	/* Query current status */
	query_status(dev, cfg.device_id, cfg.local_key);

	/* Power on and set initial temperature */
	power_on(dev, cfg.device_id, cfg.local_key);
	set_temperature_f(dev, cfg.device_id, cfg.local_key, start_f);

	/* Ramp loop: one adjustment per minute */
	for (int i = 1; i <= steps; i++) {
		double temp = start_f + step_f * i;
		if (temp > end_f) temp = end_f;

		printf("[%3d/%d min] ", i, steps);
		sleep(60);

		/* Reconnect if connection dropped */
		if (!seatuya_is_connected(dev)) {
			printf("  reconnecting...\n");
			seatuya_connect(dev, cfg.ip);
			if (seatuya_get_protocol(dev) >= SEATUYA_PROTO_V34)
				seatuya_negotiate_session(dev, cfg.local_key);
		}

		set_temperature_f(dev, cfg.device_id, cfg.local_key, temp);
	}

	printf("\nramp complete — holding at %.1f F\n", end_f);

	/* Clean up */
	seatuya_disconnect(dev);
	seatuya_destroy(dev);

	return 0;
}
