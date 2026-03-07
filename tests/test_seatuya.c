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
	const char *ver = tuya_version();
	check("version is non-null", ver != NULL);
	check("version is non-empty", ver && strlen(ver) > 0);
}

static void
test_create_destroy(void)
{
	tuya_device_t *dev;

	dev = tuya_alloc("3.3");
	check("alloc v3.3 succeeds", dev != NULL);
	if (dev) {
		check("protocol is v3.3",
		      tuya_get_protocol(dev) == TUYA_PROTO_V33);
		tuya_destroy(dev);
	}

	dev = tuya_alloc("3.4");
	check("alloc v3.4 succeeds", dev != NULL);
	if (dev) {
		check("protocol is v3.4",
		      tuya_get_protocol(dev) == TUYA_PROTO_V34);
		tuya_destroy(dev);
	}

	dev = tuya_alloc("3.5");
	check("alloc v3.5 succeeds", dev != NULL);
	if (dev) {
		check("protocol is v3.5",
		      tuya_get_protocol(dev) == TUYA_PROTO_V35);
		tuya_destroy(dev);
	}

	dev = tuya_alloc("9.9");
	check("alloc invalid version returns NULL", dev == NULL);

	dev = tuya_alloc(NULL);
	check("alloc NULL version returns NULL", dev == NULL);

	/* tuya_open with invalid version returns NULL */
	dev = tuya_create("id", "addr", "key", "9.9");
	check("create invalid version returns NULL", dev == NULL);

	/* tuya_open with unreachable host returns NULL */
	dev = tuya_create("id", "192.0.2.1", "key", "3.3");
	check("create unreachable host returns NULL", dev == NULL);
}

static void
test_initial_state(void)
{
	tuya_device_t *dev = tuya_alloc("3.3");
	if (!dev) {
		printf("  SKIP: could not create device\n");
		return;
	}

	check("initial session state is INVALID",
	      tuya_get_session_state(dev) == TUYA_SESSION_INVALID);
	check("initial socket state is DISCONNECTED",
	      tuya_get_socket_state(dev) == TUYA_SOCK_DISCONNECTED);
	check("not connected initially",
	      !tuya_is_connected(dev));

	tuya_destroy(dev);
}

static void
test_credentials(void)
{
	tuya_device_t *dev = tuya_alloc("3.3");
	if (!dev) {
		printf("  SKIP: could not create device\n");
		return;
	}

	/* No credentials initially */
	check("device_id initially NULL",
	      tuya_get_device_id(dev) == NULL);
	check("local_key initially NULL",
	      tuya_get_local_key(dev) == NULL);
	check("ip initially NULL",
	      tuya_get_ip(dev) == NULL);

	/* Set credentials */
	tuya_set_credentials(dev, "test_dev_id", "test_local_key");
	check("device_id set correctly",
	      strcmp(tuya_get_device_id(dev), "test_dev_id") == 0);
	check("local_key set correctly",
	      strcmp(tuya_get_local_key(dev), "test_local_key") == 0);

	/* Overwrite credentials */
	tuya_set_credentials(dev, "new_id", "new_key");
	check("device_id updated",
	      strcmp(tuya_get_device_id(dev), "new_id") == 0);
	check("local_key updated",
	      strcmp(tuya_get_local_key(dev), "new_key") == 0);

	tuya_destroy(dev);
}

static void
test_high_level_null_safety(void)
{
	/* High-level functions with no credentials should return NULL */
	tuya_device_t *dev = tuya_alloc("3.3");
	if (!dev) {
		printf("  SKIP: could not create device\n");
		return;
	}

	check("set_value_bool without credentials returns NULL",
	      tuya_set_value_bool(dev, 1, true) == NULL);
	check("set_value_int without credentials returns NULL",
	      tuya_set_value_int(dev, 1, 42) == NULL);
	check("set_value_string without credentials returns NULL",
	      tuya_set_value_string(dev, 1, "test") == NULL);
	check("set_value_float without credentials returns NULL",
	      tuya_set_value_float(dev, 1, 3.14) == NULL);
	check("turn_on without credentials returns NULL",
	      tuya_turn_on(dev, 1) == NULL);
	check("turn_off without credentials returns NULL",
	      tuya_turn_off(dev, 1) == NULL);
	check("status without credentials returns NULL",
	      tuya_status(dev) == NULL);
	check("heartbeat without credentials returns NULL",
	      tuya_heartbeat(dev) == NULL);
	check("reconnect without ip returns false",
	      !tuya_reconnect(dev));

	/* NULL dev */
	check("set_value_bool(NULL) returns NULL",
	      tuya_set_value_bool(NULL, 1, true) == NULL);
	check("status(NULL) returns NULL",
	      tuya_status(NULL) == NULL);
	check("reconnect(NULL) returns false",
	      !tuya_reconnect(NULL));

	/* Credential getters with NULL dev */
	check("get_device_id(NULL) returns NULL",
	      tuya_get_device_id(NULL) == NULL);
	check("get_local_key(NULL) returns NULL",
	      tuya_get_local_key(NULL) == NULL);
	check("get_ip(NULL) returns NULL",
	      tuya_get_ip(NULL) == NULL);

	tuya_destroy(dev);
}

static void
test_null_safety(void)
{
	/* None of these should crash */
	tuya_destroy(NULL);
	tuya_disconnect(NULL);
	tuya_set_credentials(NULL, "id", "key");
	check("is_connected(NULL) returns false",
	      !tuya_is_connected(NULL));
	check("connect(NULL) returns false",
	      !tuya_connect(NULL, "localhost"));
	check("get_last_error(NULL) returns -1",
	      tuya_get_last_error(NULL) == -1);
	check("build_message(NULL) returns -1",
	      tuya_build_message(NULL, NULL, TUYA_CMD_DP_QUERY,
	                            "{}", "key") == -1);
	check("decode_message(NULL) returns NULL",
	      tuya_decode_message(NULL, NULL, 0, "key") == NULL);
	check("generate_payload(NULL) returns NULL",
	      tuya_generate_payload(NULL, TUYA_CMD_DP_QUERY,
	                               "id", "{}") == NULL);
	tuya_free_string(NULL);
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

	printf("\ncredentials:\n");
	test_credentials();

	printf("\nhigh-level null safety:\n");
	test_high_level_null_safety();

	printf("\nnull safety:\n");
	test_null_safety();

	printf("\n------------------\n");
	if (failures == 0)
		printf("All tests passed.\n");
	else
		printf("%d test(s) FAILED.\n", failures);

	return failures ? 1 : 0;
}
