#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include <seatuya.h>

static int failures = 0;

static void
check(const char *name, int condition)
{
	if (condition) {
		printf("  PASS: %s\n", name);
	} else {
		printf("  FAIL: %s\n", name);
		failures++;
	}
}

static void
test_version(void)
{
	const char *ver = seatuya_version();
	check("version is non-null", ver != NULL);
	check("version is non-empty", ver && strlen(ver) > 0);
}

static void
test_create_destroy(void)
{
	seatuya_device_t *dev;

	dev = seatuya_create("3.3");
	check("create v3.3 succeeds", dev != NULL);
	if (dev) {
		check("protocol is v3.3",
		      seatuya_get_protocol(dev) == SEATUYA_PROTO_V33);
		seatuya_destroy(dev);
	}

	dev = seatuya_create("3.4");
	check("create v3.4 succeeds", dev != NULL);
	if (dev) {
		check("protocol is v3.4",
		      seatuya_get_protocol(dev) == SEATUYA_PROTO_V34);
		seatuya_destroy(dev);
	}

	dev = seatuya_create("3.5");
	check("create v3.5 succeeds", dev != NULL);
	if (dev) {
		check("protocol is v3.5",
		      seatuya_get_protocol(dev) == SEATUYA_PROTO_V35);
		seatuya_destroy(dev);
	}

	dev = seatuya_create("9.9");
	check("create invalid version returns NULL", dev == NULL);

	dev = seatuya_create(NULL);
	check("create NULL version returns NULL", dev == NULL);
}

static void
test_initial_state(void)
{
	seatuya_device_t *dev = seatuya_create("3.3");
	if (!dev) {
		printf("  SKIP: could not create device\n");
		return;
	}

	check("initial session state is INVALID",
	      seatuya_get_session_state(dev) == SEATUYA_SESSION_INVALID);
	check("initial socket state is DISCONNECTED",
	      seatuya_get_socket_state(dev) == SEATUYA_SOCK_DISCONNECTED);
	check("not connected initially",
	      !seatuya_is_connected(dev));

	seatuya_destroy(dev);
}

static void
test_null_safety(void)
{
	/* None of these should crash */
	seatuya_destroy(NULL);
	seatuya_disconnect(NULL);
	check("is_connected(NULL) returns false",
	      !seatuya_is_connected(NULL));
	check("connect(NULL) returns false",
	      !seatuya_connect(NULL, "localhost"));
	check("get_last_error(NULL) returns -1",
	      seatuya_get_last_error(NULL) == -1);
	check("build_message(NULL) returns -1",
	      seatuya_build_message(NULL, NULL, SEATUYA_CMD_DP_QUERY,
	                            "{}", "key") == -1);
	check("decode_message(NULL) returns NULL",
	      seatuya_decode_message(NULL, NULL, 0, "key") == NULL);
	check("generate_payload(NULL) returns NULL",
	      seatuya_generate_payload(NULL, SEATUYA_CMD_DP_QUERY,
	                               "id", "{}") == NULL);
	seatuya_free_string(NULL);
	check("null safety: no crashes", 1);
}

int
main(void)
{
	printf("seatuya test suite\n");
	printf("==================\n\n");

	printf("version:\n");
	test_version();

	printf("\ncreate/destroy:\n");
	test_create_destroy();

	printf("\ninitial state:\n");
	test_initial_state();

	printf("\nnull safety:\n");
	test_null_safety();

	printf("\n------------------\n");
	if (failures == 0)
		printf("All tests passed.\n");
	else
		printf("%d test(s) FAILED.\n", failures);

	return failures ? 1 : 0;
}
