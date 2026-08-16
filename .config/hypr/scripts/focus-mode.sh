#!/bin/bash
# ─────────────────────────────────────────────────────────────────────
#  「✦ FOCUS MODE TOGGLE ✦ 」
# ─────────────────────────────────────────────────────────────────────
# TOGGLES FOCUS MODE BY REMOVING GAPS, BORDERS, AND THE BAR
# ─────────────────────────────────────────────────────────────────────

STATE_FILE="/tmp/hypr_focus_mode"

if [ -f "$STATE_FILE" ]; then
  hyprctl reload
  quickshell -c bar --daemonize >/dev/null 2>&1
  rm "$STATE_FILE"
else
  hyprctl keyword general:gaps_in 0
  hyprctl keyword general:gaps_out 0
  hyprctl keyword decoration:rounding 0
  pkill -f "quickshell -c bar "
  pkill waybar
  touch "$STATE_FILE"
fi
