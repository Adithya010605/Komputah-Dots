#!/usr/bin/env sh
# One lock path, used by every trigger — the keybind, hypridle's idle timeout,
# and logind's before-sleep hook — so there is only ever one way the screen gets
# locked and only ever one client behind it.
#
# That client is now the quickshell lock screen (bar/panels/LockScreen.qml),
# with hyprlock kept as the fallback rather than as the default. The order
# matters more than it looks: quickshell is already running, already holds the
# wallpaper palette and already has the whole surface built, so it locks in the
# time it takes to set a property — where hyprlock has to start, parse a config
# and load an image first, and every millisecond of that is a millisecond of
# unlocked desktop after you asked for a locked one.
#
# hyprlock is still installed and still configured, and every path below that
# cannot prove quickshell took the lock ends up at it.
#
#   lock.sh              lock the session
#   lock.sh --rescue     hand the session to hyprlock, still locked
#
set -eu

# ── the way out ──────────────────────────────────────────────────────
#
# For a lock screen that is up but not working: kills the shell holding the lock
# and puts hyprlock on it instead. The session is never unlocked in the process
# — dropping an ext-session-lock client does not release the lock, the
# compositor keeps the screen locked with nothing on it, and
# allow_session_lock_restore (see hyprland.lua) is what lets a fresh client
# attach to the lock that is already there.
#
# It takes the bar down with it, because the bar is in the same process. That is
# the trade: a shell to restart, against a session only a TTY can reach.
if [ "${1:-}" = "--rescue" ]; then
    pkill -x quickshell || true
    sleep 0.5
    exec hyprlock >>"$HOME/.cache/hyprlock.log" 2>&1
fi

# A quickshell panel that has taken keyboard focus is a layer surface the lock
# screen would not be getting keystrokes from, so it goes first.
quickshell -c bar ipc call panel close >/dev/null 2>&1 || true

# Guarded: a second hyprlock cannot lock an already-locked session, and the
# instance that fails on the way in is one more thing that can leave the session
# locked with nothing to type into.
pidof hyprlock >/dev/null 2>&1 && exit 0

# ── quickshell first ─────────────────────────────────────────────────

# Asked rather than assumed. This one call proves three things at once: the
# process is running, it is running a config with a lock in it, and that lock is
# not already up. Anything else — no shell, an older config, a shell that has
# stopped answering — comes back as neither word and falls through to hyprlock,
# which is also exactly what should happen in all three cases.
state=$(quickshell -c bar ipc call lock status 2>/dev/null || true)

[ "$state" = "locked" ] && exit 0

if [ "$state" = "unlocked" ]; then
    quickshell -c bar ipc call lock lock >/dev/null 2>&1 || true

    # Confirmed rather than assumed, and this is the important line in the file.
    # `ipc call` reports a target it could not find on stdout and still exits 0,
    # so the only trustworthy answer to "did that lock the session" is to ask
    # again. Without this, a call that was accepted and did nothing would leave
    # the session unlocked and the fallback below never tried.
    [ "$(quickshell -c bar ipc call lock status 2>/dev/null || true)" = "locked" ] && exit 0
fi

# ── hyprlock otherwise ───────────────────────────────────────────────
#
# Kept so there is something to read if it ever dies mid-lock.
exec hyprlock >>"$HOME/.cache/hyprlock.log" 2>&1
