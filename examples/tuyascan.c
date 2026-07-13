/*
 * tuyascan -- minimal Tuya device discovery scanner.
 *
 * Listens for Tuya device UDP broadcasts and prints device id, IP,
 * protocol version and product key.  Ports:
 *
 *   6666  protocol 3.1        plaintext JSON
 *   6667  protocol 3.3 / 3.4  AES-128-ECB, static key
 *   7000  protocol 3.5        AES-GCM (presence reported, not decoded)
 *
 * The 6667 key is the MD5 of a string published in every Tuya SDK;
 * the digest is embedded below so no crypto library is required.
 *
 * Built as a native Win32 binary because WSL2's NAT does not pass
 * LAN broadcast traffic through to the guest.  Cross-compile from
 * WSL2/Linux:
 *
 *   x86_64-w64-mingw32-gcc -O2 -o tuyascan.exe tuyascan.c -lws2_32
 *
 * Native Linux/BSD build (for hosts that do see the LAN):
 *
 *   cc -O2 -o tuyascan tuyascan.c
 *
 * Usage:  tuyascan [-t seconds]     (default 20)
 *
 * Windows Firewall will prompt on first run; inbound UDP on the
 * three ports must be allowed or nothing will be received.
 */

#ifdef _WIN32
#include <winsock2.h>
#include <ws2tcpip.h>
typedef SOCKET sock_t;
typedef int socklen_arg_t;
#else
#include <sys/socket.h>
#include <sys/select.h>
#include <sys/time.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
typedef int sock_t;
typedef socklen_t socklen_arg_t;
static const sock_t INVALID_SOCKET = -1;
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

enum {
	PORT_31        = 6666,   /* plaintext broadcasts            */
	PORT_33        = 6667,   /* AES-ECB broadcasts              */
	PORT_35        = 7000,   /* AES-GCM broadcasts (v3.5)       */
	NPORTS         = 3,
	MAX_PACKET     = 2048,
	MAX_DEVICES    = 64,
	HEADER_SIZE    = 16,     /* prefix + seq + cmd + len        */
	RETCODE_SIZE   = 4,
	TRAILER_SIZE   = 8,      /* crc + suffix                    */
	AES_BLOCK      = 16,
	AES_ROUNDS     = 10,
	DEFAULT_WAIT   = 20
};

static const unsigned long FRAME_PREFIX = 0x000055AAUL;
static const unsigned long FRAME_SUFFIX = 0x0000AA55UL;

/* MD5("yGAdlopoPVldABfn") -- the static Tuya UDP broadcast key */
static const unsigned char UDPKEY[AES_BLOCK] = {
	0x6c, 0x1e, 0xc8, 0xe2, 0xbb, 0x9b, 0xb5, 0x9a,
	0xb5, 0x0b, 0x0d, 0xaf, 0x64, 0x9b, 0x41, 0x0a
};

/* ------------------------------------------------------------------ */
/*  AES-128-ECB decryption (FIPS-197 inverse cipher)                  */
/* ------------------------------------------------------------------ */

static const unsigned char sbox[256] = {
	0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
	0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,
	0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,
	0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,
	0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,
	0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,
	0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,
	0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,
	0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,
	0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,
	0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,
	0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,
	0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,
	0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,
	0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,
	0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16
};

