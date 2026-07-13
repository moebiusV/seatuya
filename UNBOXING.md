# ISV-300W Unboxing to Local Control

You have an Inkbird ISV-300W sous vide cooker. You want to control it
from your laptop over the local network with no cloud dependency.
This guide takes you from sealed box to running `sousctl ramp 25C 50C
30:00 hold 50C 30:00` — ramp, hold, auto-off, all local.

The ISV-300W speaks Tuya protocol 3.5 (0x00006699 frames with AES-GCM,
not the more common 3.3).  This matters because every other Tuya tool
defaults to 3.3 and gets silence.  seatuya was patched to handle 3.5
after discovering this the hard way.

## 1. Plug it in and get it on WiFi

The Inkbird needs a smartphone app for initial WiFi provisioning —
there is no way around this.  The app is a one-time cost; you can
delete it afterward.

1. Install **Smart Life** (or Tuya Smart) on your phone.
2. Plug in the Inkbird.
3. Open Smart Life, tap **+** to add a device.  It finds the Inkbird
   via Bluetooth, sends your WiFi credentials, and the device switches
   to WiFi.
4. Confirm the device appears in the app and reports temperature.

## 2. Get Tuya IoT credentials

The device's local encryption key is stored in Tuya's cloud.  You
fetch it once with a free developer account.

