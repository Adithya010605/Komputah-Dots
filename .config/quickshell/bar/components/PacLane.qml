pragma ComponentBehavior: Bound

import QtQuick
import "root:/"
import "root:/components"

// The password field.
//
// There is no field. What you have typed is how far along the row Pac-Man has
// got: one pellet per character, eaten left to right, put back one at a time by
// backspace. It says exactly what a row of dots says and nothing more — how many
// characters are in there — and it says it in the one way that makes a lock
// screen worth looking at twice.
//
// He starts before the first pellet rather than on it, so a lane of six pellets
// has seven positions and the sixth character lands him on the last one. The
// spare slot at the start is what stops a password of exactly the lane's length
// wrapping round to an untouched-looking board at the moment it is finished.
//
// The row is finite and typing does not stop at the end of it. Running off the
// right edge wraps back to the left with the board refilled, which is the
// arcade's own answer to the same problem: the tunnel. A password longer than
// the lane is a second lap, and nothing about the count is lost — the lane shows
// the remainder and the laps are simply not drawn, the same way a row of dots
// that has run out of room shows you the last twenty.
//
// Three things happen here that are not typing, and each is a sequence rather
// than a state: the ghost coming for him when the password is wrong, the dash
// off the right-hand edge when it is right, and the refill after either. They
// are written as animations rather than as timers so that each step runs when
// the one before it has actually finished.
Item {
    id: lane

    // How many characters are in the buffer. Not the password, not a hash of
    // it, not anything derived from its contents — the length, which is the only
    // thing on this screen that knows anything about it at all.
    property int typed: 0

    // waiting → checking → failed | won. Owned by Lock and handed down.
    property string phase: "waiting"

    property int capacity: Theme.lockCapacity
    property int step: Theme.lockLaneStep

    // Raised when the failure sequence has finished putting the board back, so
    // the screen knows when it is safe to accept typing again.
    signal cleared

    // Raised at the end of the winning dash, which is what actually releases
    // the session — the lock is held open until the animation has been seen.
    signal finished

    // Position 0 is where he waits with nothing typed and there is no pellet on
    // it. Every character after that is a pellet, so the last one is reached
    // rather than skipped past.
    readonly property int slot: {
        if (lane.capacity <= 0 || lane.typed === 0)
            return 0;

        return ((lane.typed - 1) % lane.capacity) + 1;
    }

    readonly property int pacWidth: Arcade.pacSize * Theme.lockPacPixel

    readonly property int ghostWidth: {
        if (Arcade.ghostFrames.length === 0)
            return 0;

        return Arcade.ghostFrames[0][0].length * Theme.lockPacPixel;
    }

    // Where he is, measured in slots and allowed to be between two of them.
    // Every other moving part reads this: which pellets are gone, which way he
    // is facing, where the ghost is heading.
    property real position: 0

    // True for exactly the assignment that crosses the tunnel, so the Behavior
    // below lets that one jump rather than sliding him back across the whole
    // lane at typing speed.
    property bool warping: false

    property int facing: 1

    property bool chasing: false
    property real ghostX: 0
    property real ghostFade: 1

    // How far apart the two stand at the moment he is caught, centre to centre:
    // half of each of them, plus a cell of daylight. Landing on the same spot
    // hid the whole death behind a ghost.
    readonly property real ghostGap: lane.pacWidth / 2 + lane.ghostWidth / 2 + Theme.lockPacPixel

    // Which side it comes from, which is a question because the lane is short.
    // From the right while there is room to stand there — that is the unfinished
    // end, and something arriving out of it reads as coming *for* him. With him
    // at or near the last pellet there is no such room, and rather than have it
    // stop off the end of the lane where it cannot be seen, it comes up behind
    // instead. Which is how a ghost catches Pac-Man anyway.
    readonly property bool ghostFromRight: lane.centreOf(lane.position) + lane.ghostGap + lane.ghostWidth / 2 <= lane.width

    // Both in the Loader's own terms, which is its left edge rather than its
    // middle.
    readonly property real ghostEntry: lane.ghostFromRight ? lane.width : -lane.ghostWidth
    readonly property real ghostRest: lane.centreOf(lane.position) + (lane.ghostFromRight ? lane.ghostGap : -lane.ghostGap) - lane.ghostWidth / 2

    implicitWidth: lane.pacWidth + lane.step * lane.capacity
    implicitHeight: Arcade.pacSize * Theme.lockPacPixel

    // Measured from the middle of him at rest rather than from the edge of the
    // lane, so half a sprite always fits on either end and neither the first
    // position nor the last is clipped.
    function centreOf(slot: real): real {
        return lane.pacWidth / 2 + lane.step * slot;
    }

    // Kept so a change in `slot` can be told apart from a wrap: one step in
    // either direction is a keystroke, anything further is the tunnel.
    property int previousSlot: 0

    onSlotChanged: {
        const delta = lane.slot - lane.previousSlot;
        lane.previousSlot = lane.slot;

        if (delta === 0)
            return;

        lane.facing = delta > 0 ? 1 : -1;

        // Set around the assignment rather than before it, so the Behavior sees
        // the flag on the one write that has to skip it and nothing else does.
        if (Math.abs(delta) > 1) {
            lane.warping = true;
            lane.position = lane.slot;
            lane.warping = false;
            lane.facing = 1;
            refill.restart();
            return;
        }

        lane.position = lane.slot;
    }

    Behavior on position {
        enabled: !lane.warping

        NumberAnimation {
            duration: Theme.lockStepDuration
            easing.type: Easing.OutCubic
        }
    }

    // ─── the board ───────────────────────────────────────────────────

    // Under the board rather than over it, and a whisper. It is the light coming
    // up behind a new set of pellets, not a flashbulb — over the top and at
    // anything like full strength it takes the colour out of every sprite on
    // the lane for half a second.
    Rectangle {
        id: flash

        anchors.fill: parent
        radius: height / 2
        color: Theme.pacSelf
        opacity: 0
        visible: opacity > 0
    }

    Item {
        id: track

        anchors.fill: parent
        clip: true

        Repeater {
            // One more than there are pellets, because position zero is a
            // position he can stand on and not a pellet he can eat. The delegate
            // for it draws nothing.
            model: lane.capacity + 1

            Item {
                id: slot

                required property int index

                // Nothing sits where he starts.
                readonly property bool present: slot.index > 0

                // The last one, which makes the far end of the lane a thing to
                // get to rather than just where the row stops. On a lane this
                // short it is the only one — a second big pellet two slots
                // before it would be crowding rather than pacing.
                readonly property bool power: slot.index === lane.capacity

                // Just before he arrives rather than exactly when: a pellet that
                // vanishes on contact reads as him passing over it, and one that
                // vanishes a breath early reads as him taking it in.
                readonly property bool eaten: slot.index <= lane.position + 0.4

                x: lane.centreOf(slot.index) - width / 2
                y: (track.height - height) / 2
                width: Theme.lockPowerPellet
                height: width

                visible: slot.present
                opacity: slot.eaten ? 0 : 1
                scale: slot.eaten ? 0.25 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.lockPelletFade
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.lockPelletFade
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.4
                    }
                }

                Rectangle {
                    id: dot

                    anchors.centerIn: parent

                    width: slot.power ? Theme.lockPowerPellet : Theme.lockPellet
                    height: width

                    // Square, and not by omission. A pellet was a square on the
                    // board this is quoting, and rounding it off here would be
                    // the one place in the sprite work where the grid was
                    // quietly abandoned.
                    radius: 0
                    antialiasing: false

                    color: slot.power ? Theme.pacPower : Theme.pacPellet

                    // The big ones breathe. Eased rather than blinked: the
                    // arcade strobed them because it had two frames to spend,
                    // and a hard strobe next to this much glass reads as a
                    // fault rather than as a fixture.
                    SequentialAnimation on opacity {
                        running: slot.power
                        loops: Animation.Infinite

                        NumberAnimation {
                            to: 0.35
                            duration: Theme.lockPowerPulse
                            easing.type: Easing.InOutQuad
                        }

                        NumberAnimation {
                            to: 1
                            duration: Theme.lockPowerPulse
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
            }
        }

        // ─── him ─────────────────────────────────────────────────────

        PacMan {
            id: pac

            x: lane.centreOf(lane.position) - width / 2
            y: (track.height - height) / 2

            facing: lane.facing

            // Still while the board is being checked — he has eaten everything
            // he was given and is waiting to hear, and a jaw still working
            // through that would read as him being unaware of it.
            chomping: lane.phase !== "checking"

            onDied: {
                // Nothing here: the failure sequence below is what decides what
                // happens next, and it is already waiting on the same duration.
            }
        }

        // ─── it ──────────────────────────────────────────────────────

        Loader {
            id: ghost

            active: lane.chasing
            asynchronous: false

            opacity: lane.ghostFade
            x: lane.ghostX
            y: (track.height - height) / 2

            sourceComponent: PixelSprite {
                id: sprite

                property int frame: 0

                // Its eyes are drawn looking left, so coming from the left it is
                // mirrored — a ghost chasing him with its back to him is the one
                // detail that would make the whole sprite read as a decoration.
                bitmap: lane.ghostFromRight ? Arcade.ghostFrames[sprite.frame] : Arcade.mirror(Arcade.ghostFrames[sprite.frame])
                pixel: Theme.lockPacPixel

                palette: ({
                        "#": Theme.ghostBody,
                        "o": Theme.ghostEye,
                        "*": Theme.ghostPupil
                    })

                // Its hem, and nothing else, on the same counter Pac-Man's jaw
                // runs on. A ghost does not walk; its skirt does.
                Timer {
                    running: true
                    interval: Theme.lockChompInterval * 1.5
                    repeat: true

                    onTriggered: sprite.frame = (sprite.frame + 1) % Arcade.ghostFrames.length
                }
            }
        }
    }

    // ─── being caught ────────────────────────────────────────────────
    //
    // Rushes in from off the right-hand edge, stops beside him, and goes out as
    // he does. Then the board is put back — which is also what tells the screen
    // it can be typed into again.

    SequentialAnimation {
        id: caught

        PropertyAction {
            target: lane
            property: "chasing"
            value: true
        }

        PropertyAction {
            target: lane
            property: "ghostFade"
            value: 1
        }

        // In from whichever end has room for it, and stopping a body's width
        // short of him. Both ends are worked out above.
        NumberAnimation {
            target: lane
            property: "ghostX"
            from: lane.ghostEntry
            to: lane.ghostRest
            duration: Theme.lockGhostRush
            easing.type: Easing.OutCubic
        }

        PauseAnimation {
            duration: Theme.lockGhostHold
        }

        // Caught. It goes out as he does — the board cleared the ghosts off the
        // screen for the death too, and for the same reason.
        ParallelAnimation {
            ScriptAction {
                script: pac.die()
            }

            NumberAnimation {
                target: lane
                property: "ghostFade"
                to: 0
                duration: Theme.lockGhostLeave
                easing.type: Easing.InCubic
            }
        }

        PauseAnimation {
            duration: Theme.lockDeathDuration - Theme.lockGhostLeave
        }

        PropertyAction {
            target: lane
            property: "chasing"
            value: false
        }

        ScriptAction {
            script: {
                lane.warping = true;
                lane.position = 0;
                lane.previousSlot = 0;
                lane.warping = false;
                lane.facing = 1;
                pac.revive();
                lane.cleared();
            }
        }
    }

    // ─── getting through ─────────────────────────────────────────────
    //
    // Straight off the end of the lane, eating everything still on it, because
    // the pellets are eaten by where he is and he is about to be past all of
    // them. One animation, and the board clears itself.

    SequentialAnimation {
        id: getaway

        NumberAnimation {
            target: lane
            property: "position"
            to: lane.capacity + 2
            duration: Theme.lockWinDash
            easing.type: Easing.InCubic
        }

        ScriptAction {
            script: lane.finished()
        }
    }

    // A new board. Only ever seen at the tunnel, and deliberately slight — the
    // pellets coming back are doing the talking, and this is the light going up
    // behind them.
    SequentialAnimation {
        id: refill

        NumberAnimation {
            target: flash
            property: "opacity"
            to: 0.10
            duration: 90
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: flash
            property: "opacity"
            to: 0
            duration: 420
            easing.type: Easing.InOutQuad
        }
    }

    onPhaseChanged: {
        if (lane.phase === "failed") {
            getaway.stop();
            caught.restart();
        } else if (lane.phase === "won") {
            caught.stop();
            lane.facing = 1;
            getaway.restart();
        }
    }
}
