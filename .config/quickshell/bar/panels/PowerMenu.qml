pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/"
import "root:/components"

// The power menu, as a wheel.
//
// Built on exactly the mechanism the wallpaper picker turns on — one animated
// angle, everything derived from it, the list wrapped round the rim so there are
// no ends — and deliberately a fraction of the size. The picker is a gallery and
// its cards have to be big enough to judge a photograph by. This holds five
// glyphs, and a glyph is legible small, so the disk comes in until the whole
// thing sits in the right-hand corner of the screen instead of spanning it.
//
// Five actions and five visible positions is the pairing that makes it endless
// without ever repeating on screen: the wheel has no first or last item, you can
// turn past Shutdown into Lock forever, and because any run of five consecutive
// slots covers all five actions exactly once you never see two of the same disc.
// The picker cannot have that — a folder of three wallpapers on a rim that
// reaches six deep has to show you duplicates — which is why it says so and this
// does not.
Scope {
    id: menu

    // Kept alive briefly past the close so the fade can finish playing.
    property bool open: false
    property bool rendered: false

    // How far the wheel has been turned, in notches from wherever it started.
    // Unbounded on purpose: the wheel has no ends, so this runs on past Shutdown
    // and back before Lock, and anything that needs an actual action out of it
    // takes it modulo the five.
    property int index: 0

    readonly property int count: Power.count

    // The five wrapped onto the rim. Same reasoning as the picker's: the arc has
    // to be full at every position the eye can reach, or you turn into a gap.
    // Unlike the picker this never costs a visible duplicate — see the note at
    // the top about five and five.
    readonly property int copies: menu.count > 0 ? Math.max(1, Math.ceil((menu.reach * 2 + 2) / menu.count)) : 0
    readonly property int slots: menu.count * menu.copies

    readonly property real span: menu.slots * menu.step

    readonly property int slot: menu.slots > 0 ? ((menu.index % menu.slots) + menu.slots) % menu.slots : 0
    readonly property int action: menu.count > 0 ? menu.slot % menu.count : -1
    readonly property var focused: menu.action >= 0 ? Power.actions[menu.action] : null

    // The shortest way round, so clicking a disc on the rim turns the near way
    // rather than unwinding the whole wheel to arrive at the same place.
    function shortest(delta, whole) {
        if (whole <= 0)
            return 0;

        return delta - whole * Math.round(delta / whole);
    }

    function wrapAngle(degrees) {
        return menu.span > 0 ? menu.shortest(degrees, menu.span) : degrees;
    }

    // ─── the wheel ───────────────────────────────────────────────────

    readonly property int itemSize: Theme.powerItemSize
    readonly property int radius: Theme.powerRadius
    readonly property int centreInset: Theme.powerCentreInset

    // How big the disk under the discs is, derived rather than set.
    //
    // It has to reach past the *selected* disc, which is the largest thing the
    // wheel ever draws — powerFrontScale bigger than the rest — plus a margin of
    // visible rim outside it. Sizing the disk off the plain item size instead is
    // what had the chosen disc growing out through the edge of the very object
    // it is supposed to be mounted on.
    readonly property real diskRadius: menu.radius + menu.itemSize * Theme.powerFrontScale / 2 + Theme.powerDiskMargin
    readonly property real step: Theme.powerStep
    readonly property int reach: Theme.powerReach

    // Which way a disc tilts as it travels the rim. A circle has no orientation
    // to give away, so this only shows in the label riding with the selection —
    // but the disk under them turns on it, and that is what makes the five read
    // as mounted on one object rather than as five things moving in convoy.
    readonly property real tiltSign: -1

    // The one animated value in the component. Every disc's position, size and
    // fade comes off it, and so does the disk beneath them — which is the whole
    // reason the turn traces a circle instead of cutting the corner. Easing x and
    // y separately is what makes a wheel feel wrong; the picker's comment on this
    // is the long version.
    property real wheelAngle: menu.index * menu.step

    Behavior on wheelAngle {
        NumberAnimation {
            duration: Theme.wheelTurnDuration
            easing.type: Easing.OutBack
            easing.overshoot: 0.55
        }
    }

    // ─── opening and closing ─────────────────────────────────────────

    function show() {
        if (menu.open)
            return;

        // Always opens on Lock, however far the last visit turned. A power menu
        // that opens where you left it is one that opens on Shutdown the second
        // time, and the least destructive action is the right thing to have
        // under Enter when a menu appears.
        // Turns to whichever copy of Lock is nearest, so opening never unwinds
        // the wheel through the whole list to get back to the top of it.
        menu.index -= menu.shortest(menu.action, menu.count);

        unrender.stop();
        menu.rendered = true;
        menu.open = true;
    }

    function hide() {
        menu.open = false;
        unrender.restart();
    }

    function toggle() {
        if (menu.open)
            menu.hide();
        else
            menu.show();
    }

    Timer {
        id: unrender

        interval: Theme.menuUnrenderDelay
        repeat: false
        onTriggered: {
            if (!menu.open)
                menu.rendered = false;
        }
    }

    // ─── turning it ──────────────────────────────────────────────────

    function turn(delta) {
        menu.index += delta;
    }

    // ─── choosing one ────────────────────────────────────────────────

    // Closes first, then runs. The other way round leaves the wheel painted over
    // the top of whatever the action does — most visibly on Lock, where hyprlock
    // maps underneath a power menu that is still sitting there.
    function choose() {
        if (menu.action < 0)
            return;

        const chosen = menu.action;
        menu.hide();
        Power.run(chosen);
    }

    // ─── the surface ─────────────────────────────────────────────────

    PanelWindow {
        id: window

        visible: menu.rendered
        color: "transparent"

        // Reaches the top of the screen rather than starting below the bar. Only
        // the mode is set: assigning exclusiveZone at all puts the window back
        // into normal exclusion, zone or no zone.
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.namespace: "quickshell-power"
        WlrLayershell.layer: WlrLayer.Overlay

        // Exclusive while open. This one more than any of them: the keys turning
        // the wheel must not also be reaching the session you are about to end.
        WlrLayershell.keyboardFocus: menu.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        // Scrimmed and blurred, where the launcher is neither. The launcher is in
        // the way of what you were doing for a second; this is a decision, and the
        // work behind it going quiet while you make it is the correct amount of
        // ceremony for the two entries at the bottom of the wheel.
        Rectangle {
            anchors.fill: parent
            color: Theme.scrim
            opacity: menu.open ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: menu.open ? Theme.menuFadeIn : Theme.menuFadeOut
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: menu.hide()
            }
        }

        Item {
            id: stage

            anchors.fill: parent
            focus: true

            readonly property real centreX: width - menu.centreInset
            readonly property real centreY: height / 2

            opacity: menu.open ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: menu.open ? Theme.menuFadeIn : Theme.menuFadeOut
                    easing.type: Easing.OutCubic
                }
            }

            // One handler rather than the individual Keys.on*Pressed signals:
            // only some of the keys wanted here have one, and splitting the
            // navigation across two mechanisms hides half of it.
            //
            // No Home and no End, which the picker has. There is no first or last
            // action to jump to — that is what an endless wheel of five means —
            // and a key that silently did nothing would be worse than its absence.
            Keys.onPressed: event => {
                switch (event.key) {
                case Qt.Key_Escape:
                    menu.hide();
                    break;
                case Qt.Key_Up:
                case Qt.Key_Left:
                    menu.turn(-1);
                    break;
                case Qt.Key_Down:
                case Qt.Key_Right:
                    menu.turn(1);
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    menu.choose();
                    break;
                default:
                    return;
                }

                event.accepted = true;
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                property real accumulated: 0

                onWheel: event => {
                    // Touchpads deliver a stream of small deltas; collecting them
                    // into notch-sized steps stops one gesture spinning the wheel
                    // through the whole list.
                    accumulated += event.angleDelta.y + event.angleDelta.x;

                    while (accumulated >= 120) {
                        accumulated -= 120;
                        menu.turn(-1);
                    }
                    while (accumulated <= -120) {
                        accumulated += 120;
                        menu.turn(1);
                    }
                }
            }

            // ─── the disk ────────────────────────────────────────────
            //
            // Barely visible on purpose, exactly as on the picker. It only has to
            // imply that the discs are mounted on one turning object rather than
            // floating independently, and the screen edge crops it to the near
            // arc.

            Rectangle {
                x: stage.centreX - menu.diskRadius
                y: stage.centreY - menu.diskRadius

                width: menu.diskRadius * 2
                height: width

                radius: width / 2
                antialiasing: true

                color: Theme.diskFill
                border.width: 1
                border.color: Theme.diskEdge

                // Turns with the wheel, off the same animated angle the discs
                // use. Invisible on a plain circle, and the reason it is here
                // anyway is that the disk is not plain — it has an edge, and the
                // edge turning is what carries the sense of mass.
                rotation: menu.tiltSign * menu.wheelAngle
            }

            // ─── the five on it ──────────────────────────────────────

            Item {
                anchors.fill: parent

                // One delegate per slot on the rim, not per action: a slot is a
                // mounting point on the disk, and the five are wrapped round it
                // as many times as it takes to fill the arc.
                Repeater {
                    model: menu.slots

                    delegate: Disc {
                        required property int index

                        ordinal: index
                    }
                }
            }

            // ─── what you are about to do ────────────────────────────
            //
            // Rides with the selection rather than sitting in a corner: it is a
            // caption on the disc at the selection point, and the eye is already
            // there. Left of the wheel, where the arc has curved away and there
            // is nothing to collide with.

            Item {
                id: caption

                // Measured off the edge of the disk rather than off the orbit the
                // discs ride on, so it stays clear of the rim however the wheel
                // is tuned — the two are no longer the same distance.
                x: stage.centreX - menu.diskRadius - width - 24
                y: stage.centreY - height / 2

                width: label.implicitWidth
                height: label.implicitHeight + detail.implicitHeight + 4

                PanelText {
                    id: label

                    anchors.right: parent.right
                    text: menu.focused ? menu.focused.title : ""
                    font.pixelSize: 26
                    font.weight: Font.DemiBold
                    color: menu.focused && menu.focused.heavy ? Theme.urgent : Theme.text
                }

                PanelText {
                    id: detail

                    anchors.right: parent.right
                    anchors.top: label.bottom
                    anchors.topMargin: 4
                    text: menu.focused ? menu.focused.detail : ""
                    font.pixelSize: 12
                    color: Theme.muted
                }
            }
        }
    }

    // ─── one action on the rim ───────────────────────────────────────

    component Disc: Item {
        id: disc

        required property int ordinal

        readonly property var action: Power.actions[disc.ordinal % menu.count]

        // Where this disc sits on the rim right now, in degrees from the
        // selection point. Derived from the wheel's animated angle rather than
        // from the index, so it is already smooth — nothing below needs a
        // Behavior of its own and nothing can drift out of step, because it is
        // all one number.
        //
        // Wrapped to the near half of the disk, which is what turns the arc into
        // an endless belt: a disc that has travelled past the far side is
        // described as coming round the other way instead. The swap happens half
        // a turn away, behind the right edge, so nothing is ever seen jumping.
        readonly property real angle: menu.wrapAngle(disc.ordinal * menu.step - menu.wheelAngle)
        readonly property real radians: disc.angle * Math.PI / 180
        readonly property real notches: Math.abs(disc.angle) / menu.step

        readonly property bool front: disc.ordinal === menu.slot

        visible: disc.notches <= menu.reach

        width: menu.itemSize
        height: menu.itemSize

        // Swung round the disk. The selection point is the leftmost point of the
        // circle, so a disc at zero notches sits square in the middle of the free
        // edge and the others curve away above and below it.
        x: stage.centreX - menu.radius * Math.cos(disc.radians) - width / 2
        y: stage.centreY + menu.radius * Math.sin(disc.radians) - height / 2

        // Continuous in the angle rather than switched on the index, so a disc
        // grows as it arrives at the selection point instead of popping the
        // moment the selection changes under it.
        scale: Theme.powerRimScale + (Theme.powerFrontScale - Theme.powerRimScale) * Math.max(0, 1 - disc.notches)

        opacity: {
            const rim = menu.reach + 0.5;
            if (disc.notches > rim)
                return 0;

            // Falls away much harder than the picker's cards do. There, every
            // card on the rim is a wallpaper you are still judging; here there is
            // exactly one action you are choosing and the other four are context.
            return Math.max(0, Math.min(1, (rim - disc.notches))) * Math.max(0.35, 1 - disc.notches * 0.3);
        }

        z: 100 - disc.notches

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            antialiasing: true

            color: disc.front ? (disc.action.heavy ? Theme.urgentSoft : Theme.powerSelection) : Theme.powerRest

            border.width: disc.front ? 2 : 1
            border.color: disc.front ? (disc.action.heavy ? Theme.urgent : Theme.powerSelectionEdge) : Theme.powerRestEdge

            Behavior on color {
                ColorAnimation {
                    duration: Theme.hoverDuration
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.hoverDuration
                    easing.type: Easing.OutCubic
                }
            }

            Glyph {
                anchors.centerIn: parent
                text: disc.action.glyph

                // Fixed rather than scaled with the disc: the disc's own scale
                // already grows the glyph with it, and sizing the text as well
                // would compound the two and resample the glyph every frame of
                // the turn.
                font.pixelSize: 24
                color: disc.front && disc.action.heavy ? Theme.urgent : Theme.text
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            // A disc on the rim is a target to turn to; the one at the selection
            // point is the choice itself. One click does whichever the disc is
            // for — so nothing on this wheel is ever one stray click from a
            // shutdown, because reaching Shutdown always takes a click to turn
            // to it and a second to mean it.
            onClicked: {
                if (disc.front)
                    menu.choose();
                else
                    menu.index += menu.shortest(disc.ordinal - menu.slot, menu.slots);
            }
        }
    }
}