static const unsigned char rsbox[256] = {
	0x52,0x09,0x6a,0xd5,0x30,0x36,0xa5,0x38,0xbf,0x40,0xa3,0x9e,0x81,0xf3,0xd7,0xfb,
	0x7c,0xe3,0x39,0x82,0x9b,0x2f,0xff,0x87,0x34,0x8e,0x43,0x44,0xc4,0xde,0xe9,0xcb,
	0x54,0x7b,0x94,0x32,0xa6,0xc2,0x23,0x3d,0xee,0x4c,0x95,0x0b,0x42,0xfa,0xc3,0x4e,
	0x08,0x2e,0xa1,0x66,0x28,0xd9,0x24,0xb2,0x76,0x5b,0xa2,0x49,0x6d,0x8b,0xd1,0x25,
	0x72,0xf8,0xf6,0x64,0x86,0x68,0x98,0x16,0xd4,0xa4,0x5c,0xcc,0x5d,0x65,0xb6,0x92,
	0x6c,0x70,0x48,0x50,0xfd,0xed,0xb9,0xda,0x5e,0x15,0x46,0x57,0xa7,0x8d,0x9d,0x84,
	0x90,0xd8,0xab,0x00,0x8c,0xbc,0xd3,0x0a,0xf7,0xe4,0x58,0x05,0xb8,0xb3,0x45,0x06,
	0xd0,0x2c,0x1e,0x8f,0xca,0x3f,0x0f,0x02,0xc1,0xaf,0xbd,0x03,0x01,0x13,0x8a,0x6b,
	0x3a,0x91,0x11,0x41,0x4f,0x67,0xdc,0xea,0x97,0xf2,0xcf,0xce,0xf0,0xb4,0xe6,0x73,
	0x96,0xac,0x74,0x22,0xe7,0xad,0x35,0x85,0xe2,0xf9,0x37,0xe8,0x1c,0x75,0xdf,0x6e,
	0x47,0xf1,0x1a,0x71,0x1d,0x29,0xc5,0x89,0x6f,0xb7,0x62,0x0e,0xaa,0x18,0xbe,0x1b,
	0xfc,0x56,0x3e,0x4b,0xc6,0xd2,0x79,0x20,0x9a,0xdb,0xc0,0xfe,0x78,0xcd,0x5a,0xf4,
	0x1f,0xdd,0xa8,0x33,0x88,0x07,0xc7,0x31,0xb1,0x12,0x10,0x59,0x27,0x80,0xec,0x5f,
	0x60,0x51,0x7f,0xa9,0x19,0xb5,0x4a,0x0d,0x2d,0xe5,0x7a,0x9f,0x93,0xc9,0x9c,0xef,
	0xa0,0xe0,0x3b,0x4d,0xae,0x2a,0xf5,0xb0,0xc8,0xeb,0xbb,0x3c,0x83,0x53,0x99,0x61,
	0x17,0x2b,0x04,0x7e,0xba,0x77,0xd6,0x26,0xe1,0x69,0x14,0x63,0x55,0x21,0x0c,0x7d
};

static const unsigned char rcon[11] = {
	0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36
};

static unsigned char
gmul(unsigned char a, unsigned char b)
{
	unsigned char p = 0;
	for (int i = 0; i < 8; i++) {
		if (b & 1)
			p ^= a;
		unsigned char hi = a & 0x80;
		a <<= 1;
		if (hi)
			a ^= 0x1b;
		b >>= 1;
	}
	return p;
}

static void
key_expand(const unsigned char key[AES_BLOCK],
           unsigned char rk[(AES_ROUNDS + 1) * AES_BLOCK])
{
	memcpy(rk, key, AES_BLOCK);
	for (int i = 4; i < 4 * (AES_ROUNDS + 1); i++) {
		unsigned char t[4];
		memcpy(t, &rk[(i - 1) * 4], 4);
		if (i % 4 == 0) {
			unsigned char tmp = t[0];
			t[0] = (unsigned char)(sbox[t[1]] ^ rcon[i / 4]);
			t[1] = sbox[t[2]];
			t[2] = sbox[t[3]];
			t[3] = sbox[tmp];
		}
		for (int j = 0; j < 4; j++)
			rk[i * 4 + j] = (unsigned char)(rk[(i - 4) * 4 + j] ^ t[j]);
	}
}

static void
inv_block(unsigned char s[AES_BLOCK],
          const unsigned char rk[(AES_ROUNDS + 1) * AES_BLOCK])
{
	/* AddRoundKey (final round key) */
	for (int i = 0; i < AES_BLOCK; i++)
		s[i] ^= rk[AES_ROUNDS * AES_BLOCK + i];

	for (int round = AES_ROUNDS - 1; round >= 0; round--) {
		/* InvShiftRows: row r rotates right by r (column-major state) */
		unsigned char t[AES_BLOCK];
		for (int c = 0; c < 4; c++)
			for (int r = 0; r < 4; r++)
				t[((c + r) % 4) * 4 + r] = s[c * 4 + r];
		/* InvSubBytes */
		for (int i = 0; i < AES_BLOCK; i++)
			s[i] = rsbox[t[i]];
		/* AddRoundKey */
		for (int i = 0; i < AES_BLOCK; i++)
			s[i] ^= rk[round * AES_BLOCK + i];
		/* InvMixColumns (skipped after the last iteration) */
		if (round > 0) {
			for (int c = 0; c < 4; c++) {
				unsigned char a0 = s[c*4+0], a1 = s[c*4+1];
				unsigned char a2 = s[c*4+2], a3 = s[c*4+3];
				s[c*4+0] = (unsigned char)(gmul(a0,14)^gmul(a1,11)^gmul(a2,13)^gmul(a3,9));
				s[c*4+1] = (unsigned char)(gmul(a0,9)^gmul(a1,14)^gmul(a2,11)^gmul(a3,13));
				s[c*4+2] = (unsigned char)(gmul(a0,13)^gmul(a1,9)^gmul(a2,14)^gmul(a3,11));
				s[c*4+3] = (unsigned char)(gmul(a0,11)^gmul(a1,13)^gmul(a2,9)^gmul(a3,14));
			}
		}
	}
}

