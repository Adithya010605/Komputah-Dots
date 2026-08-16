#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
#  「✦ POMODORO TIMER ✦ 」
# ─────────────────────────────────────────────────────────────────────
# Shared backend for the waybar module and the quickshell popup.
#
#   pomo.sh                 -> waybar json (cheap path, no stats)
#   pomo.sh state           -> full json incl. study stats (quickshell)
#   pomo.sh toggle          -> start / pause / resume
#   pomo.sh start|stop      -> explicit control (stop logs partial time)
#   pomo.sh reset           -> reset the running timer, keep history
#   pomo.sh reset-today     -> erase today's logged sessions
#   pomo.sh preset-next|prev
# ─────────────────────────────────────────────────────────────────────

STATE_FILE=/tmp/break_state
PRESET_FILE=/tmp/break_preset
PAUSED_FILE=/tmp/break_paused
STARTED_FILE=/tmp/break_started
SESSION_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/pomodoro/sessions.log"

MIN_PRESET=5
MAX_PRESET=120
STEP_PRESET=5
DEFAULT_PRESET=20

# Sessions shorter than this (minutes) are not worth logging.
MIN_LOGGED=1

# ─── preset ──────────────────────────────────────────────────────────

get_preset_minutes() {
  if [ -f "$PRESET_FILE" ]; then
    preset=$(cat "$PRESET_FILE" 2>/dev/null)
    case "$preset" in
      '' | *[!0-9]*) ;;
      *)
        if [ "$preset" -ge "$MIN_PRESET" ] && [ "$preset" -le "$MAX_PRESET" ]; then
          printf '%s\n' "$preset"
          return
        fi
        ;;
    esac
  fi
  printf '%s\n' "$DEFAULT_PRESET"
}

set_preset_minutes() {
  printf '%s\n' "$1" >"$PRESET_FILE"
}

adjust_preset() {
  # Preset is locked while a timer is live.
  [ -f "$STATE_FILE" ] && return 0

  current=$(get_preset_minutes)

  if [ "$1" = "next" ]; then
    new_preset=$((current + STEP_PRESET))
    [ "$new_preset" -gt "$MAX_PRESET" ] && new_preset=$MAX_PRESET
  else
    new_preset=$((current - STEP_PRESET))
    [ "$new_preset" -lt "$MIN_PRESET" ] && new_preset=$MIN_PRESET
  fi

  set_preset_minutes "$new_preset"
}

# ─── session log ─────────────────────────────────────────────────────
#
# Format:  YYYY-MM-DD HH:MM MINUTES KIND
# Legacy two-field rows (YYYY-MM-DD MINUTES) are still read correctly.

log_session() {
  minutes=$1
  kind=${2:-focus}

  [ "$minutes" -ge "$MIN_LOGGED" ] 2>/dev/null || return 0

  mkdir -p "$(dirname "$SESSION_LOG")"
  printf '%s %s %s %s\n' "$(date +%F)" "$(date +%H:%M)" "$minutes" "$kind" >>"$SESSION_LOG"
}

# ─── timer ───────────────────────────────────────────────────────────

start_timer() {
  duration_minutes=$(get_preset_minutes)
  end_time=$(($(date +%s) + duration_minutes * 60))
  printf '%s\n' "$end_time" >"$STATE_FILE"
  printf '%s\n' "$duration_minutes" >"$STARTED_FILE"
  rm -f "$PAUSED_FILE"
}

pause_timer() {
  { [ -f "$STATE_FILE" ] && [ ! -f "$PAUSED_FILE" ]; } || return 0

  end_time=$(cat "$STATE_FILE" 2>/dev/null)
  remaining=$((end_time - $(date +%s)))

  if [ "$remaining" -le 0 ]; then
    complete_timer
    return
  fi

  printf '%s\n' "$remaining" >"$STATE_FILE"
  touch "$PAUSED_FILE"
}

resume_timer() {
  { [ -f "$STATE_FILE" ] && [ -f "$PAUSED_FILE" ]; } || return 0

  remaining=$(cat "$STATE_FILE" 2>/dev/null)
  case "$remaining" in
    '' | *[!0-9]*)
      rm -f "$STATE_FILE" "$PAUSED_FILE" "$STARTED_FILE"
      return
      ;;
  esac

  printf '%s\n' "$(($(date +%s) + remaining))" >"$STATE_FILE"
  rm -f "$PAUSED_FILE"
}

