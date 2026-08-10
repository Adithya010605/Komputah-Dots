#!/usr/bin/env bash

set -euo pipefail

SOURCE="@DEFAULT_AUDIO_SOURCE@"

print_status() {
  local muted
  muted="$(wpctl get-volume "$SOURCE" | awk '{print $3}')"

  if [[ "$muted" == "[MUTED]" ]]; then
    printf '{"text":"󰍭","class":"muted"}\n'
  else
    printf '{"text":"󰍬","class":"active"}\n'
  fi
}

case "${1:-status}" in
  toggle)
    wpctl set-mute "$SOURCE" toggle >/dev/null
    ;;
  status)
    print_status
    ;;
  *)
    print_status
    ;;
esac
