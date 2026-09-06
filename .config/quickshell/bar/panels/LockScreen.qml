pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/"
import "root:/panels"

// The lock itself: one surface per display, held by the compositor rather than
// by a layer shell.
//
// This is ext-session-lock, which is the difference between a window that covers
// the screen and a session that cannot be got at. Nothing of the desktop is
// behind it, nothing of the desktop can be reached around it, and if this
// process dies while it is up the compositor keeps the session locked rather
// than handing it back — see hypr/scripts/lock.sh for the way back in when that
// happens.
//
// Everything drawn is in LockFace.qml. All that is here is the plumbing, and it
// is short on purpose: the one property that matters is `locked`, and the only
// thing in the shell that sets it is Lock.
Scope {
    id: screen

    WlSessionLock {
        id: session

        locked: Lock.locked

        surface: WlSessionLockSurface {
            // Under everything, so a wallpaper that fails to load — or a frame
            // drawn before it has — is black rather than white. The one flash a
            // lock screen must never have is a bright one.
            color: "black"

            LockFace {
                anchors.fill: parent
            }
        }
    }
}