# How many whole minutes have actually been spent on the live timer.
elapsed_minutes() {
  planned=$(cat "$STARTED_FILE" 2>/dev/null)
  case "$planned" in
    '' | *[!0-9]*) planned=$(get_preset_minutes) ;;
  esac

  if [ -f "$PAUSED_FILE" ]; then
    remaining=$(cat "$STATE_FILE" 2>/dev/null)
  else
    end_time=$(cat "$STATE_FILE" 2>/dev/null)
    remaining=$((end_time - $(date +%s)))
  fi

  case "$remaining" in
    '' | *[!0-9-]*) remaining=0 ;;
  esac
  [ "$remaining" -lt 0 ] && remaining=0

  printf '%s\n' $((planned - remaining / 60))
}

# Claiming the state file makes completion idempotent: the waybar tick and
# the quickshell poll both race here, and only the winner logs the session.
complete_timer() {
  claim="${STATE_FILE}.done.$$"
  mv "$STATE_FILE" "$claim" 2>/dev/null || return 0

  planned=$(cat "$STARTED_FILE" 2>/dev/null)
  case "$planned" in
    '' | *[!0-9]*) planned=$(get_preset_minutes) ;;
  esac

  rm -f "$claim" "$PAUSED_FILE" "$STARTED_FILE"

  log_session "$planned" focus
  notify-send "Pomodoro" "Session complete — ${planned} minutes logged"
}

# Stopping early still banks the time actually studied.
stop_timer() {
  [ -f "$STATE_FILE" ] || return 0

  spent=$(elapsed_minutes)
  claim="${STATE_FILE}.stop.$$"
  mv "$STATE_FILE" "$claim" 2>/dev/null || return 0
  rm -f "$claim" "$PAUSED_FILE" "$STARTED_FILE"

  if [ "$spent" -ge "$MIN_LOGGED" ]; then
    log_session "$spent" partial
    notify-send "Pomodoro" "Stopped — ${spent} min logged"
  else
    notify-send "Pomodoro" "Timer stopped"
  fi
}

# Reset the timer only. History is untouched.
reset_timer() {
  [ -f "$STATE_FILE" ] || return 0

  spent=$(elapsed_minutes)
  claim="${STATE_FILE}.reset.$$"
  mv "$STATE_FILE" "$claim" 2>/dev/null || return 0
  rm -f "$claim" "$PAUSED_FILE" "$STARTED_FILE"

  [ "$spent" -ge "$MIN_LOGGED" ] && log_session "$spent" partial
}

reset_today() {
  rm -f "$STATE_FILE" "$PAUSED_FILE" "$STARTED_FILE"

  if [ -f "$SESSION_LOG" ]; then
    today=$(date +%F)
    tmp_file="${SESSION_LOG}.tmp"
    awk -v today="$today" '$1 != today' "$SESSION_LOG" >"$tmp_file" && mv "$tmp_file" "$SESSION_LOG"
  fi

  notify-send "Pomodoro" "Today's sessions cleared"
}

# ─── live timer snapshot ─────────────────────────────────────────────
#
# Echoes "running paused remaining", completing the timer if it has expired.

timer_snapshot() {
  running=false
  paused=false
  remaining=0

  if [ -f "$STATE_FILE" ]; then
    if [ -f "$PAUSED_FILE" ]; then
      paused=true
      remaining=$(cat "$STATE_FILE" 2>/dev/null)
    else
      end_time=$(cat "$STATE_FILE" 2>/dev/null)
      remaining=$((end_time - $(date +%s)))
    fi

    case "$remaining" in
      '' | *[!0-9-]*)
        rm -f "$STATE_FILE" "$PAUSED_FILE" "$STARTED_FILE"
        remaining=0
        ;;
    esac

    if [ "$remaining" -le 0 ]; then
      complete_timer
      running=false
      paused=false
      remaining=0
    else
      running=true
    fi
  fi

  printf '%s %s %s\n' "$running" "$paused" "$remaining"
}

# ─── stats ───────────────────────────────────────────────────────────
#
# One awk pass over the log produces every figure the popup shows.
# Dates are converted to day numbers in-awk (no per-day `date` forks), so
# this stays cheap enough to poll.

