#!/usr/bin/env bash
# Toggles the quickshell audio panel, launching the daemon on first use.

CONFIG_NAME=audio
ANCHOR_FILE=/tmp/audio_popup_x
CALIBRATION_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/waybar/pulseaudio-anchor"

# The panel hangs under the pulseaudio module, so it anchors to that module's
# own centre rather than the pointer. Re-measure with:
#   waybar-anchor-calibrate.sh '#pulseaudio' pulseaudio
DEFAULT_ANCHOR=1101

ANCHOR_X=$(cat "$CALIBRATION_FILE" 2>/dev/null)
case "$ANCHOR_X" in
  '' | *[!0-9]*) ANCHOR_X=$DEFAULT_ANCHOR ;;
esac

printf '%s\n' "$ANCHOR_X" >"$ANCHOR_FILE"

if quickshell list -c "$CONFIG_NAME" 2>/dev/null | grep -q 'Process ID'; then
  quickshell -c "$CONFIG_NAME" ipc call audio toggle "$ANCHOR_X" >/dev/null 2>&1
else
  # A cold start opens the panel by itself, reading the anchor written above.
  quickshell -c "$CONFIG_NAME" --daemonize
fi
