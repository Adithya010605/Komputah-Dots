#!/usr/bin/env bash

set -euo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/pomodoro"
state_file="$state_dir/quickshell.state"
session_log="$state_dir/sessions.log"
default_preset=25

mkdir -p "$state_dir"

read_state() {
  preset=$default_preset
  end_time=0
  remaining=0
  paused=false

  if [[ -f "$state_file" ]]; then
    # The state file is only written by this script and contains plain key/value pairs.
    source "$state_file"
  fi
}

write_state() {
  printf 'preset=%q\nend_time=%q\nremaining=%q\npaused=%q\n' "$preset" "$end_time" "$remaining" "$paused" >"$state_file"
}

today_stats() {
  local today count minutes
  today="$(date +%F)"
  count=0
  minutes=0
  if [[ -f "$session_log" ]]; then
    read -r count minutes < <(awk -v date="$today" '$1 == date { count++; minutes += $2 } END { print count + 0, minutes + 0 }' "$session_log")
  fi
  printf '%s %s\n' "$count" "$minutes"
}

finish_if_needed() {
  local now
  now="$(date +%s)"
  if [[ "$end_time" -gt 0 && "$paused" == false && "$end_time" -le "$now" ]]; then
    printf '%s %s\n' "$(date +%F)" "$preset" >>"$session_log"
    end_time=0
    remaining=0
    paused=false
    write_state
    notify-send "Pomodoro complete" "${preset} minutes of focused work logged"
  fi
}

status() {
  read_state
  finish_if_needed

  local now running count minutes
  now="$(date +%s)"
  running=false
  if [[ "$end_time" -gt 0 || "$paused" == true ]]; then
    running=true
  fi
  if [[ "$paused" == false && "$end_time" -gt 0 ]]; then
    remaining=$((end_time - now))
  fi
  [[ "$remaining" -gt 0 ]] || remaining=0
  read -r count minutes < <(today_stats)
  printf '{"preset":%d,"running":%s,"paused":%s,"remaining":%d,"todayCount":%d,"todayMinutes":%d}\n' "$preset" "$running" "$paused" "$remaining" "$count" "$minutes"
}

case "${1:-status}" in
  status) status ;;
  toggle)
    read_state
    now="$(date +%s)"
    if [[ "$end_time" -gt 0 && "$paused" == false ]]; then
      remaining=$((end_time - now))
      end_time=0
      paused=true
    elif [[ "$paused" == true ]]; then
      end_time=$((now + remaining))
      paused=false
    else
      remaining=$((preset * 60))
      end_time=$((now + remaining))
      paused=false
    fi
    write_state
    ;;
  stop)
    read_state
    end_time=0
    remaining=0
    paused=false
    write_state
    ;;
  preset)
    read_state
    [[ "$end_time" -eq 0 && "$paused" == false ]] || exit 0
    [[ "${2:-}" =~ ^[0-9]+$ ]] || exit 1
    preset="$2"
    (( preset >= 5 && preset <= 120 )) || exit 1
    write_state
    ;;
  *) exit 1 ;;
esac
