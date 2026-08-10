#!/usr/bin/env bash

set -u

fallback_text="Nothing is playing"
state_dir="${HOME}/.cache/waybar"
state_file="${state_dir}/mpris-selected-player"

json_escape() {
  local escaped="$1"
  escaped=${escaped//\\/\\\\}
  escaped=${escaped//\"/\\\"}
  escaped=${escaped//$'\n'/\\n}
  escaped=${escaped//$'\r'/\\r}
  escaped=${escaped//$'\t'/\\t}
  printf '%s' "$escaped"
}

player_icon() {
  case "$1" in
  *spotify*) printf '%s' "" ;;
  *firefox* | *zen*) printf '%s' "" ;;
  *chromium*) printf '%s' "" ;;
  *vlc*) printf '%s' "󰕼" ;;
  *) printf '%s' "" ;;
  esac
}

list_players() {
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    status="$(playerctl -p "$p" status 2>/dev/null || true)"
    case "$status" in
    Playing | Paused) printf '%s\t%s\n' "$p" "$status" ;;
    esac
  done < <(playerctl -l 2>/dev/null || true)
}

read_selected_player() {
  [ -f "$state_file" ] && cat "$state_file"
}

write_selected_player() {
  mkdir -p "$state_dir"
  printf '%s\n' "$1" > "$state_file"
}

select_default_player() {
  while IFS=$'\t' read -r p status; do
    [ "$status" = "Playing" ] && {
      printf '%s\n' "$p"
      return 0
    }
    [ -n "${first_paused:-}" ] || first_paused="$p"
  done <<< "$1"

  printf '%s\n' "${first_paused:-}"
}

resolve_target_player() {
  players="$1"
  selected="$(read_selected_player)"
  if [ -n "$selected" ] && printf '%s\n' "$players" | cut -f1 | grep -Fxq "$selected"; then
    printf '%s\n' "$selected"
    return 0
  fi

  selected="$(select_default_player "$players")"
  [ -n "$selected" ] && write_selected_player "$selected"
  printf '%s\n' "$selected"
}

cycle_player() {
  direction="$1"
  players="$(list_players)"
  [ -n "$players" ] || exit 0

  current="$(resolve_target_player "$players")"
  mapfile -t names < <(printf '%s\n' "$players" | cut -f1)

  current_index=0
  for i in "${!names[@]}"; do
    if [ "${names[$i]}" = "$current" ]; then
      current_index="$i"
      break
    fi
  done

  if [ "$direction" = "next" ]; then
    next_index=$(( (current_index + 1) % ${#names[@]} ))
  else
    next_index=$(( (current_index - 1 + ${#names[@]}) % ${#names[@]} ))
  fi

  write_selected_player "${names[$next_index]}"
}

toggle_selected() {
  players="$(list_players)"
  [ -n "$players" ] || exit 0
  target_player="$(resolve_target_player "$players")"
  [ -n "$target_player" ] && playerctl -p "$target_player" play-pause >/dev/null 2>&1
}

case "${1:-show}" in
next)
  cycle_player "next"
  exit 0
  ;;
prev)
  cycle_player "prev"
  exit 0
  ;;
toggle)
  toggle_selected
  exit 0
  ;;
esac

players="$(list_players)"

if [ -z "$players" ]; then
  rm -f "$state_file"
  printf '{"text":"%s","tooltip":"%s"}\n' "$(json_escape "$fallback_text")" "$(json_escape "$fallback_text")"
  exit 0
fi

target_player="$(resolve_target_player "$players")"
status="$(playerctl -p "$target_player" status 2>/dev/null || true)"
title="$(playerctl -p "$target_player" metadata xesam:title 2>/dev/null || true)"
artist="$(playerctl -p "$target_player" metadata xesam:artist 2>/dev/null | paste -sd ', ' - || true)"
icon="$(player_icon "$target_player")"

[ -n "$title" ] || title="$target_player"

if [ "$status" = "Paused" ]; then
  text="⏸ $icon $title"
else
  text="$icon $title"
fi

player_count="$(printf '%s\n' "$players" | grep -c .)"
[ "$player_count" -gt 1 ] && text="$text [$player_count]"

tooltip_lines=()
while IFS=$'\t' read -r p pstatus; do
  ptitle="$(playerctl -p "$p" metadata xesam:title 2>/dev/null || true)"
  partist="$(playerctl -p "$p" metadata xesam:artist 2>/dev/null | paste -sd ', ' - || true)"
  picon="$(player_icon "$p")"
  [ -n "$ptitle" ] || ptitle="$p"
  marker=" "
  [ "$p" = "$target_player" ] && marker="•"
  status_icon="▶"
  [ "$pstatus" = "Paused" ] && status_icon="⏸"
  line="$marker $status_icon $picon $ptitle"
  [ -n "$partist" ] && line="$line - $partist"
  tooltip_lines+=("$line")
done <<< "$players"

tooltip="$(printf '%s\n' "${tooltip_lines[@]}")"

printf '{"text":"%s","tooltip":"%s"}\n' "$(json_escape "$text")" "$(json_escape "$tooltip")"
