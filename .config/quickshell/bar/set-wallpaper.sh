#!/usr/bin/env bash
#
# Swap the desktop wallpaper and re-theme the shell from it.
#
# Several things have to happen together for the swap to read as one action:
# hyprpaper puts the image on the desktop, pywal regenerates the palette that
# Theme.qml watches, and both hyprpaper.conf and hyprlock.conf are rewritten so
# the choice survives a reboot and the lock screen matches what is behind it.
# Quickshell picks the new colours up on its own — the FileView on
# ~/.cache/wal/colors.json is watching — so nothing here restarts the shell.
#
# This is the same job the rofi picker at ~/.config/rofi/scripts did; the
# Quickshell menu calls in here rather than reimplementing it, and it stays
# usable on its own:
#
#   ~/.config/quickshell/bar/set-wallpaper.sh ~/walls/clouds.jpg

set -euo pipefail

wallpaper=${1:-}
hyprpaper_conf=${HYPRPAPER_CONF:-$HOME/.config/hypr/hyprpaper.conf}
hyprlock_conf=${HYPRLOCK_CONF:-$HOME/.config/hypr/hyprlock.conf}

if [ -z "$wallpaper" ]; then
    echo "usage: set-wallpaper.sh <image>" >&2
    exit 2
fi

if [ ! -f "$wallpaper" ]; then
    echo "no such wallpaper: $wallpaper" >&2
    exit 1
fi

# Rewrite the first line assigning to `key` in a config, in place. Handles both
# the Hyprland form (`path = /x`) and the JSON one (`"wallpaper": "/x",`), since
# the only difference is how the value is quoted.
rewrite_field() {
    local conf=$1 key=$2 value=$3 tmp

    [ -f "$conf" ] || return 0

    tmp=$(mktemp)
    awk -v key="$key" -v value="$value" '
        !done && index($0, key) && $0 ~ "^[[:space:]]*" key "[[:space:]]*[=:]" {
            done = 1
            if (key ~ /^"/) print "    " key ": \"" value "\","
            else print "    " key " = " value
            next
        }
        { print }
    ' "$conf" >"$tmp"

    # Truncated in place rather than moved, so the file keeps its inode and
    # anything watching it sees a change rather than a delete.
    cat "$tmp" >"$conf"
    rm -f "$tmp"
}

# Named monitors, always. hyprpaper 0.8 accepts the empty-monitor form
# (",path") but only actually lands the first time it is used and then silently
# no-ops on every swap after that — which is why the old picker seemed to stop
# working after the first change of a session. The name never gets left out.
while read -r monitor; do
    [ -n "$monitor" ] || continue
    hyprctl hyprpaper wallpaper "$monitor,$wallpaper" >/dev/null
done < <(hyprctl monitors | awk '/^Monitor /{print $2}')

# pywal's only working backend here is ImageMagick's quantiser, and it gives up
# on an image that does not hold sixteen distinguishable colours — a near-black
# wallpaper walks it up to a 34-colour palette and then exits 1. Such an image
# is still perfectly good on the desktop, so rather than refuse it, theme from a
# contrast-stretched copy. Only the palette comes from the copy; hyprpaper is
# already showing the original.
#
# -n: hyprpaper owns the desktop, pywal owns only the palette.
theme() {
    local image=$1 stretched status

    if wal -i "$image" -n -q 2>/dev/null; then
        return 0
    fi

    stretched=$(mktemp --suffix=.png)
    status=1

    if magick "$image" -auto-level -normalize "$stretched" 2>/dev/null &&
        wal -i "$stretched" -n -q 2>/dev/null; then
        # pywal records the file it read, and the picker reads that record back
        # to mark the live thumbnail. Point it at the wallpaper that was chosen
        # rather than at the scratch copy, which is gone a line later.
        printf '%s' "$image" >"$HOME/.cache/wal/wal"
        rewrite_field "$HOME/.cache/wal/colors.json" '"wallpaper"' "$image"
        status=0
    fi

    rm -f "$stretched"
    return "$status"
}

if ! theme "$wallpaper"; then
    echo "no palette could be built from ${wallpaper##*/}" >&2
    exit 1
fi

# Waybar reads the same generated palette but has to be told to re-read it.
# Absent most of the time, and its absence is not a failure.
pkill -SIGUSR2 -x waybar 2>/dev/null || true

rewrite_field "$hyprpaper_conf" path "$wallpaper"
rewrite_field "$hyprlock_conf" path "$wallpaper"
