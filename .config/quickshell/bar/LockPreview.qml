import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/"
import "root:/panels"

// The lock screen, without the lock.
//
// LockFace draws the whole thing and holds none of the session, so pointing a
// plain overlay window at it puts the entire screen up exactly as it will look
// with nothing to type into and nothing to unlock. Which is the only sane way to
// work on it: the alternative is locking the machine every time a margin moves.
//
//   quickshell -p ~/.config/quickshell/bar/LockPreview.qml
//
// It runs a scripted attempt — type, get it wrong, get caught, type again, get
// through — and then quits on its own, so a preview left running is not a
// window that has to be found and killed.
//
// Nothing here touches PAM. `Lock.state` is written directly, which is exactly
// what PAM's answers do to it, so every sequence on screen is the real one.
ShellRoot {
    id: preview

    PanelWindow {
        id: window

        color: "black"

        WlrLayershell.namespace: "quickshell-lock-preview"
        WlrLayershell.layer: WlrLayer.Overlay

        // Never. It is a preview covering a working desktop, and a preview that
        // eats the keyboard is a preview you have to reach for a TTY to escape.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        LockFace {
            anchors.fill: parent

            // No field, no focus, no keystrokes reaching it.
            live: false

            // Whatever is worth looking at the glass against, rather than
            // whatever is on the desktop today.
            wallpaper: Quickshell.env("QS_LOCK_WALL") || Wallpapers.current
        }

        SequentialAnimation {
            running: true

            PauseAnimation {
                duration: 1400
            }

            // Seven pellets' worth of password.
            ScriptAction {
                script: Lock.buffer = "12345"
            }

            PauseAnimation {
                duration: 1400
            }

            ScriptAction {
                script: {
                    Lock.state = "checking";
                    Lock.message = "CHECKING";
                }
            }

            PauseAnimation {
                duration: 1200
            }

            // Wrong. The ghost, the death, the board coming back — and the lane
            // itself is what calls Lock.recover() at the end of it.
            ScriptAction {
                script: {
                    Lock.buffer = "";
                    Lock.fail("TRY AGAIN");
                }
            }

            PauseAnimation {
                duration: 3600
            }

            ScriptAction {
                script: Lock.buffer = "123"
            }

            PauseAnimation {
                duration: 1200
            }

            // Through checking first, exactly as submit() does it. Skipping
            // straight to the answer clears the buffer while the lane is still
            // live, and the lane reads that as the tunnel.
            ScriptAction {
                script: {
                    Lock.state = "checking";
                    Lock.message = "CHECKING";
                }
            }

            PauseAnimation {
                duration: 900
            }

            // Right. The dash off the end of the lane, and then the face fading
            // out the way it does when the session is actually handed back.
            ScriptAction {
                script: {
                    Lock.buffer = "";
                    Lock.state = "won";
                    Lock.message = "LEVEL CLEARED";
                }
            }

            PauseAnimation {
                duration: 2600
            }

            ScriptAction {
                script: Qt.quit()
            }
        }
    }
}
