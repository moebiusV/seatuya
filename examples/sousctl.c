/*
 * sousctl ("sue kettle") — Local Tuya controller for Inkbird sous vide.
 *
 * Usage:
 *   sousctl [-v] [-n] [-c FILE] [-i IP] COMMAND [ARGS] [COMMAND [ARGS]] ...
 *
 * Commands chain SoX-style: each command consumes its own arguments,
 * then the next word is the next command.
 *
 *   sousctl status                          read all data points
 *   sousctl read                            read current temperature
 *   sousctl temp 50C                        set target temperature
 *   sousctl ramp 25C 50C 30:00              ramp over duration
 *   sousctl hold 50C 30:00                  hold temperature
 *   sousctl off                             power off
 *
 * Chaining:
 *   sousctl ramp 25C 50C 30:00 hold 50C 30:00
 *   sousctl -v temp 122F hold 122F 1:00:00
 *
 * Temperature: NUMBER with optional C or F suffix (default: Celsius).
 *   Examples: 50C  122F  37.5
 *
 * Time: M:SS, HH:MM:SS, or bare minutes.
 *   Examples: 5:00  1:30:00  45
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
#include <signal.h>
#include <unistd.h>

/* ------------------------------------------------------------------ */
/*  Globals                                                            */
/* ------------------------------------------------------------------ */

static bool verbose = false;
static tuya_device_t *atexit_dev = NULL;
static char override_ip[256] = {0};

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
        DPS_FAULT        = 107,   /* int: fault code                    */
        DPS_TEMP_UNIT    = 108,   /* bool: true=C, false=F              */
        DPS_RECIPE       = 109,   /* int: recipe number                  */
        DPS_TEMP_CAL     = 110    /* int: calibration offset * 10       */
};

static void
cleanup_poweroff(void)
{
        tuya_device_t *d = atexit_dev;
        if (!d) return;
        atexit_dev = NULL;
        fprintf(stderr, "\nsousctl: shutting down device\n");
        tuya_turn_off(d, DPS_POWER);
        tuya_disconnect(d);
        tuya_destroy(d);
}

static void
signal_handler(int sig)
{
        (void)sig;
        cleanup_poweroff();
        _exit(1);
}

/* ------------------------------------------------------------------ */
/*  Config file reader                                                 */
/* ------------------------------------------------------------------ */

