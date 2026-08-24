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

# Rewrite the first `path =` in a Hyprland-style config, in place.
persist() {
    local conf=$1 path=$2 tmp

    [ -f "$conf" ] || return 0

    tmp=$(mktemp)
    awk -v path="$path" '
        !done && /^[[:space:]]*path[[:space:]]*=/ { print "    path = " path; done = 1; next }
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

# -n: hyprpaper owns the desktop, pywal owns only the palette.
wal -i "$wallpaper" -n -q

# Waybar reads the same generated palette but has to be told to re-read it.
# Absent most of the time, and its absence is not a failure.
pkill -SIGUSR2 -x waybar 2>/dev/null || true

persist "$hyprpaper_conf" "$wallpaper"
persist "$hyprlock_conf" "$wallpaper"
