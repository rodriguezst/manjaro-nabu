# Manjaro ARM for Xiaomi Pad 5
[![stable-build](https://github.com/rodriguezst/manjaro-nabu/workflows/build-manjaro-stable/badge.svg)](https://github.com/rodriguezst/manjaro-nabu/actions)

[![unstable-build](https://github.com/rodriguezst/manjaro-nabu/workflows/build-manjaro-unstable/badge.svg)](https://github.com/rodriguezst/manjaro-nabu/actions)

## Description

Development Branch for Manjaro ARM images for Xiaomi Pad 5

## Features

- RootFS images built using official Manjaro ARM workflows
- Linux kernel 6.1 for nabu based on maverickjb and updated to 6.1.98
- Persistent WLAN MAC address across reboots
- Qbootctl command with systemd service to set boot flag as successful
- Nabu firmware and alsa files from map220v
- UKI kernel images included in the esp partition automatically detected by UEFI

## Where can I download an image?

[GitHub Releases](https://github.com/rodriguezst/manjaro-nabu/releases)

## Sources

Building from generic-efi profile from here: [image profiles](https://gitlab.manjaro.org/manjaro-arm/applications/arm-profiles)