1. Go to [iot.tuya.com](https://iot.tuya.com) and sign up.  Use the
   **same email and password** as the Smart Life app so your device
   is already linked.
2. Click **Cloud** → **Create Cloud Project**.
   - Name it whatever you want.
   - Industry: **Smart Home**.
   - Development method: **Smart Home PaaS**.
   - Data center: pick the one matching your region (US → Western
     America, Canada → same, Europe → Central Europe, etc.).
   - If you pick the wrong data center the wizard fails with an auth
     error — just create another project.
3. On the project overview page, go to **Authorization** in the left
   sidebar.  You see:
   - **Access ID** — this is your API key
   - **Access Secret** — this is your API secret (only shown once;
     save it now)
4. Go to **Devices** → **Link Tuya App Account**.  It shows a QR code.
5. Open Smart Life → **Me** tab → scan icon (top right) → scan the QR
   code → accept.  Your Inkbird now appears under the **Devices** tab
   in the IoT console.
6. Go to **Cloud** → **API Services** (or "Cloud Services").  Subscribe
   to these (free under the trial tier):
   - **IoT Core**
   - **Authorization Token Management**
   - **Smart Home Basic Service**
7. Save your credentials somewhere safe:
   ```
   AccessID:     <your-access-id>
   AccessSecret: <your-access-secret>
   Region:       us
   ```

## 3. Build seatuya

```
git clone git@github.com:moebiusV/seatuya.git
cd seatuya
./fetch-deps.sh
autoreconf -fi
./configure
make -j4
```

Requirements: gcc, make, autoconf, automake, libtool, OpenSSL dev
headers (`libssl-dev`).  The build produces `sousctl`, `seatuya-wizard`,
`tuyaprobe`, and `tuyascan` in `examples/.libs/`.

You can now run `sousctl` directly — an rpath is baked into the binary
so `LD_LIBRARY_PATH` is not needed.

## 4. Get the local key and device IP

Run the wizard to pull the local key from Tuya's cloud, then find the
device on your local network.

```
./examples/.libs/seatuya-wizard-openssl \
  -k YOUR_ACCESS_ID -s YOUR_ACCESS_SECRET -r us -y \
  -i eb1234567890abcdef012345
```

- `-y` skips the interactive prompts.
- `-i` provides any device ID registered in your account (find it in
  the IoT console under Devices — the Inkbird's ID is a 22-character
  string like `eb1234567890abcdef012345`).
- The wizard writes `tinytuya.json` (cloud credentials) and
  `devices.json` (device list with local keys).

If the wizard fails with "permission deny" or "token invalid," check
that you subscribed to the API services in step 2.6 and that the
device ID is correct.

If the wizard succeeds but the UDP scan finds nothing, that is normal
on WSL2 — WSL2's NAT does not pass LAN broadcasts.  Find the device IP
by checking your router's DHCP client list at `192.168.1.254`, or from
the Smart Life app's device info screen, or by looking up the MAC
address in the Windows ARP table:

```
powershell.exe -c "arp -a" | grep -i "00-33-7a-78-47-28"
```

The MAC is listed in the IoT console device detail page and in
`devices.json` after a successful wizard run.

## 5. Write the config file

Create `~/.config/seatuya/config`:

```ini
[sousvide]
device_id = eb1234567890abcdef012345
local_key = a1B2c3D4e5F6g7H8
mac       = aa:bb:cc:dd:ee:ff
ip        = 192.168.1.100
version   = 3.5
```

- `version` must be **3.5**.  The ISV-300W speaks protocol 3.5, not
  3.3.  Every other tool defaults to 3.3 and gets complete silence.
- `mac` is optional but recommended — `resolve-mac.sh` uses it to
  update the IP when DHCP changes it.
- The `&` in the local key is a literal ampersand, not an HTML entity.
  If you copy-paste from the wizard's JSON output you may get the
  Unicode escape `&` instead.  The config file needs the actual
  `&` character (16 bytes total).  Verify with `xxd keyfile`.

## 6. Test the connection

```
$ sousctl status
ISV-300W status:
  {"dps":{"101":true,"102":"working","103":500,"104":500,...}}

  Power:          ON
  Status:         working
  Current:        50.0 C / 122.0 F
  Target:         50.0 C / 122.0 F
  Unit:           Celsius
```

If `sousctl status` works, local control is confirmed.  If it fails
with "error: connect failed" or hangs, verify:
- The device is powered on and connected to WiFi.
- The IP in the config matches the device's current IP.
- The local key is exactly 16 bytes (verify with `xxd keyfile`).
- The version is `3.5`.
- You can reach the device: `echo >/dev/tcp/192.168.1.131/6668`.

If everything checks out but `sousctl` still hangs, run `tuyaprobe`:

```
./examples/.libs/tuyaprobe -i 192.168.1.131 \
  -d eb1234567890abcdef012345 -k keyfile
```

Pay attention to Phase 2 (read-consumption test) and Phase 3
(protocol frames).  If Phase 2 says an application IS reading but all
Phase 3 frames get silence, the protocol version or key is wrong.  If
Phase 2 says writes stall, nothing reads port 6668 and local control
is disabled in firmware.

## 7. Daily use

`sousctl` commands chain SoX-style.  Power-off is implicit at the
end of every chain and on crash/interrupt.

```
# Read current state (no modification)
sousctl status
sousctl read

# Set target temperature
sousctl temp 55C

# Ramp 25→50°C over 30 minutes, hold 50°C for 30 minutes
sousctl ramp 25C 50C 30:00 hold 50C 30:00

# Same thing, with timestamps printed to stderr
sousctl -v ramp 25C 50C 30:00 hold 50C 30:00

# Dry run — print the schedule without connecting
sousctl -n ramp 20C 85C 60:00

# Power off
sousctl off

# Use a different device (beach house vs home)
sousctl -c ~/.config/seatuya/beach status
sousctl -i 192.168.1.200 status
```

**Temperature format:** `50C`, `122F`, or `37.5` (default Celsius).

**Time format:** `45` (minutes), `5:00` (M:SS), `1:30:00` (HH:MM:SS).

## Troubleshooting

| Symptom | Likely cause |
|---------|-------------|
| `sousctl status` hangs | Wrong protocol version (must be 3.5) |
| `sousctl status` says "connect failed" | Device is off, wrong IP, or not on WiFi |
| Wizard says "token invalid" | Wrong region or API services not subscribed |
| Wizard says "permission deny" | Device not linked to cloud project (step 2.4-2.5) |
| Local key doesn't work | Key contains `&` instead of `&` — use the literal character |
| Device not in ARP table | Device hasn't communicated with Windows host — ping the broadcast address or check the router |
| `tuyascan` finds nothing on Windows | Windows Firewall blocked the inbound UDP — allow it |
| DHCP changed the IP | Run `./resolve-mac.sh` to update the config from the ARP table |