/*
 * Decrypt buf in place, strip PKCS#7 padding.
 * Returns plaintext length, or -1 on bad input.
 */
static int
aes128_ecb_decrypt(unsigned char *buf, int len, const unsigned char key[AES_BLOCK])
{
	if (len <= 0 || len % AES_BLOCK != 0)
		return -1;

	unsigned char rk[(AES_ROUNDS + 1) * AES_BLOCK];
	key_expand(key, rk);

	for (int off = 0; off < len; off += AES_BLOCK)
		inv_block(&buf[off], rk);

	int pad = buf[len - 1];
	if (pad < 1 || pad > AES_BLOCK || pad > len)
		return -1;
	for (int i = len - pad; i < len; i++)
		if (buf[i] != pad)
			return -1;
	return len - pad;
}

/* ------------------------------------------------------------------ */
/*  Minimal JSON string extraction ("key":"value")                    */
/* ------------------------------------------------------------------ */

static int
json_get_string(const char *json, const char *key, char *out, int outsize)
{
	char pattern[64];
	snprintf(pattern, sizeof(pattern), "\"%s\"", key);
	const char *p = strstr(json, pattern);
	if (!p)
		return 0;
	p = strchr(p + strlen(pattern), ':');
	if (!p)
		return 0;
	p++;
	while (*p == ' ' || *p == '\t')
		p++;
	if (*p != '"')
		return 0;
	p++;
	int i = 0;
	while (*p && *p != '"' && i < outsize - 1)
		out[i++] = *p++;
	out[i] = '\0';
	return i > 0;
}

/* ------------------------------------------------------------------ */
/*  Frame handling                                                    */
/* ------------------------------------------------------------------ */

static unsigned long
be32(const unsigned char *p)
{
	return ((unsigned long)p[0] << 24) | ((unsigned long)p[1] << 16) |
	       ((unsigned long)p[2] << 8)  |  (unsigned long)p[3];
}

struct seen {
	char id[64];
};

static struct seen seen_devices[MAX_DEVICES];
static int seen_count = 0;

static int
already_seen(const char *id)
{
	for (int i = 0; i < seen_count; i++)
		if (strcmp(seen_devices[i].id, id) == 0)
			return 1;
	if (seen_count < MAX_DEVICES) {
		strncpy(seen_devices[seen_count].id, id,
		    sizeof(seen_devices[0].id) - 1);
		seen_count++;
	}
	return 0;
}

/*
 * Handle one received datagram.  Returns 1 if a new device was
 * printed, 0 otherwise.
 */
static int
handle_packet(int port, unsigned char *buf, int n, const char *sender_ip)
{
	if (port == PORT_35) {
		/* 6699/GCM frame: report presence, id not recoverable here */
		char label[80];
		snprintf(label, sizeof(label), "35:%s", sender_ip);
		if (already_seen(label))
			return 0;
		printf("  %-24s %-15s  v3.5 (GCM broadcast; use protocol 3.5)\n",
		    "(id not decoded)", sender_ip);
		return 1;
	}

	if (n < HEADER_SIZE + RETCODE_SIZE + TRAILER_SIZE)
		return 0;
	if (be32(buf) != FRAME_PREFIX || be32(&buf[n - 4]) != FRAME_SUFFIX)
		return 0;

	unsigned char *payload = &buf[HEADER_SIZE + RETCODE_SIZE];
	int plen = n - HEADER_SIZE - RETCODE_SIZE - TRAILER_SIZE;
	if (plen <= 0)
		return 0;

	if (port == PORT_33) {
		plen = aes128_ecb_decrypt(payload, plen, UDPKEY);
		if (plen < 0) {
			fprintf(stderr, "  [6667] %s: decrypt failed\n", sender_ip);
			return 0;
		}
	}
	payload[plen] = '\0';

	char gw_id[64] = {0}, ip[64] = {0}, ver[16] = {0}, pk[64] = {0};
	if (!json_get_string((char *)payload, "gwId", gw_id, sizeof(gw_id)))
		return 0;
	if (already_seen(gw_id))
		return 0;
	if (!json_get_string((char *)payload, "ip", ip, sizeof(ip)))
		snprintf(ip, sizeof(ip), "%s", sender_ip);
	json_get_string((char *)payload, "version", ver, sizeof(ver));
	json_get_string((char *)payload, "productKey", pk, sizeof(pk));

	printf("  %-24s %-15s  v%-4s  productKey=%s\n",
	    gw_id, ip, ver[0] ? ver : "?", pk[0] ? pk : "?");
	return 1;
}

