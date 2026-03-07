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

enum { MAX_BUF = 1024 };

/* ------------------------------------------------------------------ */
/*  Device handle + credentials bundle                                */
/* ------------------------------------------------------------------ */

struct tuya_dev {
	seatuya_device_t *handle;
	char device_id[128];
	char local_key[128];
	char ip[256];
	char version[8];
};

/* ------------------------------------------------------------------ */
/*  Config file reader                                                */
/* ------------------------------------------------------------------ */

static int
read_config(const char *path, struct tuya_dev *dev)
{
	FILE *fp;
	char line[512];
	int in_section = 0;

	memset(dev, 0, sizeof(*dev));
	strncpy(dev->version, "3.3", sizeof(dev->version) - 1);

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
			strncpy(dev->device_id, val, sizeof(dev->device_id) - 1);
		else if (strcmp(key, "local_key") == 0)
			strncpy(dev->local_key, val, sizeof(dev->local_key) - 1);
		else if (strcmp(key, "ip") == 0)
			strncpy(dev->ip, val, sizeof(dev->ip) - 1);
		else if (strcmp(key, "version") == 0)
			strncpy(dev->version, val, sizeof(dev->version) - 1);
	}

	fclose(fp);

	if (!dev->device_id[0] || !dev->local_key[0] || !dev->ip[0]) {
		fprintf(stderr,
		    "error: missing device_id, local_key, or ip in [sousvide] section of %s\n",
		    path);
		return -1;
	}

	return 0;
}

/* ------------------------------------------------------------------ */
/*  Connect + negotiate                                               */
/* ------------------------------------------------------------------ */

static int
tuya_dev_connect(struct tuya_dev *dev)
{
	dev->handle = seatuya_create(dev->version);
	if (!dev->handle) {
		fprintf(stderr, "error: unsupported protocol version: %s\n",
		    dev->version);
		return -1;
	}

	printf("connecting to %s...\n", dev->ip);
	if (!seatuya_connect(dev->handle, dev->ip)) {
		fprintf(stderr, "error: connection failed (errno %d)\n",
		    seatuya_get_last_error(dev->handle));
		seatuya_destroy(dev->handle);
		dev->handle = NULL;
		return -1;
	}

	if (seatuya_get_protocol(dev->handle) >= SEATUYA_PROTO_V34) {
		printf("negotiating session...\n");
		if (!seatuya_negotiate_session(dev->handle, dev->local_key)) {
			fprintf(stderr, "error: session negotiation failed\n");
			seatuya_disconnect(dev->handle);
			seatuya_destroy(dev->handle);
			dev->handle = NULL;
			return -1;
		}
	}

	return 0;
}

static void
tuya_dev_reconnect(struct tuya_dev *dev)
{
	if (seatuya_is_connected(dev->handle))
		return;
	printf("  reconnecting...\n");
	seatuya_connect(dev->handle, dev->ip);
	if (seatuya_get_protocol(dev->handle) >= SEATUYA_PROTO_V34)
		seatuya_negotiate_session(dev->handle, dev->local_key);
}

static void
tuya_dev_destroy(struct tuya_dev *dev)
{
	if (!dev->handle) return;
	seatuya_disconnect(dev->handle);
	seatuya_destroy(dev->handle);
	dev->handle = NULL;
}

/* ------------------------------------------------------------------ */
/*  Generic set-value and status query                                */
/* ------------------------------------------------------------------ */

static int
set_value_bool(struct tuya_dev *dev, int dp, bool val)
{
	char dps[64];
	unsigned char buf[MAX_BUF];

	snprintf(dps, sizeof(dps), "{\"%d\":%s}", dp, val ? "true" : "false");

	char *payload = seatuya_generate_payload(dev->handle,
	    SEATUYA_CMD_CONTROL, dev->device_id, dps);
	if (!payload) return -1;

	int len = seatuya_build_message(dev->handle, buf,
	    SEATUYA_CMD_CONTROL, payload, dev->local_key);
	seatuya_free_string(payload);
	if (len < 0) return -1;

	int n = seatuya_send(dev->handle, buf, len);
	if (n < 0) return -1;

	usleep(200000);
	n = seatuya_receive(dev->handle, buf, MAX_BUF - 1, 0);
	if (n > 0) {
		char *resp = seatuya_decode_message(dev->handle, buf, n,
		    dev->local_key);
		if (resp) {
			printf("  response: %s\n", resp);
			seatuya_free_string(resp);
		}
	}
	return 0;
}

