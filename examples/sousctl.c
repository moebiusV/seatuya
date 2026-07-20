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
static time_t start_time;

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

static void
tprintf(const char *fmt, ...)
{
        time_t now = time(NULL);
        struct tm *lt = localtime(&now);
        fprintf(stdout, "[%02d:%02d:%02d] ",
            lt->tm_hour, lt->tm_min, lt->tm_sec);
        va_list ap;
        va_start(ap, fmt);
        vprintf(fmt, ap);
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

/* Temperature tolerance for catch-up waiting - 0.5 C.  The Inkbird
   PID typically settles within this band. */
static const int DPS_TOLERANCE     = 5;
static const int POLL_INTERVAL_SEC = 60;

/* Fault recovery: probe backoff schedule in seconds, capped at last value.
   E2 (dry-run / low-water) is auto-recoverable with unlimited attempts.
   Non-E2 faults get at most MAX_NON_E2_PROBES attempts then alarm. */
static const int PROBE_BACKOFF[]   = {30, 60, 120};
static const int PROBE_BACKOFF_CAP = 120;
static const int PROBE_WINDOW_SEC  = 10;
static const int FAULT_POLL_SEC    = 5;
static const int MAX_NON_E2_PROBES = 2;

/* DP 107 fault bitfield.  Observed value 3 (= bits 0+1) on ISV-300W
   for both E2 (dry-run) and E3 (low-water).  Bit 1 is the E2 indicator
   per the standard Tuya bit-per-E-code convention. */
static const int FAULT_E2_MASK     = 2;   /* bit 1 = dry-run / low-water */

static const char *
fault_bits_str(int code, char *buf, size_t bufsz)
{
        int faults = code & ~1;
        int len = 0;
        if (faults == 0) {
                snprintf(buf, bufsz, "none (running, raw 0x%02x)", code);
        } else {
                for (int b = 1; b < 8; b++)
                        if (code & (1 << b))
                                len += snprintf(buf + len,
                                    bufsz - (size_t)len,
                                    "E%d ", b + 1);
                snprintf(buf + len, bufsz - (size_t)len,
                    "(raw 0x%02x)", code);
        }
        return buf;
}

/* Temperature heuristic: if bath temp rises within this many decicelsius
   of the pre-fault temperature while faulted, the stick is probably
   re-immersed — probe immediately. */
static const int REIMMERSE_DELTA   = 30;  /* 3.0 C */

static void
print_elapsed(void)
{
        time_t now = time(NULL);
        int elapsed = (int)(now - start_time);
        struct tm *lt = localtime(&now);
        tprintf("elapsed %d:%02d:%02d\n",
            elapsed / 3600, (elapsed % 3600) / 60, elapsed % 60);
}

static void
cleanup_poweroff(void)
{
        tuya_device_t *d = atexit_dev;
        if (!d) return;
        atexit_dev = NULL;
        fprintf(stderr, "\n");
        print_elapsed();
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
        if (resp) { tprintf("  %s\n", resp); tuya_free_string(resp); }
}

static void
set_temp(tuya_device_t *d, int target_c_x10)
{
        double c = target_c_x10 / 10.0;
        vlog("target %.1f C / %.1f F\n", c, c_to_f(c));
        char *resp = tuya_set_value_int(d, DPS_TARGET_TEMP, target_c_x10);
        if (resp) {
                vlog("target %.1f C / %.1f F — success.\n", c, c_to_f(c));
                if (verbose) tprintf("  %s\n", resp);
                tuya_free_string(resp);
        } else {
                vlog("target %.1f C / %.1f F — no ack\n", c, c_to_f(c));
        }
}

static void
power_off(tuya_device_t *d)
{
        char *resp = tuya_turn_off(d, DPS_POWER);
        if (resp) {
                tprintf("power off\n");
                if (verbose) tprintf("  %s\n", resp);
                tuya_free_string(resp);
        } else {
                vlog("power off — no ack\n");
        }
}

/* ------------------------------------------------------------------ */
/*  Temperature helpers                                                 */
/* ------------------------------------------------------------------ */

/*
 * Extract DP 104 (current water temperature) from a status JSON string.
 * Returns Celsius * 10 on success, or -1 if the value is not found.
 */
static int
parse_dp104(const char *json)
{
        const char *p = strstr(json, "\"104\"");
        if (!p) return -1;
        p = strchr(p, ':');
        if (!p) return -1;
        return (int)strtol(p + 1, NULL, 10);
}

/*
 * Extract DP 102 (status string) from a status JSON string.
 * Writes up to bufsz-1 chars into buf, returns buf on success or NULL.
 */
static const char *
parse_dp102(const char *json, char *buf, size_t bufsz)
{
        const char *p = strstr(json, "\"102\"");
        if (!p) return NULL;
        p = strchr(p, ':');
        if (!p) return NULL;
        if (*p != '"') return NULL;
        p++;
        const char *end = strchr(p, '"');
        if (!end) return NULL;
        size_t len = (size_t)(end - p);
        if (len >= bufsz) len = bufsz - 1;
        memcpy(buf, p, len);
        buf[len] = '\0';
        return buf;
}

/*
 * Extract DP 107 (fault bitfield) from a status JSON string.
 * Returns the raw fault code, or 0 if not found.
 */
static int
parse_dp107(const char *json)
{
        const char *p = strstr(json, "\"107\"");
        if (!p) return 0;
        p = strchr(p, ':');
        if (!p) return 0;
        return (int)strtol(p + 1, NULL, 10);
}

/*
 * Read current water temperature (DP 104) from the device.
 * Returns Celsius * 10 on success, or -1 on error.
 */
static int
read_current_temp(tuya_device_t *d)
{
        char *resp = tuya_status(d);
        if (!resp) return -1;
        int val = parse_dp104(resp);
        tuya_free_string(resp);
        return val;
}

/*
 * Fault recovery state machine.
 *
 * RUNNING -> FAULTED (107 != 0) -> PROBING -> RUNNING (or ALARM).
 *
 * E2 (dry-run / low-water, bit 1) gets unlimited probe attempts with
 * backoff 30 -> 60 -> 120 s cap.  Non-E2 faults get at most 2 probes.
 *
 * During FAULTED, polls at 5 s.  If bath temperature rises to within
 * 3 C of the pre-fault reading, probes immediately (the stick is
 * probably re-immersed).  Each probe sends CONTROL_NEW 101=true and
 * observes for 10 s: 107==0 and 102=="working" sustained = success.
 *
 * On success, re-asserts the target setpoint (DP 103) in case the
 * firmware cleared it.  Returns normally so the caller resumes its
 * ramp/hold loop.  On ALARM, exits the process.
 */
static void
recover_from_fault(tuya_device_t *d, int target_c_x10)
{
        int pre_fault_temp = target_c_x10;  /* best guess at time of fault */
        int fault_code = 0;
        bool is_e2;
        int max_probes, probe_count = 0, backoff_idx = 0;
        int nlevels = (int)(sizeof(PROBE_BACKOFF) / sizeof(PROBE_BACKOFF[0]));

        /* Read fault code to classify */
        {
                char *resp = tuya_status(d);
                if (resp) {
                        const char *p = strstr(resp, "\"107\"");
                        if (p) {
                                p = strchr(p, ':');
                                if (p) fault_code = (int)strtol(p+1,NULL,10);
                        }
                        /* Snapshot current temp for heuristic */
                        int cur = parse_dp104(resp);
                        if (cur >= 0) pre_fault_temp = cur;
                        tuya_free_string(resp);
                }
        }

        is_e2     = (fault_code & FAULT_E2_MASK) != 0;
        max_probes = is_e2 ? 9999 : MAX_NON_E2_PROBES;

        {
                char fb[64];
                tprintf("  ! device faulted: %s — %s\n",
                    fault_bits_str(fault_code, fb, sizeof(fb)),
                    is_e2 ? "refill water and device will recover"
                          : "check device, limited retries");
        }

        /* Turn off to silence beeping */
        tuya_turn_off(d, DPS_POWER);

        while (probe_count < max_probes) {
                int delay = (backoff_idx < nlevels)
                    ? PROBE_BACKOFF[backoff_idx] : PROBE_BACKOFF_CAP;

                /* Wait with temperature heuristic */
                {
                        int elapsed = 0;
                        while (elapsed < delay) {
                                sleep(FAULT_POLL_SEC);
                                elapsed += FAULT_POLL_SEC;
                                tuya_reconnect(d);
                                char *resp = tuya_status(d);
                                if (!resp) continue;
                                int cur = parse_dp104(resp);
                                tuya_free_string(resp);
                                if (cur >= 0
                                    && (pre_fault_temp - cur)
                                        <= REIMMERSE_DELTA) {
                                        tprintf("  temp recovering (%.1f C)"
                                            " — probing early\n",
                                            cur / 10.0);
                                        break;
                                }
                        }
                }

                /* Probe */
                probe_count++;
                vlog("probe %d/%d: restarting\n", probe_count, max_probes);
                tuya_reconnect(d);
                tuya_turn_on(d, DPS_POWER);

                /* Observe for PROBE_WINDOW_SEC */
                bool stuck = true;
                for (int w = 0; w < PROBE_WINDOW_SEC; w += 2) {
                        sleep(2);
                        char *resp = tuya_status(d);
                        if (!resp) continue;
                        int  f107 = 0;
                        char stat[32] = {0};
                        {
                                const char *p=strstr(resp,"\"107\"");
                                if(p){p=strchr(p,':');
                                    if(p)f107=(int)strtol(p+1,NULL,10);}
                        }
                        parse_dp102(resp, stat, sizeof(stat));
                        tuya_free_string(resp);
                        /* ISV-300W: after recovery, 107=1 (not 0) is
                   the normal running state.  Check that the
                   E2/dry-run bit cleared and device is on. */
                if ((f107 & FAULT_E2_MASK) != 0) {
                                tprintf("  re-faulted after %d s"
                                    " (107=0x%02x, st=%s)\n",
                                    w + 2, f107, stat);
                                tuya_turn_off(d, DPS_POWER);
                                stuck = false;
                                break;
                        }
                }

                if (stuck) {
                        tprintf("  probe successful — resuming\n");
                        /* Re-assert target setpoint in case firmware
                           cleared it across the fault */
                        tuya_set_value_int(d, DPS_TARGET_TEMP,
                            target_c_x10);
                        return;
                }

                /* Advance backoff */
                if (backoff_idx < nlevels - 1) backoff_idx++;
        }

        /* ALARM: max probes exhausted (non-E2 path only) */
        {
                char fb[64];
                tprintf("ALARM: %s — max %d probes failed,"
                    " device left off."
                    "  Check device and restart manually.\n",
                    fault_bits_str(fault_code, fb, sizeof(fb)),
                    MAX_NON_E2_PROBES);
        }
        print_elapsed();
        exit(1);
}

/*
 * Poll the device until current temperature reaches target (Celsius * 10)
 * within DPS_TOLERANCE.  Polls every POLL_INTERVAL_SEC seconds.
 * Monitors for device faults (low water, etc.) and auto-recovers.
 * No timeout -- if the heater is slow, we wait.  SIGINT to abort.
 */
static void
wait_for_temp(tuya_device_t *d, int target_c_x10)
{
        int first = 1;
        /* Let device stabilise after power-on / set_temp before
           polling — avoids false E2 trigger on transitional 107. */
        sleep(5);
        for (;;) {
                tuya_reconnect(d);
                char *resp = tuya_status(d);
                if (!resp) {
                        vlog("error reading status, retrying...\n");
                        sleep(POLL_INTERVAL_SEC);
                        continue;
                }
                int current = parse_dp104(resp);
                int dp107   = parse_dp107(resp);
                char status[32];
                parse_dp102(resp, status, sizeof(status));
                tuya_free_string(resp);

                if ((dp107 & FAULT_E2_MASK) != 0) {
                        recover_from_fault(d, target_c_x10);
                        first = 1;
                        continue;
                }

                if (current < 0) {
                        vlog("error reading temp, retrying...\n");
                        sleep(POLL_INTERVAL_SEC);
                        continue;
                }
                if (abs(current - target_c_x10) <= DPS_TOLERANCE) {
                        vlog("reached %.1f C\n", current / 10.0);
                        return;
                }
                if (first) {
                        vlog("waiting for water to reach %.1f C...\n",
                            target_c_x10 / 10.0);
                        first = 0;
                }
                vlog("current %.1f C, target %.1f C (delta %.1f)\n",
                    current / 10.0, target_c_x10 / 10.0,
                    (target_c_x10 - current) / 10.0);
                sleep(POLL_INTERVAL_SEC);
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
        tprintf("ISV-300W status:\n  %s\n\n", resp);

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

        tprintf("  Power:          %s\n", power ? "ON" : "OFF");
        tprintf("  Status:         %s\n", status[0] ? status : "?");
        tprintf("  Current:        %.1f C / %.1f F\n",
            current / 10.0, c_to_f(current / 10.0));
        tprintf("  Target:         %.1f C / %.1f F\n",
            target / 10.0, c_to_f(target / 10.0));
        tprintf("  Timer:          %d min (remaining: %d)\n", timer, remain);
        tprintf("  Unit:           %s\n", unit ? "Celsius" : "Fahrenheit");
        tprintf("  Fault:          %d\n", fault);
        tprintf("  Recipe:         %d\n", recipe);
        tprintf("  Calibration:    %.1f C\n", cal / 10.0);
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
        int val = parse_dp104(resp);
        if (val >= 0) {
                tprintf("%.1f C / %.1f F — success.\n",
                    val / 10.0, c_to_f(val / 10.0));
                if (verbose) tprintf("  %s\n", resp);
        } else {
                tprintf("read — FAILED.\n");
                tprintf("  %s\n", resp);
        }
        tuya_free_string(resp);
}

/* ------------------------------------------------------------------ */
/*  Ramp / hold                                                        */
/* ------------------------------------------------------------------ */

struct phase {
        int    start, end;       /* Celsius * 10 */
        int    duration_secs;
        bool   is_hold;
        bool   is_pause;
        bool   is_temp;
};

static int
run_ramp(tuya_device_t *d, struct phase *phases, int nphases, bool poweroff)
{
        (void)poweroff;
        for (int pi = 0; pi < nphases; pi++) {
                struct phase *ph = &phases[pi];
                int steps    = ph->duration_secs / 60;
                int remainder = ph->duration_secs % 60;
                time_t phase_start = time(NULL);

                if (ph->is_temp) {
                        vlog("phase %d: temp %.1f C\n",
                            pi + 1, ph->start / 10.0);
                        set_temp(d, ph->start);
                        wait_for_temp(d, ph->start);
                        tprintf("temp %.1f C\n", ph->start / 10.0);
                        continue;
                }

                if (ph->is_pause) {
                        vlog("phase %d: pause %d:%02d\n",
                            pi + 1, ph->duration_secs / 60,
                            ph->duration_secs % 60);
                        tprintf("pause %d:%02d\n",
                            ph->duration_secs / 60, ph->duration_secs % 60);
                        sleep(ph->duration_secs);
                        continue;
                }

                if (steps < 1 && remainder == 0)
                        steps = 1;

                double step_d = (steps > 0)
                    ? (double)(ph->end - ph->start) / (double)steps : 0.0;

                if (ph->is_hold) {
                        vlog("phase %d: hold %.1f C for %d:%02d\n",
                            pi + 1, ph->start / 10.0,
                            ph->duration_secs / 60, ph->duration_secs % 60);

                        set_temp(d, ph->start);
                        wait_for_temp(d, ph->start);
                        {
                                int cur = read_current_temp(d);
                                tprintf("hold %.1f C for %d:%02d"
                                    " (currently %.1f C)\n",
                                    ph->start / 10.0,
                                    ph->duration_secs / 60,
                                    ph->duration_secs % 60,
                                    cur >= 0 ? cur / 10.0
                                             : ph->start / 10.0);
                        }

                        int hold_elapsed = 0;
                        int cold_since = -1;
                        int cold_max_delta = 0;

                        while (hold_elapsed < ph->duration_secs) {
                                int chunk = POLL_INTERVAL_SEC;
                                if (hold_elapsed + chunk > ph->duration_secs)
                                        chunk = ph->duration_secs - hold_elapsed;
                                sleep(chunk);
                                hold_elapsed += chunk;

                                tuya_reconnect(d);
                                char *resp = tuya_status(d);
                                if (!resp) continue;
                                int actual = parse_dp104(resp);
                                int dp107  = parse_dp107(resp);
                                char status[32];
                                parse_dp102(resp, status, sizeof(status));
                                tuya_free_string(resp);

                                if ((dp107 & FAULT_E2_MASK) != 0) {
                                        recover_from_fault(d, ph->start);
                                        cold_since = -1;
                                        cold_max_delta = 0;
                                        continue;
                                }

                                if (actual < 0) continue;

                                int delta = ph->start - actual;
                                if (delta > 20) {
                                        if (cold_since < 0) {
                                                cold_since = hold_elapsed;
                                                cold_max_delta = delta;
                                                tprintf("  ! dropped to %.1f C"
                                                    " (%.1f C below target)\n",
                                                    actual / 10.0, delta / 10.0);
                                        } else if (delta > cold_max_delta) {
                                                cold_max_delta = delta;
                                        }
                                } else if (cold_since >= 0
                                    && delta <= DPS_TOLERANCE) {
                                        int dur = hold_elapsed - cold_since;
                                        tprintf("  recovered after %d:%02d"
                                            " (max deviation %.1f C)\n",
                                            dur / 60, dur % 60,
                                            cold_max_delta / 10.0);
                                        cold_since = -1;
                                        cold_max_delta = 0;
                                }
                        }
                } else {
                        vlog("phase %d: ramp %.1f -> %.1f C over %d:%02d"
                            " (%d steps)\n",
                            pi + 1, ph->start / 10.0, ph->end / 10.0,
                            ph->duration_secs / 60, ph->duration_secs % 60,
                            steps);
                        tprintf("ramp %.1f -> %.1f C over %d:%02d"
                            " (%d steps of %.2f C)\n",
                            ph->start / 10.0, ph->end / 10.0,
                            ph->duration_secs / 60, ph->duration_secs % 60,
                            steps, step_d / 10.0);

                        set_temp(d, ph->start);

                        for (int i = 1; i <= steps; i++) {
                                int target = ph->start
                                    + (int)round(step_d * i);
                                int lo = (ph->start < ph->end)
                                    ? ph->start : ph->end;
                                int hi = (ph->start < ph->end)
                                    ? ph->end   : ph->start;
                                if (target < lo) target = lo;
                                if (target > hi) target = hi;

                                vlog("[%3d/%d min] ", i, steps);
                                sleep(60);
                                tuya_reconnect(d);
                                set_temp(d, target);
                                int actual = read_current_temp(d);
                                if (actual >= 0) {
                                        vlog("target %.1f C,"
                                            " actual %.1f C%s\n",
                                            target / 10.0, actual / 10.0,
                                            (abs(actual - target)
                                                > DPS_TOLERANCE)
                                                ? " (catching up)" : "");
                                }
                        }

                        if (remainder > 0) {
                                tprintf("[holding %d sec] ", remainder);
                                sleep(remainder);
                        }

                        /* Catch-up at phase boundary:
                           block until water reaches end temp before
                           transitioning to the next phase. */
                        wait_for_temp(d, ph->end);
                }

                /* Report overtime if the phase took significantly
                   longer than planned. */
                time_t phase_end = time(NULL);
                int elapsed = (int)(phase_end - phase_start);
                if (elapsed > ph->duration_secs + 60) {
                        int overtime = elapsed - ph->duration_secs;
                        tprintf("  phase took %d:%02d"
                            " (planned %d:%02d, +%d:%02d overtime)\n",
                            elapsed / 60, elapsed % 60,
                            ph->duration_secs / 60, ph->duration_secs % 60,
                            overtime / 60, overtime % 60);
                }
        }

        tprintf("\ndone.\n");
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
"  pause TIME            pause (device keeps running)\n"
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
"Ramp durations are minimums: if the water hasn't reached the target\n"
"by the end of a phase, sousctl waits until it catches up before\n"
"starting the next phase.  During holds, large temperature drops\n"
"(e.g., from adding cold water) are detected and reported.\n"
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
        start_time = time(NULL);
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
                                tprintf("[dry run] status\n"); continue;
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
                                tprintf("[dry run] read\n"); continue;
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
                                tprintf("[dry run] off\n"); continue;
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
                        /* If phases already exist, accumulate so temp
                           interleaves correctly with ramp/hold/pause. */
                        if (nphases > 0) {
                                struct phase ph;
                                memset(&ph, 0, sizeof(ph));
                                ph.start   = t;
                                ph.end     = t;
                                ph.is_temp = true;
                                if (nphases >= nalloc) {
                                        nalloc = nalloc ? nalloc * 2 : 4;
                                        phases = realloc(phases,
                                            (size_t)nalloc * sizeof(*phases));
                                        if (!phases) {
                                                fprintf(stderr,
                                                    "error: out of memory\n");
                                                return 1;
                                        }
                                }
                                phases[nphases++] = ph;
                                continue;
                        }
                        if (dry_run) {
                                tprintf("[dry run] temp %.1f C\n", t / 10.0);
                                continue;
                        }
                        tuya_device_t *d = tuya_create(cfg.device_id,
                            cfg.ip, cfg.local_key, cfg.version);
                        if (!d) {
                                fprintf(stderr, "error: connect failed\n");
                                free(phases); return 1;
                        }
                        {
                                char *resp = tuya_turn_on(d, DPS_POWER);
                                if (resp) {
                                        if (verbose) tprintf("  %s\n", resp);
                                        tuya_free_string(resp);
                                }
                        }
                        set_temp(d, t);
                        tprintf("temp %.1f C\n", t / 10.0);
                        if (i < argc) wait_for_temp(d, t);
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

                if (strcmp(cmd, "pause") == 0) {
                        if (i >= argc) {
                                fprintf(stderr, "error: pause needs TIME\n");
                                free(phases); return 1;
                        }
                        bool ok;
                        struct phase ph;
                        memset(&ph, 0, sizeof(ph));
                        ph.is_pause = true;
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
                        tprintf("[dry run]\n");
                        for (int p = 0; p < nphases; p++) {
                                struct phase *ph = &phases[p];
                                if (ph->is_temp) {
                                        tprintf("  temp  %.1f C\n",
                                            ph->start / 10.0);
                                        continue;
                                }
                                if (ph->is_pause) {
                                        tprintf("  pause %d:%02d\n",
                                            ph->duration_secs / 60,
                                            ph->duration_secs % 60);
                                        continue;
                                }
                                const char *label =
                                    ph->is_hold ? "hold" : "ramp";
                                char buf[128];
                                int len = snprintf(buf, sizeof(buf),
                                    "  %s  %.1f C", label,
                                    ph->start / 10.0);
                                if (!ph->is_hold)
                                        len += snprintf(buf + len,
                                            sizeof(buf) - (size_t)len,
                                            " -> %.1f C", ph->end / 10.0);
                                snprintf(buf + len,
                                    sizeof(buf) - (size_t)len,
                                    "  %d:%02d\n",
                                    ph->duration_secs / 60,
                                    ph->duration_secs % 60);
                                tprintf("%s", buf);
                        }
                        tprintf("  off (implicit)\n");
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
                tuya_turn_on(d, DPS_POWER);
                sleep(2);
                {
                        char *s = tuya_status(d);
                        bool on = false;
                        if (s) {
                                const char *p = strstr(s, "\"101\"");
                                if (p) {
                                        p = strchr(p, ':');
                                        if (p) on = (strncmp(p+1,"true",4)==0);
                                }
                                if (verbose) tprintf("  %s\n", s);
                                tuya_free_string(s);
                        }
                        tprintf("power %s\n", on ? "on" : "OFF — check device");
                }

                int r = run_ramp(d, phases, nphases, true);
                /* implicit off at end of chain */
                if (!dry_run) cleanup_poweroff();
                free(phases);
                return r;
        }


        print_elapsed();
        return 0;
}
