#!/usr/bin/env bash

set -euo pipefail

state="$(bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/ {print $2; exit}')"

if [[ "${state:-no}" == "yes" ]]; then
  bluetoothctl power off >/dev/null
else
  bluetoothctl power on >/dev/null
fi
