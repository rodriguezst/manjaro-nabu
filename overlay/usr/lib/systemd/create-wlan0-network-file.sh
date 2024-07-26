#!/bin/bash
interface=wlan0
mac="$((cat /etc/machine-id; echo "$interface"; ) | sha256sum -)"
echo "[Match]" > /etc/systemd/network/10-$interface.network
echo "Name=$interface" >> /etc/systemd/network/10-$interface.network
echo "" >> /etc/systemd/network/10-$interface.network
echo "[Link]" >> /etc/systemd/network/10-$interface.network
echo "MACAddress=42:${mac:0:2}:${mac:4:2}:${mac:8:2}:${mac:12:2}:${mac:16:2}" >> /etc/systemd/network/10-$interface.network
