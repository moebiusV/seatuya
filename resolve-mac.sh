#!/bin/bash
# Resolve MAC address to IP via ARP table.
# Usage: resolve-mac.sh <config-file>
# Reads mac= from [sousvide] section, updates ip= in place.

config="${1:-$HOME/.config/seatuya/config}"
mac=$(grep -E '^mac\s*=' "$config" 2>/dev/null | sed 's/.*=\s*//' | tr -d ' ')

if [ -z "$mac" ]; then
    echo "No mac= in config, skipping MAC resolution" >&2
    exit 0
fi

# Convert MAC to various formats for lookup
mac_dash=$(echo "$mac" | tr ':' '-')
mac_nocolon=$(echo "$mac" | tr -d ':')

# Try Windows ARP first (we're in WSL)
ip=$(powershell.exe -Command "arp -a" 2>/dev/null | grep -i "$mac_dash" | awk '{print $1}' | head -1)

# Fallback: Linux ARP table
if [ -z "$ip" ]; then
    ip=$(grep -i "$mac_nocolon" /proc/net/arp 2>/dev/null | awk '{print $1}' | head -1)
fi

if [ -z "$ip" ]; then
    echo "MAC $mac not found in ARP table" >&2
    exit 1
fi

# Update config in place
old_ip=$(grep -E '^ip\s*=' "$config" 2>/dev/null | sed 's/.*=\s*//' | tr -d ' ')
if [ "$old_ip" != "$ip" ]; then
    sed -i "s/^ip\s*=.*/ip        = $ip/" "$config"
    echo "Updated IP: $old_ip -> $ip" >&2
fi
echo "$ip"
