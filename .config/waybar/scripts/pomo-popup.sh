#!/usr/bin/env bash
# Toggles the quickshell pomodoro panel, launching the daemon on first use.

CONFIG_NAME=pomo
ANCHOR_FILE=/tmp/break_popup_x

# Where the click landed, so the panel drops out of the icon rather than a
# hardcoded spot on the bar. Passed over IPC for a running daemon, and left
# in a file for a cold start to pick up.
CURSOR_X=$(hyprctl cursorpos 2>/dev/null | cut -d, -f1 | tr -d ' ')
printf '%s\n' "${CURSOR_X:-960}" >"$ANCHOR_FILE"

if quickshell list -c "$CONFIG_NAME" 2>/dev/null | grep -q 'Process ID'; then
  quickshell -c "$CONFIG_NAME" ipc call pomo toggle "${CURSOR_X:-960}" >/dev/null 2>&1
else
  # A cold start opens the panel by itself, reading the anchor written above.
  quickshell -c "$CONFIG_NAME" --daemonize
fi