static int
set_value_int(struct tuya_dev *dev, int dp, int val)
{
	char dps[64];
	unsigned char buf[MAX_BUF];

	snprintf(dps, sizeof(dps), "{\"%d\":%d}", dp, val);

	char *payload = seatuya_generate_payload(dev->handle,
	    SEATUYA_CMD_CONTROL, dev->device_id, dps);
	if (!payload) return -1;

	int len = seatuya_build_message(dev->handle, buf,
	    SEATUYA_CMD_CONTROL, payload, dev->local_key);
	seatuya_free_string(payload);
	if (len < 0) return -1;

	int n = seatuya_send(dev->handle, buf, len);
	if (n < 0) return -1;

	usleep(200000);
	n = seatuya_receive(dev->handle, buf, MAX_BUF - 1, 0);
	if (n > 0) {
		char *resp = seatuya_decode_message(dev->handle, buf, n,
		    dev->local_key);
		if (resp) {
			printf("  response: %s\n", resp);
			seatuya_free_string(resp);
		}
	}
	return 0;
}

static int
query_status(struct tuya_dev *dev)
{
	unsigned char buf[MAX_BUF];

	char *payload = seatuya_generate_payload(dev->handle,
	    SEATUYA_CMD_DP_QUERY, dev->device_id, "");
	if (!payload) return -1;

	int len = seatuya_build_message(dev->handle, buf,
	    SEATUYA_CMD_DP_QUERY, payload, dev->local_key);
	seatuya_free_string(payload);
	if (len < 0) return -1;

	int n = seatuya_send(dev->handle, buf, len);
	if (n < 0) return -1;

	usleep(200000);
	n = seatuya_receive(dev->handle, buf, MAX_BUF - 1, 0);
	if (n > 0) {
		char *resp = seatuya_decode_message(dev->handle, buf, n,
		    dev->local_key);
		if (resp) {
			printf("  response: %s\n", resp);
			seatuya_free_string(resp);
		}
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

static int
power_on(struct tuya_dev *dev)
{
	printf("  powering on\n");
	return set_value_bool(dev, DPS_POWER, true);
}

static int
set_temperature_f(struct tuya_dev *dev, double temp_f)
{
	printf("  set target: %.1f F (%.1f C)\n", temp_f, f_to_c(temp_f));
	return set_value_int(dev, DPS_TARGET_TEMP, f_to_dps(temp_f));
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

	/* Read config into device bundle */
	struct tuya_dev dev;
	if (read_config(config_path, &dev) != 0)
		return 1;

	printf("device: %s @ %s (protocol %s)\n",
	    dev.device_id, dev.ip, dev.version);

	/* Connect + negotiate */
	if (tuya_dev_connect(&dev) != 0)
		return 1;

	/* Query current status */
	printf("  querying status\n");
	query_status(&dev);

	/* Power on and set initial temperature */
	power_on(&dev);
	set_temperature_f(&dev, start_f);

	/* Ramp loop: one adjustment per minute */
	for (int i = 1; i <= steps; i++) {
		double temp = start_f + step_f * i;
		if (temp > end_f) temp = end_f;

		printf("[%3d/%d min] ", i, steps);
		sleep(60);

		tuya_dev_reconnect(&dev);

		set_temperature_f(&dev, temp);
	}

	printf("\nramp complete -- holding at %.1f F\n", end_f);

	tuya_dev_destroy(&dev);
	return 0;
}
