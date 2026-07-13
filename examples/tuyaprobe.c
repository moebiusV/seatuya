/*
 * tuyaprobe -- ground-truth prober for a mute Tuya device.
 *
 * A Tuya device that accepts TCP on 6668 but never answers any
 * protocol frame has one of two things behind the port:
 *
 *   (a) an application that reads frames and silently discards them
 *       (wrong key or protocol variant -- keep hunting), or
 *   (b) no application reading at all: the SDK opened the listener
 *       but the firmware's LAN command handler is disabled/absent.
 *
 * Both look identical to tinytuya/seatuya.  TCP flow control tells
 * them apart: shrink the local send buffer to its minimum and write
 * junk with a send timeout.  If nothing reads the peer socket, the
 * peer's kernel receive buffer fills, its window closes, and writes
 * stall after peer-buffer-sized progress (a few KB on embedded
 * lwIP/RTOS stacks, tens of KB at most).  If an application is
 * draining the socket, writes proceed indefinitely.
 *
 * The verdict is transport-level ground truth, independent of keys,
 * protocol versions, and frame formats.
 *
 * Phases:
 *   1. connect timing
 *   2. read-consumption test (the decisive one)
 *   3. protocol frames per version, fresh connection each,
 *      hexdump of anything received   (needs -d and -k)
 *   4. idle lifecycle: does the device FIN/RST an idle connection?
 *
 * Usage:
 *   tuyaprobe -i IP [-p port] [-d device_id] [-k keyfile] [-t secs]
 *
 * The key is read from a FILE, never argv, because Tuya local keys
 * routinely contain shell metacharacters.
 *
 * Note: phase 2 sends non-protocol garbage.  Well-behaved firmware
 * drops it or resets the connection; if the device misbehaves
 * afterwards, power-cycle it.
 */

#include <seatuya.h>

#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

enum {
	DEFAULT_PORT     = 6668,
	ALT_PORT         = 6669,        /* TLS-wrapped command variant */
	DEFAULT_WAIT     = 5,
	JUNK_CHUNK       = 1024,
	JUNK_LIMIT       = 512 * 1024,  /* consumption => app reading  */
	SMALL_SNDBUF     = 4096,
	SEND_TIMEOUT_SEC = 3,
	IDLE_HOLD_SEC    = 10,
	RECV_BUFSIZE     = 4096,
	MAX_TCP_PORTS    = 8
};

static const char *arg_ip = NULL;
static int arg_ports[MAX_TCP_PORTS] = { DEFAULT_PORT, ALT_PORT };
static int arg_nports = 2;
static const char *arg_devid = NULL;
static char arg_key[128] = "";
static int arg_wait = DEFAULT_WAIT;

/* the port currently being probed (phases 2-4 operate one port at a time) */
static int arg_port = DEFAULT_PORT;

/* ------------------------------------------------------------------ */

static long long
now_ms(void)
{
	struct timeval tv;
	gettimeofday(&tv, NULL);
	return (long long)tv.tv_sec * 1000 + tv.tv_usec / 1000;
}

