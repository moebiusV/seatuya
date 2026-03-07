#include <stdio.h>
#include <string.h>
#include "seatuya.h"

int
main(void)
{
	const char *ver = seatuya_version();
	if (ver == NULL || strlen(ver) == 0) {
		fprintf(stderr, "FAIL: seatuya_version returned empty\n");
		return 1;
	}
	printf("seatuya version: %s\n", ver);
	return 0;
}
