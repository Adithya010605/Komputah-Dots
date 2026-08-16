#!/usr/bin/env bash
# Toggles the quickshell media panel, launching the daemon on first use.

CONFIG_NAME=media
ANCHOR_FILE=/tmp/media_popup_x
CALIBRATION_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/waybar/mpris-anchor"

# The panel hangs under the mpris module, so it anchors to that module's own
# centre — not to wherever inside the pill the pointer happened to land, which
# made every open land somewhere new.
#
# Measured with media-anchor-calibrate.sh: the pill spans 635..885, so its
# centre is 760. Re-run that script if the bar layout changes.
DEFAULT_ANCHOR=760

ANCHOR_X=$(cat "$CALIBRATION_FILE" 2>/dev/null)
case "$ANCHOR_X" in
  '' | *[!0-9]*) ANCHOR_X=$DEFAULT_ANCHOR ;;
esac

printf '%s\n' "$ANCHOR_X" >"$ANCHOR_FILE"

if quickshell list -c "$CONFIG_NAME" 2>/dev/null | grep -q 'Process ID'; then
  quickshell -c "$CONFIG_NAME" ipc call media toggle "$ANCHOR_X" >/dev/null 2>&1
else
  # A cold start opens the panel by itself, reading the anchor written above.
  quickshell -c "$CONFIG_NAME" --daemonize
fi
