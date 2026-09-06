pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import "root:/"
import "root:/components"

// Everything the lock screen draws, and nothing about how it is held on screen.
//
// Split from LockScreen.qml because the session lock is one thing — a protocol
// object with a surface per display — and the face is another, and only one of
// the two can be looked at without locking the machine to look at it. This is
// the half that can: point a plain window at it and the whole screen is there,
// which is how it was built and how it gets changed.
//
// The composition is the shell's own glass with 8-bit content set on it: a
// bitmap clock, a bitmap caption, and a row of pellets standing in for the
// password field. The mix is the point. Pixel art on its own is a costume; pixel
// art on a frosted pane with a soft shadow under it and a weighted settle on the
// way in is the shell wearing it.
//
// Nothing in here knows the password. The lane is handed a count and a state
// word, both from Lock, and the buffer never leaves that singleton.
Item {
    id: face

    // Whether this face is the one being typed into. False in the preview, and
    // false on every display but the one the compositor hands the keyboard to.
    property bool live: true

    // Set a tick after the item exists rather than bound to Lock.locked, which
    // is already true by the time any of this is built: the arrival needs one
    // frame in the unarrived state to animate out of.
    property bool arrived: false

    Component.onCompleted: entrance.restart()

    Timer {
        id: entrance

        interval: 1
        repeat: false

        onTriggered: {
            face.arrived = true;

            if (face.live)
                field.forceActiveFocus();
        }
    }

    // ─── keeping the keyboard ────────────────────────────────────────
    //
    // Focus is taken once on the way in, above, and that is not enough to keep
    // it. The screen blanks ten minutes after it locks and the machine suspends
    // twenty minutes after that, and both of those take the surface down and
    // put a new one up on the way back: Hyprland drops the lock surface for an
    // output it has turned off, and what returns when the display comes back is
    // a fresh window that the field in the old one had the focus of. The face
    // looks exactly right — wallpaper, clock, capsule, all of it — and every
    // keystroke goes nowhere, which from the outside is a lock screen that has
    // stopped accepting the password and can only be escaped from a TTY.
    //
    // So focus is checked rather than assumed, for as long as this face is the
    // live one. It is one boolean read twice a second against a state that
    // changes maybe twice a day; the cost of the poll is nothing next to the
    // cost of the case it covers.
    //
    // Started only once the entrance above has had its go at the field, so the
    // one thing this can ever react to is focus that was taken and then lost —
    // which is what makes the line it logs worth reading. A lock screen that
    // has quietly stopped accepting keys leaves nothing behind to look at
    // afterwards; this leaves `quickshell -c bar log`.
    Timer {
        id: keyboard

        running: face.live && face.arrived
        interval: 500
        repeat: true

        onTriggered: {
            if (field.activeFocus)
                return;

            console.log("lock: field lost focus, taking it back");
            field.forceActiveFocus();
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // ─── the wallpaper, frosted ──────────────────────────────────────
    //
    // Every other surface in the shell borrows its blur from Hyprland — there is
    // a layer rule per namespace in hyprland.lua doing it — and none of that
    // reaches a lock surface, because there is nothing behind one to blur. So
    // the wallpaper is drawn here and frosted here, and the card sits on the
    // result exactly the way the panels sit on the blurred desktop.

    // What is behind the glass. Bound to the live wallpaper and left settable so
    // LockPreview can point it at something else — the shell's own wallpaper is
    // a poor test of a frosted surface on the day it happens to be black.
    property string wallpaper: Wallpapers.current

    // Holds the overscan in. The picture below is deliberately bigger than the
    // screen, so that the edge of the blur — which fades out, having nothing
    // beyond the texture to sample — falls outside the display instead of
    // drawing a dark frame around it.
    Item {
        anchors.fill: parent
        clip: true

        Image {
            id: paper

            // Drawn small and blown back up, which is the whole of the blur.
            // See Theme.lockBlurBase: MultiEffect's radius is in the pixels of
            // the texture it is given, so the only way to reach compositor
            // depth is to hand it a small one. At this size the picture is
            // three hundred-odd pixels of colour, and the radius below is a
            // real fraction of that rather than a rounding error on it.
            readonly property real factor: parent.width * Theme.lockBlurOverscan / Theme.lockBlurBase

            width: Theme.lockBlurBase
            height: parent.height * Theme.lockBlurOverscan / paper.factor

            transformOrigin: Item.TopLeft
            scale: paper.factor

            // Centred by hand: transformOrigin is the top left, so the item
            // scales away from that corner and the overscan all lands bottom
            // right unless the surplus is split.
            x: -(paper.width * paper.factor - parent.width) / 2 / paper.factor
            y: -(paper.height * paper.factor - parent.height) / 2 / paper.factor

            source: face.wallpaper.length > 0 ? "file://" + face.wallpaper : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: Theme.lockBlurBase
            cache: true
            asynchronous: false
            smooth: true

            // Blurred by the item's own layer rather than by a MultiEffect
            // reading it as a source. Same result, one fewer item, and no
            // question about whether a hidden source is still being drawn into
            // a texture — the layer is the texture. It is also the texture the
            // scale above magnifies, so the blur happens once, small, and what
            // is stretched to the display is the finished thing.
            layer.enabled: true

            layer.effect: MultiEffect {
                blurEnabled: true
                blur: Theme.lockBlur
                blurMax: Theme.lockBlurMax
                brightness: Theme.lockDim
                saturation: Theme.lockDesaturate
            }
        }
    }

    // On top of the blur rather than folded into its brightness, so the two can
    // be tuned against each other: the blur decides how much of the wallpaper
    // survives and this decides how dark the result is under white text.
    Rectangle {
        anchors.fill: parent
        color: Theme.lockScrim
    }

    // ─── what is on it ───────────────────────────────────────────────

    Item {
        id: stage

        anchors.fill: parent

        opacity: face.arrived ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: face.arrived ? Theme.lockFadeIn : Theme.lockFadeOut
                easing.type: Easing.OutCubic
            }
        }

        // Two blocks, not one column. A lock screen is a clock you look at and a
        // box you type into, and stacking those in the middle of the screen
        // makes one object out of two jobs — the clock ends up as a label on the
        // password field. Apart, the clock owns the screen and the bar owns the
        // bottom edge, which is where the eye already is when you sit down and
        // where hyprlock's input field was.

        Column {
            id: face_clock

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: Theme.lockClockOffset

            spacing: 0

            // Translated rather than moved, so the arrival does not fight the
            // anchors holding it in the middle.
            transform: Translate {
                y: face.arrived ? 0 : Theme.lockRiseDistance

                Behavior on y {
                    NumberAnimation {
                        duration: Theme.lockRise
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.8
                    }
                }
            }

            PixelText {
                anchors.horizontalCenter: parent.horizontalCenter

                text: Qt.formatDateTime(clock.date, "HH:mm")
                pixel: Theme.lockClockPixel
                tracking: 1
                color: Theme.text

                // The one line on screen that changes on its own, so it is the
                // one line that flashes the glyph that changed.
                animated: true
            }

            Item {
                width: 1
                height: 30
            }

            PixelText {
                anchors.horizontalCenter: parent.horizontalCenter

                text: Qt.formatDateTime(clock.date, "dddd dd MMMM")
                pixel: Theme.lockDatePixel
                tracking: 2
                color: Theme.muted
            }
        }

        // ─── the board, at the bottom ────────────────────────────────

        Column {
            id: entry

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.lockBottomMargin

            spacing: 0

            // Further than the clock travels, and from below rather than from
            // nowhere: it comes up out of the edge it is sitting on.
            transform: Translate {
                y: face.arrived ? 0 : Theme.lockRiseDistance * 2

                Behavior on y {
                    NumberAnimation {
                        duration: Theme.lockRise
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.8
                    }
                }
            }

            Item {
                id: card

                anchors.horizontalCenter: parent.horizontalCenter

                width: Theme.lockCardWidth
                height: Theme.lockCardHeight

                Rectangle {
                    id: glass

                    anchors.fill: parent

                    // A capsule rather than a rounded rectangle, which is what
                    // the bar at the top of the desktop is too. At this size the
                    // panel radius would leave four short straight runs of edge
                    // and read as a small box; taken all the way round it reads
                    // as one object, and as the same object the shell already
                    // has one of.
                    radius: height / 2
                    antialiasing: true

                    color: Theme.lockGlass
                    border.width: 1
                    border.color: Theme.lockGlassBorder

                    GlassSheen {}

                    // The one surface in the shell that casts a real shadow,
                    // because it is the one surface the shell draws the ground
                    // under. Everywhere else the pane is lifted off the desktop
                    // by the compositor's blur; here there is no compositor in
                    // the way, so the depth has to be drawn.
                    layer.enabled: true

                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: "black"
                        shadowOpacity: 0.42
                        shadowBlur: 1
                        shadowVerticalOffset: 10
                        autoPaddingEnabled: true
                    }
                }

                // Outside the glass rather than inside it, so the layer above
                // casts one shadow from one capsule. In there, every pellet
                // would be casting its own.
                PacLane {
                    id: lane

                    anchors.centerIn: parent
                    width: Theme.lockLaneWidth

                    typed: Lock.count
                    phase: Lock.state

                    onCleared: Lock.recover()
                    onFinished: leave.restart()
                }
            }

            Item {
                width: 1
                height: 14
            }

            // ─── what it says ────────────────────────────────────────

            PixelText {
                id: caption

                anchors.horizontalCenter: parent.horizontalCenter

                // Held while it fades, so a message goes quiet before it is
                // replaced rather than being swapped out from under itself.
                // Assigned in the sequence below, which is what breaks the
                // binding — deliberately, and the same way the launcher's
                // caption does it.
                property string shown: Lock.message

                text: caption.shown
                pixel: Theme.lockCaptionPixel
                tracking: 1

                color: {
                    if (Lock.state === "failed")
                        return Theme.urgent;
                    if (Lock.state === "won")
                        return Theme.accent;

                    return Theme.muted;
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.hoverDuration
                    }
                }

                Connections {
                    target: Lock

                    function onMessageChanged() {
                        swap.restart();
                    }
                }

                SequentialAnimation {
                    id: swap

                    NumberAnimation {
                        target: caption
                        property: "opacity"
                        to: 0
                        duration: 110
                        easing.type: Easing.OutCubic
                    }

                    ScriptAction {
                        script: caption.shown = Lock.message
                    }

                    NumberAnimation {
                        target: caption
                        property: "opacity"
                        to: 1
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Item {
                width: 1
                height: 12
            }

            // ─── how many are left ───────────────────────────────────
            //
            // The arcade's own way of saying how it is going, and the only
            // reason the count exists: nothing is gated on it. A lock screen
            // that stops accepting the right password after three wrong ones is
            // a lock screen that has locked out the person it is for.

            Row {
                anchors.horizontalCenter: parent.horizontalCenter

                spacing: Theme.lockLivesPixel * 4

                Repeater {
                    model: Lock.maxLives

                    PixelSprite {
                        id: life

                        required property int index

                        // The wide-open frame, which is the one the cabinet used
                        // for the little ones in the corner — a closed circle
                        // down there reads as a dot rather than as him.
                        bitmap: Arcade.pacRight.length > 3 ? Arcade.pacRight[3] : []
                        pixel: Theme.lockLivesPixel
                        color: Theme.pacSelf

                        opacity: life.index < Lock.lives ? 1 : 0.15

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 260
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }

        // ─── the corner ──────────────────────────────────────────────
        //
        // Out of the composition on purpose. It is the one thing here that is
        // read rather than looked at, and the middle of the screen is spoken
        // for.

        PixelText {
            readonly property var battery: UPower.displayDevice

            readonly property int percent: {
                if (!battery || !battery.isPresent)
                    return 0;

                const raw = battery.percentage;
                return Math.round(raw <= 1 ? raw * 100 : raw);
            }

            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: 34
            anchors.bottomMargin: 28

            visible: battery && battery.isPresent

            text: (battery && battery.state === UPowerDeviceState.Charging ? "CHG " : "BAT ") + percent + "%"
            pixel: Theme.lockLivesPixel
            tracking: 2
            color: Theme.muted
        }
    }

    // ─── the keyboard ────────────────────────────────────────────────
    //
    // A real text field, drawn nowhere. Reading raw key events instead would
    // mean reimplementing shift, AltGr, dead keys and every compose sequence, on
    // the one input in the shell that has to accept exactly what was meant — and
    // it would still get a password with a ü in it wrong.
    //
    // NoEcho rather than a password mask: there is nothing on screen to draw a
    // mask in. The pellets are the only feedback, and they come from a count.

    // The wake itself, which is a moved mouse or a touched pad rather than a
    // key: whatever brings the display back gets the field back at the same
    // time, so the first keystroke after it lands rather than the second. The
    // poll above would get there within half a second anyway — this is only so
    // that half second is never spent typing into nothing.
    //
    // Nothing else on this screen is clickable, so there is nothing under it
    // this can be taking events away from.
    MouseArea {
        anchors.fill: parent

        enabled: face.live
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true

        onPositionChanged: field.forceActiveFocus()
        onPressed: field.forceActiveFocus()
    }

    TextInput {
        id: field

        width: 0
        height: 0
        opacity: 0

        focus: face.live
        echoMode: TextInput.NoEcho
        activeFocusOnPress: false
        selectByMouse: false

        // Locked out for exactly as long as the screen is busy saying something
        // about the last attempt. Typing into a ghost's approach would leave
        // pellets being eaten by a Pac-Man in the middle of dying.
        readOnly: !face.live || Lock.state !== "waiting"

        onTextChanged: {
            if (face.live && Lock.state === "waiting")
                Lock.buffer = field.text;
        }

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Return:
            case Qt.Key_Enter:
                Lock.submit();
                break;
            case Qt.Key_Escape:
                field.text = "";
                break;
            // The readline clear, for hands already there.
            case Qt.Key_U:
                if (!(event.modifiers & Qt.ControlModifier))
                    return;

                field.text = "";
                break;
            default:
                return;
            }

            event.accepted = true;
        }

        // Lock empties the buffer the moment PAM answers, and the field is what
        // has to be emptied with it — it is the only thing in the process still
        // holding the characters at that point.
        Connections {
            target: Lock

            function onBufferChanged() {
                if (Lock.buffer.length === 0)
                    field.text = "";
            }
        }
    }

    // ─── letting go ──────────────────────────────────────────────────
    //
    // The session is released here and nowhere else, a beat after the dash has
    // taken him off the end of the lane. PAM said yes some seconds of animation
    // ago; this is the screen agreeing.

    SequentialAnimation {
        id: leave

        PauseAnimation {
            duration: Theme.lockReleaseDelay
        }

        ScriptAction {
            script: face.arrived = false
        }

        PauseAnimation {
            duration: Theme.lockFadeOut
        }

        ScriptAction {
            script: Lock.release()
        }
    }
}
