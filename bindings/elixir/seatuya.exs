defmodule Seatuya do
  @moduledoc """
  Elixir bindings for libseatuya (Tuya local device control).

  This module wraps the compiled Erlang NIF module `:seatuya` with an
  idiomatic Elixir API.  The `:seatuya` Erlang module must be compiled
  and available on the code path, or you can set `SEATUYA_LIB` to the
  path of the NIF shared library (`.so` / `.dylib`).

  Build the NIF shared library:
      cc -fPIC -shared -I$ERLANG_ROOT/usr/include \\
          -o seatuya_nif.so seatuya_nif.c -lseatuya

  The NIF is then loaded by the Erlang `:seatuya` module.
  """

  # ------------------------------------------------------------------
  # Lifecycle
  # ------------------------------------------------------------------

  @doc """
  Create a device, connect, and negotiate session.
  Returns `{:ok, ref}` or `{:error, reason}`.
  """
  def create(device_id, address, local_key, version \\ "3.3") do
    :seatuya.create(device_id, address, local_key, version)
  end

  @doc "Allocate a device handle without connecting."
  def alloc(version) do
    :seatuya.alloc(version)
  end

  @doc "Destroy a device handle and free all resources."
  def destroy(dev) do
    :seatuya.destroy(dev)
  end

  # ------------------------------------------------------------------
  # Credentials
  # ------------------------------------------------------------------

  defdelegate set_credentials(dev, device_id, local_key), to: :seatuya
  defdelegate get_device_id(dev), to: :seatuya
  defdelegate get_local_key(dev), to: :seatuya
  defdelegate get_ip(dev), to: :seatuya

  # ------------------------------------------------------------------
  # Connection
  # ------------------------------------------------------------------

  defdelegate connect(dev, hostname), to: :seatuya
  defdelegate disconnect(dev), to: :seatuya
  defdelegate is_connected(dev), to: :seatuya
  defdelegate reconnect(dev), to: :seatuya

  # ------------------------------------------------------------------
  # Retry settings
  # ------------------------------------------------------------------

  defdelegate set_retry_limit(dev, limit), to: :seatuya
  defdelegate set_retry_delay(dev, delay_ms), to: :seatuya
  defdelegate get_retry_limit(dev), to: :seatuya
  defdelegate get_retry_delay(dev), to: :seatuya

  # ------------------------------------------------------------------
  # State queries
  # ------------------------------------------------------------------

  defdelegate get_protocol(dev), to: :seatuya
  defdelegate get_session_state(dev), to: :seatuya
  defdelegate get_socket_state(dev), to: :seatuya
  defdelegate get_last_error(dev), to: :seatuya

  # ------------------------------------------------------------------
  # Async mode
  # ------------------------------------------------------------------

  defdelegate set_async_mode(dev, async), to: :seatuya
  defdelegate is_socket_readable(dev), to: :seatuya
  defdelegate is_socket_writable(dev), to: :seatuya
  defdelegate set_session_ready(dev), to: :seatuya

  # ------------------------------------------------------------------
  # Message building / decoding
  # ------------------------------------------------------------------

  defdelegate build_message(dev, buf, cmd, payload, key), to: :seatuya
  defdelegate decode_message(dev, buf, key), to: :seatuya
  defdelegate generate_payload(dev, cmd, device_id, datapoints), to: :seatuya
  defdelegate send(dev, buf, size), to: :seatuya
  defdelegate receive(dev, maxsize, minsize), to: :seatuya

  # ------------------------------------------------------------------
  # device22 mode
  # ------------------------------------------------------------------

  defdelegate set_device22(dev, null_dps_json), to: :seatuya
  defdelegate is_device22(dev), to: :seatuya

  # ------------------------------------------------------------------
  # High-level round-trip operations
  # ------------------------------------------------------------------

  defdelegate set_value_bool(dev, dp, value), to: :seatuya
  defdelegate set_value_int(dev, dp, value), to: :seatuya
  defdelegate set_value_string(dev, dp, value), to: :seatuya
  defdelegate set_value_float(dev, dp, value), to: :seatuya
  defdelegate turn_on(dev, switch_dp), to: :seatuya
  defdelegate turn_off(dev, switch_dp), to: :seatuya
  defdelegate status(dev), to: :seatuya
  defdelegate heartbeat(dev), to: :seatuya

  # ------------------------------------------------------------------
  # Memory management
  # ------------------------------------------------------------------

  defdelegate free_string(str), to: :seatuya

  # ------------------------------------------------------------------
  # Version
  # ------------------------------------------------------------------

  defdelegate version(), to: :seatuya

  # ------------------------------------------------------------------
  # Type-aware set_value dispatcher
  # ------------------------------------------------------------------

  @doc """
  Set a DP value, dispatching by Elixir type to the correct C setter.

  ## Examples

      Seatuya.set_value(dev, 1, true)        # calls set_value_bool
      Seatuya.set_value(dev, 2, 42)          # calls set_value_int
      Seatuya.set_value(dev, 3, "hello")     # calls set_value_string
      Seatuya.set_value(dev, 4, 3.14)        # calls set_value_float
  """
  def set_value(dev, dp, value) when is_boolean(value) do
    set_value_bool(dev, dp, value)
  end

  def set_value(dev, dp, value) when is_integer(value) do
    set_value_int(dev, dp, value)
  end

  def set_value(dev, dp, value) when is_float(value) do
    set_value_float(dev, dp, value)
  end

  def set_value(dev, dp, value) when is_binary(value) do
    set_value_string(dev, dp, value)
  end

  # ------------------------------------------------------------------
  # Constants
  # ------------------------------------------------------------------

  # Command types
  @cmd_udp                  0
  @cmd_ap_config            1
  @cmd_active               2
  @cmd_bind                 3
  @cmd_rename_gw            4
  @cmd_rename_device        5
  @cmd_unbind               6
  @cmd_control              7
  @cmd_status               8
  @cmd_heart_beat           9
  @cmd_dp_query            10
  @cmd_query_wifi          11
  @cmd_token_bind          12
  @cmd_control_new         13
  @cmd_enable_wifi         14
  @cmd_dp_query_new        16
  @cmd_scene_execute       17
  @cmd_updatedps           18
  @cmd_udp_new             19
  @cmd_ap_config_new       20
  @cmd_get_local_time      28
  @cmd_weather_open        32
  @cmd_weather_data        33
  @cmd_state_upload_syn    34
  @cmd_state_upload_syn_recv 35
  @cmd_heart_beat_stop     37
  @cmd_stream_trans        38
  @cmd_get_wifi_status     43
  @cmd_wifi_connect_test   44
  @cmd_get_mac             45
  @cmd_get_ir_status       46
  @cmd_ir_tx_rx_test       47
  @cmd_lan_gw_active       240
  @cmd_lan_sub_dev_request 241
  @cmd_lan_delete_sub_dev  242
  @cmd_lan_report_sub_dev  243
  @cmd_lan_scene           244
  @cmd_lan_publish_cloud_config 245
  @cmd_lan_publish_app_config   246
  @cmd_lan_export_app_config    247
  @cmd_lan_publish_scene_panel  248
  @cmd_lan_remove_gw       249
  @cmd_lan_check_gw_update 250
  @cmd_lan_gw_update       251
  @cmd_lan_set_gw_channel  252

  # Protocol versions
  @proto_v31 0
  @proto_v33 1
  @proto_v34 2
  @proto_v35 3

  # Session states
  @session_invalid      0
  @session_starting     1
  @session_finalizing   2
  @session_established  3

  # Socket states
  @sock_no_such_host    0
  @sock_no_sock_avail   1
  @sock_failed          2
  @sock_disconnected    3
  @sock_connecting      4
  @sock_connected       5
  @sock_ready           6
  @sock_receiving       7

  # General
  @default_port         6668
  @bufsize              1024
  @default_retry_limit  5
  @default_retry_delay_ms 100
end
