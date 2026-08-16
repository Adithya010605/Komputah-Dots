#!/usr/bin/env sh
# One lock path, used by every trigger — the keybind, hypridle's idle timeout,
# and logind's before-sleep hook — so there is only ever one way the screen
# gets locked and only ever one hyprlock behind it.

# A quickshell panel that has taken keyboard focus is a layer surface the lock
# screen would not be getting keystrokes from, so it goes first.
quickshell -c bar ipc call panel close >/dev/null 2>&1

# Guarded: a second hyprlock cannot lock an already-locked session, and the
# instance that fails on the way in is one more thing that can leave the
# session locked with nothing to type into.
pidof hyprlock >/dev/null 2>&1 && exit 0

# Kept so there is something to read if it ever dies mid-lock.
exec hyprlock >>"$HOME/.cache/hyprlock.log" 2>&1