static int
tcp_connect(const char *ip, int port)
{
	int s = socket(AF_INET, SOCK_STREAM, 0);
	if (s < 0) {
		perror("socket");
		return -1;
	}
	struct sockaddr_in addr;
	memset(&addr, 0, sizeof(addr));
	addr.sin_family = AF_INET;
	addr.sin_port = htons((unsigned short)port);
	if (inet_pton(AF_INET, ip, &addr.sin_addr) != 1) {
		fprintf(stderr, "bad ip: %s\n", ip);
		close(s);
		return -1;
	}
	if (connect(s, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
		perror("connect");
		close(s);
		return -1;
	}
	return s;
}

static void
hexdump(const unsigned char *buf, int n)
{
	for (int i = 0; i < n; i += 16) {
		printf("    %04x  ", i);
		for (int j = 0; j < 16; j++) {
			if (i + j < n)
				printf("%02x ", buf[i + j]);
			else
				printf("   ");
		}
		printf(" ");
		for (int j = 0; j < 16 && i + j < n; j++) {
			unsigned char c = buf[i + j];
			putchar(c >= 32 && c < 127 ? c : '.');
		}
		printf("\n");
	}
}

/*
 * Wait up to wait_secs for data; hexdump anything that arrives.
 * Returns bytes received, 0 on silence, -1 on EOF/RST.
 */
static int
drain_and_report(int s, int wait_secs)
{
	long long deadline = now_ms() + (long long)wait_secs * 1000;
	int total = 0;

	for (;;) {
		long long remain = deadline - now_ms();
		if (remain <= 0)
			break;

		fd_set fds;
		FD_ZERO(&fds);
		FD_SET(s, &fds);
		struct timeval tv;
		tv.tv_sec = remain / 1000;
		tv.tv_usec = (remain % 1000) * 1000;

		int r = select(s + 1, &fds, NULL, NULL, &tv);
		if (r <= 0)
			break;

		unsigned char buf[RECV_BUFSIZE];
		int n = (int)recv(s, buf, sizeof(buf), 0);
		if (n == 0) {
			printf("    connection closed by peer (FIN)\n");
			return total > 0 ? total : -1;
		}
		if (n < 0) {
			printf("    recv error: %s (RST?)\n",
			    strerror(errno));
			return total > 0 ? total : -1;
		}
		printf("    received %d bytes:\n", n);
		hexdump(buf, n);
		total += n;
	}
	return total;
}

/* ------------------------------------------------------------------ */
/*  Phase 2: read-consumption test                                    */
/* ------------------------------------------------------------------ */

static void
phase_consumption(void)
{
	printf("\n=== PHASE 2: read-consumption test ===\n");
	printf("(shrunken send buffer + send timeout: stall position "
	       "reveals whether\n anything reads the peer socket)\n");

	int s = tcp_connect(arg_ip, arg_port);
	if (s < 0)
		return;

	int sndbuf = SMALL_SNDBUF;
	setsockopt(s, SOL_SOCKET, SO_SNDBUF, &sndbuf, sizeof(sndbuf));
	socklen_t optlen = sizeof(sndbuf);
	getsockopt(s, SOL_SOCKET, SO_SNDBUF, &sndbuf, &optlen);
	printf("  effective local send buffer: %d bytes\n", sndbuf);

	struct timeval sto;
	sto.tv_sec = SEND_TIMEOUT_SEC;
	sto.tv_usec = 0;
	setsockopt(s, SOL_SOCKET, SO_SNDTIMEO, &sto, sizeof(sto));

	unsigned char junk[JUNK_CHUNK];
	memset(junk, 0x55, sizeof(junk));

	long long total = 0;
	long long t0 = now_ms();
	int stalled = 0, reset = 0;

	while (total < JUNK_LIMIT) {
		ssize_t n = send(s, junk, sizeof(junk), MSG_NOSIGNAL);
		if (n > 0) {
			total += n;
			continue;
		}
		if (n < 0 && (errno == EAGAIN || errno == EWOULDBLOCK)) {
			stalled = 1;      /* send timeout: window closed */
			break;
		}
		if (n < 0) {
			reset = 1;
			printf("  send error after %lld bytes: %s\n",
			    total, strerror(errno));
			break;
		}
	}
	long long elapsed = now_ms() - t0;

	printf("  bytes accepted: %lld in %lld ms\n", total, elapsed);

	/* check for RST/FIN/data triggered by the junk */
	unsigned char buf[RECV_BUFSIZE];
	struct timeval rto = { 1, 0 };
	setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, &rto, sizeof(rto));
	ssize_t rn = recv(s, buf, sizeof(buf), 0);
	if (rn == 0)
		printf("  peer closed connection (FIN) after junk\n");
	else if (rn < 0 && errno != EAGAIN && errno != EWOULDBLOCK)
		printf("  peer reset connection (%s)\n", strerror(errno));
	else if (rn > 0) {
		printf("  peer SENT %zd bytes in response to junk:\n", rn);
		hexdump(buf, (int)rn);
	}

	printf("\n  VERDICT: ");
	if (reset) {
		printf("connection reset mid-stream -- firmware actively\n"
		       "  rejects unparseable input; an application IS "
		       "watching the socket.\n  Protocol/key mismatch is "
		       "back on the table.\n");
	} else if (stalled) {
		printf("writes stalled at %lld bytes.\n", total);
		if (total <= 65536)
			printf("  The peer's receive buffer filled and "
			       "nothing drained it:\n  NO APPLICATION IS "
			       "READING port %d.  The LAN command handler\n"
			       "  is disabled or absent in this firmware.  "
			       "No key or protocol\n  variant will ever get "
			       "an answer from this port.\n", arg_port);
		else
			printf("  Stall came late (>64KB); peer read some "
			       "data then stopped.\n  Ambiguous -- rerun "
			       "and compare stall positions.\n");
	} else {
		printf("peer consumed %lld bytes without stalling:\n"
		       "  an application IS reading and silently discarding "
		       "frames.\n  The failure is at the protocol/key layer, "
		       "not firmware disable.\n  Recheck the key against the "
		       "IoT console device debug panel and\n  capture the "
		       "Smart Life app's local traffic.\n", total);
	}

	close(s);
}

