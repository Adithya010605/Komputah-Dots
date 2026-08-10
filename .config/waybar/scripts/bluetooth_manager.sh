#!/usr/bin/env bash

set -euo pipefail

if ! pgrep -x blueman-applet >/dev/null 2>&1; then
  blueman-applet >/dev/null 2>&1 &
  sleep 1
fi

gtk-launch blueman-manager >/dev/null 2>&1 &
disown