stats_json() {
  if [ ! -f "$SESSION_LOG" ]; then
    printf '"today_minutes":0,"today_sessions":0,"week_minutes":0,"week_sessions":0,'
    printf '"total_minutes":0,"total_sessions":0,"streak":0,"best_day_minutes":0,'
    printf '"active_days":0,"week":[]'
    return
  fi

  awk -v today="$(date +%F)" '
    # Days since 1970-01-01, per Howard Hinnant days_from_civil.
    function day_number(y, m, d,   era, yoe, doy, doe) {
      y -= (m <= 2)
      era = int((y >= 0 ? y : y - 399) / 400)
      yoe = y - era * 400
      doy = int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1
      doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
      return era * 146097 + doe - 719468
    }

    function to_day_number(iso,   p) {
      if (split(iso, p, "-") != 3) return -1
      return day_number(p[1] + 0, p[2] + 0, p[3] + 0)
    }

    BEGIN {
      split("Sun Mon Tue Wed Thu Fri Sat", names, " ")
      today_num = to_day_number(today)
    }

    {
      # New rows carry a time column; legacy rows do not.
      if (NF >= 3) { date = $1; mins = $3 + 0 }
      else         { date = $1; mins = $2 + 0 }

      if (mins <= 0) next
      num = to_day_number(date)
      if (num < 0) next

      minutes[num] += mins
      count[num] += 1
      total += mins
      sessions += 1
    }

    END {
      for (num in minutes) {
        active += 1
        if (minutes[num] > best) best = minutes[num]

        offset = today_num - num
        if (offset >= 0 && offset < 7) {
          week_minutes += minutes[num]
          week_sessions += count[num]
        }
      }

      # A streak survives a day that has not happened yet, so start from
      # yesterday when nothing has been logged today.
      cursor = (minutes[today_num] > 0) ? today_num : today_num - 1
      while (minutes[cursor] > 0) { streak += 1; cursor -= 1 }

      printf "\"today_minutes\":%d,\"today_sessions\":%d,", minutes[today_num] + 0, count[today_num] + 0
      printf "\"week_minutes\":%d,\"week_sessions\":%d,", week_minutes + 0, week_sessions + 0
      printf "\"total_minutes\":%d,\"total_sessions\":%d,", total + 0, sessions + 0
      printf "\"streak\":%d,\"best_day_minutes\":%d,", streak + 0, best + 0
      printf "\"active_days\":%d,\"week\":[", active + 0

      # Oldest to newest, ending today.
      for (i = 6; i >= 0; i--) {
        num = today_num - i
        printf "%s{\"day\":\"%s\",\"minutes\":%d}", (i < 6 ? "," : ""), names[(num % 7 + 7 + 4) % 7 + 1], minutes[num] + 0
      }
      printf "]"
    }
  ' "$SESSION_LOG"
}

print_state() {
  read -r running paused remaining <<<"$(timer_snapshot)"

  printf '{"preset_minutes":%s,"remaining_seconds":%s,"running":%s,"paused":%s,%s}\n' \
    "$(get_preset_minutes)" "$remaining" "$running" "$paused" "$(stats_json)"
}

# ─── waybar module ───────────────────────────────────────────────────

print_waybar() {
  duration_minutes=$(get_preset_minutes)
  read -r running paused remaining <<<"$(timer_snapshot)"

  if [ "$running" != "true" ]; then
    printf '{"text":"󰔟","tooltip":"Pomodoro — %s min ready","class":"idle"}\n' "$duration_minutes"
    return
  fi

  label=$(printf '%02d:%02d' $((remaining / 60)) $((remaining % 60)))

  if [ "$paused" = "true" ]; then
    printf '{"text":"󰏤 %s","tooltip":"Paused","class":"paused"}\n' "$label"
  else
    printf '{"text":"󰔟 %s","tooltip":"Focusing — %s min session","class":"running"}\n' "$label" "$duration_minutes"
  fi
}

# ─── entrypoint ──────────────────────────────────────────────────────

case "$1" in
  start) start_timer ;;
  stop) stop_timer ;;
  reset) reset_timer ;;
  reset-today) reset_today ;;
  state | stats) print_state ;;
  preset-next) adjust_preset next ;;
  preset-prev) adjust_preset prev ;;
  toggle)
    if [ -f "$STATE_FILE" ]; then
      if [ -f "$PAUSED_FILE" ]; then resume_timer; else pause_timer; fi
    else
      start_timer
    fi
    ;;
  *) print_waybar ;;
esac