/* ------------------------------------------------------------------ */
/*  Phase 3: protocol frames                                          */
/* ------------------------------------------------------------------ */

static void
send_frame(const char *label, const char *version,
           enum tuya_command cmd, const char *dps)
{
	printf("\n  --- %s ---\n", label);

	tuya_device_t *dev = tuya_alloc(version);
	if (!dev) {
		printf("    tuya_alloc(%s) failed\n", version);
		return;
	}
	tuya_set_credentials(dev, arg_devid, arg_key);

	char *payload = tuya_generate_payload(dev, cmd, arg_devid, dps);
	if (!payload) {
		printf("    payload generation failed\n");
		tuya_destroy(dev);
		return;
	}

	unsigned char frame[1024];
	int len = tuya_build_message(dev, frame, cmd, payload, arg_key);
	tuya_free_string(payload);
	if (len < 0) {
		printf("    frame build failed\n");
		tuya_destroy(dev);
		return;
	}

	int s = tcp_connect(arg_ip, arg_port);
	if (s < 0) {
		tuya_destroy(dev);
		return;
	}

	if (send(s, frame, (size_t)len, MSG_NOSIGNAL) != len) {
		printf("    send failed: %s\n", strerror(errno));
		close(s);
		tuya_destroy(dev);
		return;
	}
	printf("    sent %d bytes (v%s cmd %d), waiting %ds...\n",
	    len, version, (int)cmd, arg_wait);

	int got = drain_and_report(s, arg_wait);
	if (got == 0)
		printf("    silence\n");

	close(s);
	tuya_destroy(dev);
}

/*
 * Protocol 3.4/3.5 refuse ordinary commands until session
 * negotiation completes, so those versions are probed with the
 * negotiation opener itself: a device speaking that version MUST
 * answer SESS_KEY_NEG_START (even a wrong local key gets a reply;
 * the key is only verifiable one step later).  Silence here means
 * the version is not spoken or nothing is listening.
 */
static void
probe_negotiation(const char *version)
{
	printf("\n  --- %s session negotiation ---\n", version);

	tuya_device_t *dev = tuya_alloc(version);
	if (!dev) {
		printf("    tuya_alloc(%s) failed\n", version);
		return;
	}
	tuya_set_credentials(dev, arg_devid, arg_key);

	if (!tuya_connect(dev, arg_ip)) {
		printf("    connect failed\n");
		tuya_destroy(dev);
		return;
	}
	if (!tuya_negotiate_session_start(dev, arg_key)) {
		printf("    could not send SESS_KEY_NEG_START\n");
		tuya_disconnect(dev);
		tuya_destroy(dev);
		return;
	}
	printf("    SESS_KEY_NEG_START sent, waiting %ds...\n", arg_wait);

	unsigned char buf[1024];
	int total = 0;
	long long deadline = now_ms() + (long long)arg_wait * 1000;
	while (now_ms() < deadline) {
		int n = tuya_receive(dev, buf, sizeof(buf), 1);
		if (n > 0) {
			printf("    received %d bytes:\n", n);
			hexdump(buf, n);
			total += n;
			if (tuya_negotiate_session_finalize(dev, buf, n,
			        arg_key))
				printf("    session ESTABLISHED -- device "
				       "speaks %s and the key is GOOD\n",
				    version);
			else
				printf("    finalize failed -- device "
				       "speaks %s but the key is likely "
				       "WRONG\n", version);
			break;
		}
	}
	if (total == 0)
		printf("    silence\n");

	tuya_disconnect(dev);
	tuya_destroy(dev);
}

static void
phase_frames(void)
{
	printf("\n=== PHASE 3: protocol frames "
	       "(fresh connection each) ===\n");

	/* null-DP map for device22-style CONTROL_NEW status query */
	char nulldps[256];
	snprintf(nulldps, sizeof(nulldps),
	    "{\"101\":null,\"102\":null,\"103\":null,\"104\":null,"
	    "\"105\":null,\"106\":null,\"107\":null,\"108\":null,"
	    "\"109\":null,\"110\":null}");

	send_frame("3.3 HEART_BEAT",   "3.3", TUYA_CMD_HEART_BEAT,  NULL);
	send_frame("3.3 DP_QUERY",     "3.3", TUYA_CMD_DP_QUERY,    NULL);
	send_frame("3.3 CONTROL_NEW null-DPs (device22 status)",
	                               "3.3", TUYA_CMD_CONTROL_NEW, nulldps);
	send_frame("3.1 DP_QUERY",     "3.1", TUYA_CMD_DP_QUERY,    NULL);
	probe_negotiation("3.4");
	probe_negotiation("3.5");
}