/* ------------------------------------------------------------------ */
/*  Main                                                              */
/* ------------------------------------------------------------------ */

static void
sock_close(sock_t s)
{
#ifdef _WIN32
	closesocket(s);
#else
	close(s);
#endif
}

static sock_t
open_listener(int port)
{
	sock_t s = socket(AF_INET, SOCK_DGRAM, 0);
	if (s == INVALID_SOCKET)
		return s;

	int reuse = 1;
	setsockopt(s, SOL_SOCKET, SO_REUSEADDR,
	    (const char *)&reuse, sizeof(reuse));

	struct sockaddr_in addr;
	memset(&addr, 0, sizeof(addr));
	addr.sin_family = AF_INET;
	addr.sin_port = htons((unsigned short)port);
	addr.sin_addr.s_addr = htonl(INADDR_ANY);

	if (bind(s, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
		fprintf(stderr, "bind udp/%d failed", port);
#ifdef _WIN32
		fprintf(stderr, " (WSA error %d)", WSAGetLastError());
#endif
		fprintf(stderr, "\n");
		sock_close(s);
		return INVALID_SOCKET;
	}
	return s;
}

#ifndef TUYASCAN_NO_MAIN
int
main(int argc, char **argv)
{
	int wait_secs = DEFAULT_WAIT;

	for (int i = 1; i < argc; i++) {
		if (strcmp(argv[i], "-t") == 0 && i + 1 < argc)
			wait_secs = atoi(argv[++i]);
		else {
			fprintf(stderr, "usage: %s [-t seconds]\n", argv[0]);
			return 1;
		}
	}
	if (wait_secs < 1)
		wait_secs = DEFAULT_WAIT;

#ifdef _WIN32
	WSADATA wsa;
	if (WSAStartup(MAKEWORD(2, 2), &wsa) != 0) {
		fprintf(stderr, "WSAStartup failed\n");
		return 1;
	}
#endif

	static const int ports[NPORTS] = { PORT_31, PORT_33, PORT_35 };
	sock_t socks[NPORTS];
	sock_t maxfd = 0;
	int nopen = 0;

	for (int i = 0; i < NPORTS; i++) {
		socks[i] = open_listener(ports[i]);
		if (socks[i] != INVALID_SOCKET) {
			nopen++;
			if (socks[i] > maxfd)
				maxfd = socks[i];
		}
	}
	if (nopen == 0) {
		fprintf(stderr, "no ports could be opened\n");
		return 1;
	}

	printf("Listening on udp 6666/6667/7000 for %d seconds...\n",
	    wait_secs);
	printf("(devices broadcast roughly every 5 seconds)\n\n");

	time_t deadline = time(NULL) + wait_secs;
	int found = 0;

	while (time(NULL) < deadline) {
		fd_set fds;
		FD_ZERO(&fds);
		for (int i = 0; i < NPORTS; i++)
			if (socks[i] != INVALID_SOCKET)
				FD_SET(socks[i], &fds);

		struct timeval tv;
		tv.tv_sec = 1;
		tv.tv_usec = 0;

		int r = select((int)(maxfd + 1), &fds, NULL, NULL, &tv);
		if (r <= 0)
			continue;

		for (int i = 0; i < NPORTS; i++) {
			if (socks[i] == INVALID_SOCKET ||
			    !FD_ISSET(socks[i], &fds))
				continue;

			unsigned char buf[MAX_PACKET];
			struct sockaddr_in sender;
			socklen_arg_t slen = sizeof(sender);
			int n = recvfrom(socks[i], (char *)buf,
			    sizeof(buf) - 1, 0,
			    (struct sockaddr *)&sender, &slen);
			if (n <= 0)
				continue;

			char sender_ip[16];
			strncpy(sender_ip, inet_ntoa(sender.sin_addr),
			    sizeof(sender_ip) - 1);
			sender_ip[sizeof(sender_ip) - 1] = '\0';

			found += handle_packet(ports[i], buf, n, sender_ip);
		}
	}

	for (int i = 0; i < NPORTS; i++)
		if (socks[i] != INVALID_SOCKET)
			sock_close(socks[i]);
#ifdef _WIN32
	WSACleanup();
#endif

	printf("\n%d device(s) found.\n", found);
	if (found == 0)
		printf("If the device is known to be online, LAN broadcast "
		       "may be disabled\nin firmware, or a firewall is "
		       "blocking inbound UDP.\n");
	return 0;
}
#endif /* TUYASCAN_NO_MAIN */