struct config {
        char device_id[128];
        char local_key[128];
        char ip[256];
        char mac[24];
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
                if (!in_section) continue;

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
                else if (strcmp(key, "mac") == 0)
                        strncpy(cfg->mac, val, sizeof(cfg->mac) - 1);
                else if (strcmp(key, "version") == 0)
                        strncpy(cfg->version, val, sizeof(cfg->version) - 1);
        }

        fclose(fp);

        if (!cfg->device_id[0] || !cfg->local_key[0] || !cfg->ip[0]) {
                fprintf(stderr, "error: missing device_id, local_key, or ip"
                    " in %s\n", path);
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

static double c_to_f(double c) { return c * 9.0 / 5.0 + 32.0; }
static double f_to_c(double f) { return (f - 32.0) * 5.0 / 9.0; }

/*
 * Normalise a MAC address string to a compact hex form for comparison.
 * "00:33:7a:78:47:28" and "00-33-7A-78-47-28" both become
 * "00337a784728".
 */
static void
mac_normalise(const char *raw, char *out, size_t outsz)
{
        out[0] = '\0';
        for (const char *p = raw; *p && (size_t)(out - out + strlen(out)) < outsz - 1; p++)
                if (*p != ':' && *p != '-' && *p != ' ' && *p != '\t')
                        out[strlen(out)] = (char)tolower((unsigned char)*p);
}

/*
 * Match a line of `arp -a` output against a normalised MAC.
 * Format varies by OS:
 *   macOS/BSDs: ? (192.168.1.131) at 00:33:7a:78:47:28 on en0 ...
 *   Windows:    192.168.1.131        00-33-7a-78-47-28     dynamic
 * Also handles the /proc/net/arp format for Linux native.
 */
static bool
arp_line_match(const char *line, const char *mac_norm, char *ip_out, size_t ipsz)
{
        char ip[64] = {0}, hw[64] = {0}, hw_norm[48] = {0};
        int n;

        /* /proc/net/arp format: IP hw_type flags HW_addr mask device */
        n = sscanf(line, "%63s %*s %*s %63s", ip, hw);
        if (n == 2 && ip[0] && hw[0]) {
                mac_normalise(hw, hw_norm, sizeof(hw_norm));
                if (strcmp(mac_norm, hw_norm) == 0) {
                        strncpy(ip_out, ip, ipsz - 1);
                        return true;
                }
        }

        /* Windows `arp -a` format: IP  HW-addr  type */
        n = sscanf(line, "%63s %63s %*s", ip, hw);
        if (n == 2 && strchr(hw, '-') && ip[0]) {
                mac_normalise(hw, hw_norm, sizeof(hw_norm));
                if (strcmp(mac_norm, hw_norm) == 0) {
                        strncpy(ip_out, ip, ipsz - 1);
                        return true;
                }
        }

        /* macOS/BSD `arp -a` format: ? (ip) at hw on if */
        {
                const char *lp = strchr(line, '(');
                if (lp) {
                        lp++;
                        const char *rp = strchr(lp, ')');
                        if (rp && rp > lp) {
                                size_t len = (size_t)(rp - lp);
                                if (len < sizeof(ip)) {
                                        memcpy(ip, lp, len);
                                        ip[len] = '\0';
                                }
                        }
                }
                if (ip[0]) {
                        const char *at = strstr(line, " at ");
                        if (at) {
                                at += 4;
                                sscanf(at, "%63s", hw);
                                mac_normalise(hw, hw_norm, sizeof(hw_norm));
                                if (strcmp(mac_norm, hw_norm) == 0) {
                                        strncpy(ip_out, ip, ipsz - 1);
                                        return true;
                                }
                        }
                }
        }

        return false;
}

/*
 * Resolve a MAC address to an IP using the system ARP table.
 * Tries /proc/net/arp (Linux native), then `arp -a` (BSDs/macOS),
 * then powershell.exe arp -a (WSL2).  On WSL2, /proc/net/arp only
 * shows virtual interfaces, not the Windows host's LAN.
 */
static bool
resolve_mac(struct config *cfg)
{
        char mac_norm[32];
        FILE *fp;
        char line[512];

        if (!cfg->mac[0])
                return false;

        mac_normalise(cfg->mac, mac_norm, sizeof(mac_norm));

        /* 1. /proc/net/arp — Linux native, and WSL2 virtual iface */
        fp = fopen("/proc/net/arp", "r");
        if (fp) {
                fgets(line, sizeof(line), fp); /* skip header */
                while (fgets(line, sizeof(line), fp)) {
                        if (arp_line_match(line, mac_norm, cfg->ip,
                            sizeof(cfg->ip))) {
                                vlog("MAC %s -> %s (/proc/net/arp)\n",
                                    cfg->mac, cfg->ip);
                                fclose(fp);
                                return true;
                        }
                }
                fclose(fp);
        }

        /* 2. `arp -a` — macOS, FreeBSD, OpenBSD, NetBSD, native Linux */
        fp = popen("arp -a 2>/dev/null", "r");
        if (fp) {
                while (fgets(line, sizeof(line), fp)) {
                        if (arp_line_match(line, mac_norm, cfg->ip,
                            sizeof(cfg->ip))) {
                                vlog("MAC %s -> %s (arp -a)\n",
                                    cfg->mac, cfg->ip);
                                pclose(fp);
                                return true;
                        }
                }
                pclose(fp);
        }

        /* 3. WSL2: powershell.exe arp -a for Windows host's LAN */
#ifdef __linux__
        {
                /* Detect WSL by checking for /proc/sys/fs/binfmt_misc/WSLInterop */
                bool is_wsl = (access("/proc/sys/fs/binfmt_misc/WSLInterop",
                    F_OK) == 0);
                if (is_wsl) {
                        fp = popen(
                            "powershell.exe -c \"arp -a\" 2>/dev/null", "r");
                        if (fp) {
                                while (fgets(line, sizeof(line), fp)) {
                                        if (arp_line_match(line, mac_norm,
                                            cfg->ip, sizeof(cfg->ip))) {
                                                vlog("MAC %s -> %s (Win32 ARP)\n",
                                                    cfg->mac, cfg->ip);
                                                pclose(fp);
                                                return true;
                                        }
                                }
                                pclose(fp);
                        }
                }
        }
#endif

        return false;
}

static int
parse_temp(const char *s, bool *ok)
{
        char unit = 0;
        double val;
        *ok = false;
        if (!s || !*s) return 0;
        char tail[8] = {0};
        if (sscanf(s, "%lf%7s", &val, tail) < 1) return 0;
        if (tail[0]) {
                unit = (char)toupper((unsigned char)tail[0]);
                if (tail[1]) return 0;
        }
        if (unit == 0 || unit == 'C') { *ok = true; }
        else if (unit == 'F') { val = f_to_c(val); *ok = true; }
        else return 0;
        return (int)round(val * 10.0);
}

static int
parse_duration(const char *s, bool *ok)
{
        int h = 0, m = 0, sec = 0, n;
        *ok = false;
        if (!s || !*s) return 0;
        n = sscanf(s, "%d:%d:%d", &h, &m, &sec);
        if (n == 3)
                *ok = (m >= 0 && m < 60 && sec >= 0 && sec < 60 && h >= 0);
        else if (n == 2) {
                sec = m; m = h; h = 0;
                *ok = (m >= 0 && sec >= 0 && sec < 60);
        } else if (n == 1 && strchr(s, ':') == NULL) {
                m = h; h = 0;
                *ok = (m >= 0);
        }
        return h * 3600 + m * 60 + sec;
}

static void
print_response(char *resp)
{
        if (resp) { printf("  %s\n", resp); tuya_free_string(resp); }
}

static void
set_temp(tuya_device_t *d, int target_c_x10)
{
        double c = target_c_x10 / 10.0;
        vlog("target %.1f C / %.1f F\n", c, c_to_f(c));
        char *resp = tuya_set_value_int(d, DPS_TARGET_TEMP, target_c_x10);
        if (resp) {
                printf("  target: %.1f C / %.1f — success.\n", c, c_to_f(c));
                if (verbose) printf("  %s\n", resp);
                tuya_free_string(resp);
        } else {
                printf("  target: %.1f C / %.1f — FAILED.\n", c, c_to_f(c));
        }
}

static void
power_off(tuya_device_t *d)
{
        char *resp = tuya_turn_off(d, DPS_POWER);
        if (resp) {
                printf("  power off — success.\n");
                if (verbose) printf("  %s\n", resp);
                tuya_free_string(resp);
        } else {
                printf("  power off — FAILED.\n");
        }
}

/* ------------------------------------------------------------------ */
/*  Status / read                                                      */
/* ------------------------------------------------------------------ */

static void
cmd_status(tuya_device_t *d)
{
        char *resp = tuya_status(d);
        if (!resp) {
                fprintf(stderr, "error: no response from device\n");
                return;
        }
        printf("ISV-300W status:\n  %s\n\n", resp);

        const char *dps = strstr(resp, "\"dps\"");
        if (!dps) { tuya_free_string(resp); return; }

        int power = 0, target = 0, current = 0, timer = 0, remain = 0;
        int fault = 0, unit = 0, recipe = 0, cal = 0;
        char status[32] = {0};

        const char *p = dps;
        while ((p = strchr(p, '"')) != NULL) {
                long dp_id = strtol(p + 1, NULL, 10);
                p = strchr(p + 1, ':');
                if (!p) break;
                p++;

                switch ((int)dp_id) {
                case 101: power  = (strncmp(p, "true", 4) == 0); break;
                case 102:
                        if (*p == '"') {
                                p++;
                                const char *end = strchr(p, '"');
                                if (end) {
                                        int len = (int)(end - p);
                                        if (len > 31) len = 31;
                                        memcpy(status, p, (size_t)len);
                                        status[len] = '\0';
                                        p = (char *)end + 1;
                                }
                        }
                        break;
                case 103: target  = (int)strtol(p, NULL, 10); break;
                case 104: current = (int)strtol(p, NULL, 10); break;
                case 105: timer   = (int)strtol(p, NULL, 10); break;
                case 106: remain  = (int)strtol(p, NULL, 10); break;
                case 107: fault   = (int)strtol(p, NULL, 10); break;
                case 108: unit    = (strncmp(p, "true", 4) == 0); break;
                case 109: recipe  = (int)strtol(p, NULL, 10); break;
                case 110: cal     = (int)strtol(p, NULL, 10); break;
                }
        }

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
        const char *p = strstr(resp, "\"104\"");
        if (p) {
                p = strchr(p, ':');
                if (p) {
                        int val = (int)strtol(p + 1, NULL, 10);
                        printf("%.1f C / %.1f F — success.\n",
                            val / 10.0, c_to_f(val / 10.0));
                        if (verbose) printf("  %s\n", resp);
                        tuya_free_string(resp);
                        return;
                }
        }
        printf("read — FAILED.\n");
        printf("  %s\n", resp);
        tuya_free_string(resp);
}

/* ------------------------------------------------------------------ */
/*  Ramp / hold                                                        */
/* ------------------------------------------------------------------ */

struct phase {
        int    start, end;       /* Celsius * 10 */
        int    duration_secs;
        bool   is_hold;
};

static int
run_ramp(tuya_device_t *d, struct phase *phases, int nphases, bool poweroff)
{
        for (int pi = 0; pi < nphases; pi++) {
                struct phase *ph = &phases[pi];
                int steps    = ph->duration_secs / 60;
                int remainder = ph->duration_secs % 60;

                if (steps < 1 && remainder == 0)
                        steps = 1;

                double step_d = (steps > 0)
                    ? (double)(ph->end - ph->start) / (double)steps : 0.0;

                if (ph->is_hold) {
                        vlog("phase %d: hold %.1f C for %d:%02d\n",
                            pi + 1, ph->start / 10.0,
                            ph->duration_secs / 60, ph->duration_secs % 60);
                        printf("\n--- Hold at %.1f C for %d:%02d ---\n",
                            ph->start / 10.0,
                            ph->duration_secs / 60, ph->duration_secs % 60);
                } else {
                        vlog("phase %d: ramp %.1f -> %.1f C over %d:%02d"
                            " (%d steps)\n",
                            pi + 1, ph->start / 10.0, ph->end / 10.0,
                            ph->duration_secs / 60, ph->duration_secs % 60,
                            steps);
                        printf("\n--- Ramp %.1f -> %.1f C over %d:%02d"
                            " (%d steps of %.2f C) ---\n",
                            ph->start / 10.0, ph->end / 10.0,
                            ph->duration_secs / 60, ph->duration_secs % 60,
                            steps, step_d / 10.0);
                }

                set_temp(d, ph->start);

                for (int i = 1; i <= steps; i++) {
                        int target = ph->start + (int)round(step_d * i);
                        int lo = (ph->start < ph->end) ? ph->start : ph->end;
                        int hi = (ph->start < ph->end) ? ph->end   : ph->start;
                        if (target < lo) target = lo;
                        if (target > hi) target = hi;

                        printf("[%3d/%d min] ", i, steps);
                        sleep(60);
                        tuya_reconnect(d);
                        set_temp(d, target);
                }

                if (remainder > 0) {
                        printf("[holding %d sec] ", remainder);
                        sleep(remainder);
                }
        }

        printf("\ndone.\n");
        return 0;
}

/* ------------------------------------------------------------------ */
/*  Usage                                                              */
/* ------------------------------------------------------------------ */

static void
usage(const char *prog)
{
        fprintf(stderr,
"Usage: %s [-v] [-n] [-c FILE] COMMAND [ARGS] [COMMAND [ARGS]] ...\n"
"\n"
"Local Tuya controller for Inkbird sous vide cookers.\n"
"Reads credentials from $XDG_CONFIG_HOME/seatuya/config [sousvide].\n"
"\n"
"Commands (chain SoX-style):\n"
"  status                display all data points\n"
"  read                  read current temperature\n"
"  temp TEMP             set target temperature\n"
"  ramp START END TIME   linear temperature ramp\n"
"  hold TEMP TIME        hold at temperature\n"
"  off                   power off\n"
"\n"
"Temperature: NUMBER with optional C or F suffix (default: Celsius).\n"
"  Examples:  50C   122F   37.5\n"
"\n"
"Time: M:SS, HH:MM:SS, or bare minutes.\n"
"  Examples:  5:00   1:30:00   45\n"
"\n"
"Examples:\n"
"  %s -v ramp 25C 50C 30:00 hold 50C 30:00\n"
"  %s temp 55C hold 55C 1:00:00\n"
"  %s -n ramp 20C 85C 60:00\n"
"\n"
"Power-off is implicit at end of every chain and on crash/kill.\n"
"\n"
"Global options:\n"
"  -c FILE    config file path\n"
"  -i IP      override device IP address\n"
"  -n         dry run (print schedule, no device connection)\n"
"  -v         verbose (timestamped log to stderr)\n",
            prog, prog, prog, prog);
}

/* ------------------------------------------------------------------ */
/*  Main                                                               */
/* ------------------------------------------------------------------ */

int
main(int argc, char **argv)
{
        const char *prog = progname(argv[0]);
        int opt, i;
        char config_path[512];
        bool dry_run = false;

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

        while ((opt = getopt(argc, argv, "+c:i:nhv")) != -1) {
                switch (opt) {
                case 'c': strncpy(config_path, optarg,
                            sizeof(config_path) - 1); break;
                case 'i': strncpy(override_ip, optarg,
                            sizeof(override_ip) - 1); break;
                case 'n': dry_run = true; break;
                case 'v': verbose = true; break;
                default:
                        usage(prog);
                        return (opt == 'h') ? 0 : 1;
                }
        }

        if (optind >= argc) { usage(prog); return 1; }

        struct config cfg;
        if (read_config(config_path, &cfg) != 0) return 1;
        if (override_ip[0]) {
                strncpy(cfg.ip, override_ip, sizeof(cfg.ip) - 1);
        } else if (cfg.mac[0]) {
                resolve_mac(&cfg);
        }

        /* Build phase list from the SoX-style command chain */
        struct phase *phases = NULL;
        int nphases = 0, nalloc = 0;

        i = optind;
        while (i < argc) {
                const char *cmd = argv[i++];

                if (strcmp(cmd, "status") == 0) {
                        if (dry_run) {
                                printf("[dry run] status\n"); continue;
                        }
                        tuya_device_t *d = tuya_create(cfg.device_id,
                            cfg.ip, cfg.local_key, cfg.version);
                        if (!d) {
                                fprintf(stderr, "error: connect failed\n");
                                free(phases); return 1;
                        }
                        cmd_status(d);
                        tuya_disconnect(d); tuya_destroy(d);
                        continue;
                }

                if (strcmp(cmd, "read") == 0) {
                        if (dry_run) {
                                printf("[dry run] read\n"); continue;
                        }
                        tuya_device_t *d = tuya_create(cfg.device_id,
                            cfg.ip, cfg.local_key, cfg.version);
                        if (!d) {
                                fprintf(stderr, "error: connect failed\n");
                                free(phases); return 1;
                        }
                        cmd_read(d);
                        tuya_disconnect(d); tuya_destroy(d);
                        continue;
                }

                if (strcmp(cmd, "off") == 0) {
                        if (dry_run) {
                                printf("[dry run] off\n"); continue;
                        }
                        tuya_device_t *d = tuya_create(cfg.device_id,
                            cfg.ip, cfg.local_key, cfg.version);
                        if (!d) {
                                fprintf(stderr, "error: connect failed\n");
                                free(phases); return 1;
                        }
                        power_off(d);
                        tuya_disconnect(d); tuya_destroy(d);
                        continue;
                }

                if (strcmp(cmd, "temp") == 0) {
                        if (i >= argc) {
                                fprintf(stderr, "error: temp needs TEMP\n");
                                free(phases); return 1;
                        }
                        bool ok;
                        int t = parse_temp(argv[i++], &ok);
                        if (!ok) {
                                fprintf(stderr, "error: bad temp '%s'\n",
                                    argv[i - 1]);
                                free(phases); return 1;
                        }
                        if (dry_run) {
                                printf("[dry run] temp %.1f C\n", t / 10.0);
                                continue;
                        }
                        tuya_device_t *d = tuya_create(cfg.device_id,
                            cfg.ip, cfg.local_key, cfg.version);
                        if (!d) {
                                fprintf(stderr, "error: connect failed\n");
                                free(phases); return 1;
                        }
                        set_temp(d, t);
                        tuya_disconnect(d); tuya_destroy(d);
                        continue;
                }

                if (strcmp(cmd, "ramp") == 0 || strcmp(cmd, "hold") == 0) {
                        bool is_hold = (strcmp(cmd, "hold") == 0);
                        int needed = is_hold ? 2 : 3;
                        if (i + needed > argc) {
                                fprintf(stderr, "error: %s needs %d arg(s)\n",
                                    cmd, needed);
                                free(phases); return 1;
                        }
                        bool ok;
                        struct phase ph;
                        memset(&ph, 0, sizeof(ph));

                        if (is_hold) {
                                ph.start = parse_temp(argv[i++], &ok);
                                ph.end   = ph.start;
                                ph.is_hold = true;
                        } else {
                                ph.start = parse_temp(argv[i++], &ok);
                                if (!ok) {
                                        fprintf(stderr, "error: bad temp '%s'\n",
                                            argv[i - 1]);
                                        free(phases); return 1;
                                }
                                ph.end = parse_temp(argv[i++], &ok);
                                ph.is_hold = (ph.start == ph.end);
                        }
                        if (!ok) {
                                fprintf(stderr, "error: bad temp '%s'\n",
                                    argv[i - 1]);
                                free(phases); return 1;
                        }
                        ph.duration_secs = parse_duration(argv[i++], &ok);
                        if (!ok || ph.duration_secs < 1) {
                                fprintf(stderr, "error: bad duration '%s'\n",
                                    argv[i - 1]);
                                free(phases); return 1;
                        }

                        if (nphases >= nalloc) {
                                nalloc = nalloc ? nalloc * 2 : 4;
                                phases = realloc(phases,
                                    (size_t)nalloc * sizeof(*phases));
                                if (!phases) {
                                        fprintf(stderr, "error: out of memory\n");
                                        return 1;
                                }
                        }
                        phases[nphases++] = ph;
                        continue;
                }

                fprintf(stderr, "error: unknown command '%s'\n", cmd);
                usage(prog); free(phases); return 1;
        }

        /* Execute accumulated phases */
        if (nphases > 0) {
                if (dry_run) {
                        printf("[dry run]\n");
                        for (int p = 0; p < nphases; p++) {
                                struct phase *ph = &phases[p];
                                const char *label =
                                    ph->is_hold ? "hold" : "ramp";
                                printf("  %s  %.1f C", label,
                                    ph->start / 10.0);
                                if (!ph->is_hold)
                                        printf(" -> %.1f C", ph->end / 10.0);
                                printf("  %d:%02d\n",
                                    ph->duration_secs / 60,
                                    ph->duration_secs % 60);
                        }
                        printf("  off (implicit)\n");
                        free(phases);
                        return 0;
                }

                tuya_device_t *d = tuya_create(cfg.device_id,
                    cfg.ip, cfg.local_key, cfg.version);
                if (!d) {
                        fprintf(stderr, "error: connect to %s failed\n",
                            cfg.ip);
                        free(phases); return 1;
                }

                vlog("connected to %s (v%s)\n", cfg.ip, cfg.version);
                atexit_dev = d;
                atexit(cleanup_poweroff);
                signal(SIGINT, signal_handler);
                signal(SIGTERM, signal_handler);
                char *resp = tuya_turn_on(d, DPS_POWER);
                if (resp) {
                        printf("power on — success.\n");
                        if (verbose) printf("  %s\n", resp);
                        tuya_free_string(resp);
                } else {
                        printf("power on — FAILED.\n");
                }
                if (verbose) print_response(tuya_status(d));

                int r = run_ramp(d, phases, nphases, true);
                /* implicit off at end of chain */
                if (!dry_run) cleanup_poweroff();
                free(phases);
                return r;
        }


        return 0;
}