/* ------------------------------------------------------------------ */

static int
read_keyfile(const char *path)
{
	FILE *f = fopen(path, "r");
	if (!f) {
		perror(path);
		return -1;
	}
	if (!fgets(arg_key, sizeof(arg_key), f)) {
		fclose(f);
		return -1;
	}
	fclose(f);
	char *nl = strpbrk(arg_key, "\r\n");
	if (nl)
		*nl = '\0';
	return (int)strlen(arg_key);
}

static void
usage(const char *prog)
{
	fprintf(stderr,
	    "usage: %s -i IP [-p port | -P p1,p2,...] [-d device_id] "
	    "[-k keyfile] [-t secs]\n"
	    "  -i IP        device address (required)\n"
	    "  -p PORT      probe a single TCP port\n"
	    "  -P LIST      probe a comma-separated port list\n"
	    "               (default: %d,%d)\n"
	    "  -d ID        device id (enables phase 3)\n"
	    "  -k FILE      file containing the local key, first line\n"
	    "  -t SECS      per-frame wait     (default %d)\n",
	    prog, DEFAULT_PORT, ALT_PORT, DEFAULT_WAIT);
}

static void
probe_one_port(int port)
{
	arg_port = port;

	printf("\n########################################################\n");
	printf("#  TCP PORT %d\n", port);
	printf("########################################################\n");

	/* PHASE 1: connect timing */
	printf("\n=== PHASE 1: connect ===\n");
	long long t0 = now_ms();
	int s = tcp_connect(arg_ip, port);
	if (s < 0) {
		printf("  port %d not open -- skipping remaining phases\n",
		    port);
		return;
	}
	printf("  connected in %lld ms\n", now_ms() - t0);
	close(s);

	/* PHASE 2: the decisive test */
	phase_consumption();

	/* PHASE 3: protocol frames (needs credentials) */
	if (arg_devid && arg_key[0])
		phase_frames();
	else
		printf("\n(phase 3 skipped: give -d and -k to send "
		       "protocol frames)\n");

	/* PHASE 4: idle lifecycle */
	printf("\n=== PHASE 4: idle lifecycle (%ds) ===\n", IDLE_HOLD_SEC);
	s = tcp_connect(arg_ip, port);
	if (s >= 0) {
		int got = drain_and_report(s, IDLE_HOLD_SEC);
		if (got == 0)
			printf("    connection stayed open, silent\n");
		close(s);
	}
}

static int
parse_ports(const char *spec)
{
	arg_nports = 0;
	char tmp[128];
	strncpy(tmp, spec, sizeof(tmp) - 1);
	tmp[sizeof(tmp) - 1] = '\0';
	for (char *tok = strtok(tmp, ","); tok && arg_nports < MAX_TCP_PORTS;
	     tok = strtok(NULL, ",")) {
		int p = atoi(tok);
		if (p > 0 && p < 65536)
			arg_ports[arg_nports++] = p;
	}
	return arg_nports;
}

int
main(int argc, char **argv)
{
	int opt;
	while ((opt = getopt(argc, argv, "i:p:P:d:k:t:h")) != -1) {
		switch (opt) {
		case 'i': arg_ip = optarg; break;
		case 'p':
			arg_ports[0] = atoi(optarg);
			arg_nports = 1;
			break;
		case 'P':
			if (parse_ports(optarg) == 0) {
				fprintf(stderr, "no valid ports in -P\n");
				return 1;
			}
			break;
		case 'd': arg_devid = optarg; break;
		case 'k':
			if (read_keyfile(optarg) <= 0)
				return 1;
			break;
		case 't': arg_wait = atoi(optarg); break;
		default:
			usage(argv[0]);
			return (opt == 'h') ? 0 : 1;
		}
	}
	if (!arg_ip) {
		usage(argv[0]);
		return 1;
	}

	printf("tuyaprobe: %s  ports:", arg_ip);
	for (int i = 0; i < arg_nports; i++)
		printf(" %d", arg_ports[i]);
	printf("\n");
	printf("note: phase 3 session-negotiation sub-probes always use "
	       "6668\n(the tuyapp library's fixed command port); phases "
	       "1/2/4 and the\nphase-3 raw frames honor each swept port.\n");

	for (int i = 0; i < arg_nports; i++)
		probe_one_port(arg_ports[i]);

	printf("\ndone.\n");
	return 0;
}
