#!/usr/bin/env bash
# Measures where a waybar module actually sits on the bar, so a quickshell
# panel can hang under it instead of under the mouse pointer.
#
# Waybar exposes no geometry for individual modules, so the module is flagged
# with an unmistakable fill for one screenshot, located by pixel, and put back.
# Run this after changing bar layout, fonts, or module widths.
#
#   waybar-anchor-calibrate.sh '#custom-mpris' mpris
#   waybar-anchor-calibrate.sh '#pulseaudio'   pulseaudio

set -u

SELECTOR=${1:-}
NAME=${2:-}

if [ -z "$SELECTOR" ] || [ -z "$NAME" ]; then
  printf 'usage: %s <css-selector> <name>\n' "${0##*/}" >&2
  exit 2
fi

STYLE=~/.config/waybar/style.css
CALIBRATION_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/waybar/${NAME}-anchor"
MARKER="/* waybar-anchor-calibration */"
SHOT=$(mktemp --suffix=.png)
BACKUP=$(mktemp --suffix=.css)

for tool in grim magick; do
  command -v "$tool" >/dev/null || {
    printf 'calibrate: %s is required\n' "$tool" >&2
    exit 1
  }
done

cp "$STYLE" "$BACKUP"

# Always put the stylesheet back, even if this is interrupted part way.
cleanup() {
  cp "$BACKUP" "$STYLE"
  rm -f "$BACKUP" "$SHOT"
}
trap cleanup EXIT INT TERM

printf '\n%s\n%s { background: #ff00ff; border-color: #ff00ff; }\n' "$MARKER" "$SELECTOR" >>"$STYLE"

# waybar has reload_style_on_change set, so it repaints on its own.
sleep 2

BAR_TOP=$(python3 -c "
import json, re
raw = open('$HOME/.config/waybar/config').read()
print(json.loads(re.sub(r'^\s*//.*$', '', raw, flags=re.M)).get('margin-top', 0))
" 2>/dev/null || printf '0')

SCREEN_W=$(hyprctl monitors -j 2>/dev/null | python3 -c "
import json, sys
print(max((m['width'] for m in json.load(sys.stdin)), default=1920))
" 2>/dev/null || printf '1920')

# A fullscreen window covers the bar on Hyprland, so the flagged module is
# simply not on screen and there is nothing to measure. Rather than writing a
# wrong number, keep looking for a few seconds.
ATTEMPTS=${ATTEMPTS:-8}
MEASURED=""

for _ in $(seq "$ATTEMPTS"); do
  grim -g "0,${BAR_TOP} ${SCREEN_W}x40" "$SHOT" 2>/dev/null || {
    printf 'calibrate: screenshot failed\n' >&2
    exit 1
  }

  MEASURED=$(magick "$SHOT" -crop "${SCREEN_W}x1+0+20" +repage txt:- 2>/dev/null | python3 -c "
import sys, re

hits = []
for line in sys.stdin:
    m = re.match(r'(\d+),0: \((\d+),(\d+),(\d+)', line)
    if not m:
        continue
    x, r, g, b = (int(m.group(i)) for i in range(1, 5))
    if r > 180 and b > 180 and g < 90:
        hits.append(x)

if not hits:
    raise SystemExit(1)

left, right = min(hits), max(hits)
print(f'{left} {right} {(left + right) // 2}')
")

  [ -n "$MEASURED" ] && break
  sleep 1
done

if [ -z "$MEASURED" ]; then
  printf 'calibrate: could not find %s on screen.\n' "$SELECTOR" >&2
  printf 'The bar must be visible — a fullscreen window hides it on Hyprland.\n' >&2
  exit 1
fi

read -r LEFT RIGHT MID <<<"$MEASURED"

mkdir -p "$(dirname "$CALIBRATION_FILE")"
printf '%s\n' "$MID" >"$CALIBRATION_FILE"

printf '%s: x %s..%s (width %s), centre %s\n' "$SELECTOR" "$LEFT" "$RIGHT" "$((RIGHT - LEFT + 1))" "$MID"
printf 'written to %s\n' "$CALIBRATION_FILE"
