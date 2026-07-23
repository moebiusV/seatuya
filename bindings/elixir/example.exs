# Example: create a Tuya device, turn DP 1 on, print status, turn off.
#
# Run:
#   elixir example.exs
#
# Environment variables: DEVICE_ID, DEVICE_IP, LOCAL_KEY, VERSION

Mix.install([], force: true)

defmodule Example do
  def run do
    dev_id  = System.get_env("DEVICE_ID",  "0123456789abcdef0123")
    addr    = System.get_env("DEVICE_IP",  "192.168.1.100")
    key     = System.get_env("LOCAL_KEY",  "0123456789abcdef")
    ver     = System.get_env("VERSION",    "3.3")

    IO.puts("seatuya version: #{Seatuya.version()}")

    case Seatuya.create(dev_id, addr, key, ver) do
      {:ok, dev} ->
        IO.puts("Device created")

        # Turn on DP 1
        case Seatuya.turn_on(dev, 1) do
          {:ok, resp} ->
            IO.puts("Turn ON response: #{resp}")
          {:error, reason} ->
            IO.puts("Turn ON failed: #{inspect(reason)}")
        end

        # Query status
        case Seatuya.status(dev) do
          {:ok, status} ->
            IO.puts("Device status: #{status}")
          {:error, reason} ->
            IO.puts("Status query failed: #{inspect(reason)}")
        end

        # Turn off DP 1
        case Seatuya.turn_off(dev, 1) do
          {:ok, resp} ->
            IO.puts("Turn OFF response: #{resp}")
          {:error, reason} ->
            IO.puts("Turn OFF failed: #{inspect(reason)}")
        end

        Seatuya.destroy(dev)
        IO.puts("Device destroyed")

      {:error, reason} ->
        IO.puts("Create failed: #{inspect(reason)}")
    end
  end
end

Example.run()
