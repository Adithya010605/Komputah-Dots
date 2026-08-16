#!/usr/bin/env bash
# Switches the desktop between the quickshell bar (the primary bar, started at
# login) and waybar (kept around as a fallback).
#
# The two can run at once — quickshell simply stacks below waybar — which is
# useful for comparing them, but only one should own the top of the screen day
# to day.
#
#   bar-switch.sh on       quickshell bar takes over
#   bar-switch.sh off      fall back to waybar
#   bar-switch.sh toggle   swap whichever bar is up for the other one
#   bar-switch.sh restart  reload the quickshell bar in place
#   bar-switch.sh status   what is running now

set -u

# The standalone panel daemons are superseded by the bar, which now hosts the
# same panels in its own process. Leaving them running is harmless but means
# two copies of each panel answer to different triggers.
LEGACY_CONFIGS=(audio media pomo)

quickshell_pid() {
  pgrep -f "quickshell -c $1 " 2>/dev/null | head -1
}

# Every matching instance, not just the first: quickshell restarts itself after
# a crash, so a stale copy can be left behind and two bars stack on the screen.
stop_quickshell() {
  pkill -f "quickshell -c $1 " 2>/dev/null
  return 0
}

start_bar() {
  if [ -n "$(quickshell_pid bar)" ]; then
    printf 'quickshell bar is already running\n'
    return
  fi

  quickshell -c bar --daemonize >/dev/null 2>&1
}

bar_on() {
  pkill -x waybar 2>/dev/null

  for config in "${LEGACY_CONFIGS[@]}"; do
    stop_quickshell "$config"
  done

  start_bar
  printf 'quickshell bar is up; waybar stopped\n'
}

bar_off() {
  stop_quickshell bar

  if ! pgrep -x waybar >/dev/null 2>&1; then
    waybar >/dev/null 2>&1 &
    disown
  fi

  printf 'waybar is back; quickshell bar stopped\n'
}

case "${1:-status}" in
on)
  bar_on
  ;;

off)
  bar_off
  ;;

toggle)
  if [ -n "$(quickshell_pid bar)" ]; then
    bar_off
  else
    bar_on
  fi
  ;;

restart)
  stop_quickshell bar
  sleep 1
  start_bar
  printf 'quickshell bar restarted\n'
  ;;

status)
  pgrep -x waybar >/dev/null 2>&1 && printf 'waybar:          running\n' || printf 'waybar:          stopped\n'
  [ -n "$(quickshell_pid bar)" ] && printf 'quickshell bar:  running\n' || printf 'quickshell bar:  stopped\n'

  for config in "${LEGACY_CONFIGS[@]}"; do
    [ -n "$(quickshell_pid "$config")" ] && printf 'legacy %-9s running\n' "$config:"
  done
  ;;

*)
  printf 'usage: %s {on|off|toggle|restart|status}\n' "${0##*/}" >&2
  exit 2
  ;;
esac

exit 0
