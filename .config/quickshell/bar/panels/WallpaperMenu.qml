pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "root:/"
import "root:/components"

// The wallpaper picker.
//
// Deliberately not a DripPanel: the drip is the bar's idiom, for surfaces that
// belong to a module you clicked. This one has no module and no anchor — it is
// summoned by a keybind and takes over the screen.
//
// The wallpapers are mounted on a disk whose centre sits off the right edge, so
// only the near arc of it is on screen. Turning the wheel brings the next one
// round to the selection point. Nothing is stacked behind anything: every card
// on the arc is in the foreground and legible, and the one you are choosing is
// simply the one that has come round to the front and grown.
//
// Nothing here blurs or hides the desktop. What is behind the wheel is the
// wallpaper you are currently on, which is the one thing worth comparing
// against — the picker sits on it rather than over it.
Scope {
    id: menu

    // Kept alive briefly past the close so the retract can finish playing.
    property bool open: false
    property bool rendered: false

    // How far the wheel has been turned, counted in notches from wherever it
    // started. Deliberately unbounded: the wheel has no ends, so this runs on
    // past the last wallpaper and back before the first, and everything that
    // needs a file out of it takes it modulo the folder.
    property int index: 0

    readonly property int count: Wallpapers.files.length

    // The folder wrapped onto the rim. With few enough wallpapers the arc
    // would not fill — you would turn into a gap and out the other side — so
    // the list is repeated round the disk until there is always a card at
    // every position the eye can reach. Seeing the same wallpaper twice on a
    // small folder is the honest consequence of a wheel that never ends.
    readonly property int copies: menu.count > 0 ? Math.max(1, Math.ceil((menu.reach * 2 + 2) / menu.count)) : 0
    readonly property int slots: menu.count * menu.copies

    // A full turn, in degrees. Half of it is the furthest any card ever gets
    // from the selection point before it is cheaper to say it is coming round
    // the other side instead.
    readonly property real span: menu.slots * menu.step

    // Which slot has come round to the selection point, and which wallpaper
    // that is. Not the applied one — that is Wallpapers.current, and the two
    // are only equal until you start turning the wheel.
    readonly property int slot: menu.slots > 0 ? ((menu.index % menu.slots) + menu.slots) % menu.slots : 0
    readonly property int file: menu.count > 0 ? menu.slot % menu.count : -1
    readonly property string focused: menu.file >= 0 ? Wallpapers.files[menu.file] : ""

    // The shortest way round. Everything that jumps the wheel somewhere
    // absolute — opening on the live wallpaper, clicking a card on the rim —
    // goes through one of these, so it turns the near way rather than
    // unwinding the whole folder to arrive at the same place.
    function shortest(delta, whole) {
        if (whole <= 0)
            return 0;

        return delta - whole * Math.round(delta / whole);
    }

    function wrapAngle(degrees) {
        return menu.span > 0 ? menu.shortest(degrees, menu.span) : degrees;
    }

    // ─── the wheel ───────────────────────────────────────────────────

    readonly property int cardWidth: 260
    readonly property int cardHeight: Math.round(cardWidth * 9 / 16)

    // How big the disk is, and how far its centre sits in from the right edge
    // of the screen. Kept tight on purpose: a large radius flattens the arc
    // into a near-vertical column running the full height of the display,
    // which spreads the wallpapers so far apart they stop reading as one
    // wheel. A small disk curls them back in around the selection point and
    // keeps the whole thing clear of the screen edges.
    readonly property int radius: 300
    readonly property int centreInset: 40

    // Degrees between one wallpaper and the next.
    readonly property real step: 16

    // Past this the cards have curled away round the back of the disk, so they
    // are not drawn. Sized so the far ones still land inside the right edge
    // rather than being sliced off by it.
    readonly property int reach: 4

    // Which way a card tilts as it travels round the rim. Mounted radially, so
    // a card below the selection point leans the way the disk is turning.
    readonly property real tiltSign: -1

    // How far the wheel has turned, in degrees. This is the one animated value
    // in the whole component: every card's position, tilt, size and fade is
    // derived from it, and so is the disk under them.
    //
    // Animating each card's x and y separately — which is the obvious way to
    // do it — is what made the turn feel wrong. Two independent springs on two
    // axes do not trace a circle: the card cuts the corner across the inside
    // of the arc and the overshoot throws it off the rim entirely. Easing the
    // angle instead means everything travels exactly along the circle, and the
    // cards and the disk stay locked together because they are the same
    // number.
    property real wheelAngle: menu.index * menu.step

    Behavior on wheelAngle {
        NumberAnimation {
            duration: Theme.wheelTurnDuration
            easing.type: Easing.OutBack
            easing.overshoot: 0.55
        }
    }

    // ─── opening ─────────────────────────────────────────────────────

    // Always opens on what is actually on the desktop, however far the last
    // visit turned the wheel from it.
    function goTo(fileIndex) {
        if (menu.count === 0 || fileIndex < 0)
            return;

        // The same wallpaper sits at several slots on a repeated wheel; this
        // turns to whichever copy of it is nearest.
        menu.index += menu.shortest(fileIndex - menu.file, menu.count);
    }

    function syncToLive() {
        const live = Wallpapers.files.indexOf(Wallpapers.current);
        menu.goTo(live >= 0 ? live : 0);
    }

    function show() {
        if (menu.open)
            return;

        Wallpapers.refresh();
        menu.syncToLive();

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

    // The rescan is asynchronous, so on the first open of a session the list
    // can still be arriving when show() reads it. Landing on the live
    // wallpaper matters more than holding position through a rescan, and the
    // list only changes when the folder does.
    Connections {
        target: Wallpapers

        function onFilesChanged() {
            if (menu.open)
                menu.syncToLive();
        }
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
        if (menu.count === 0)
            return;

        // No clamp: run off the end of the folder and the next wallpaper is
        // the first one again.
        menu.index += delta;
    }

    function applyFocused() {
        if (menu.focused.length > 0)
            Wallpapers.apply(menu.focused);
    }

    // ─── the surface ─────────────────────────────────────────────────

    PanelWindow {
        id: window

        visible: menu.rendered
        color: "transparent"

        // Ignores the bar's exclusive zone, so the picker reaches the top of
        // the screen instead of starting in a seam below the bar — which is
        // what left the strip behind the bar unblurred and unwashed while the
        // rest of the display was covered.
        //
        // Only the mode is set here. Assigning exclusiveZone at all puts the
        // window back into Normal exclusion, zone or no zone, which is exactly
        // the geometry this is trying to avoid; Ignore already claims nothing.
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.namespace: "quickshell-wallpaper"
        WlrLayershell.layer: WlrLayer.Overlay

        // Exclusive while open: this is a chooser, and the arrow keys driving
        // it should not also be reaching whatever is behind it.
        WlrLayershell.keyboardFocus: menu.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        // A wash rather than a curtain. Enough to lift the caption off a bright
        // wallpaper, not enough to stop you seeing what you are replacing.
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
                case Qt.Key_Home:
                    menu.goTo(0);
                    break;
                case Qt.Key_End:
                    menu.goTo(menu.count - 1);
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                case Qt.Key_Space:
                    menu.applyFocused();
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
                    // Touchpads deliver a stream of small deltas; collecting
                    // them into notch-sized steps stops one gesture spinning
                    // the wheel through the whole folder.
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
            // Barely visible on purpose. It only has to imply that the cards
            // are mounted on one turning object rather than floating
            // independently, and the screen edge crops it to the near arc.

            Rectangle {
                x: stage.centreX - menu.radius - menu.cardWidth / 2
                y: stage.centreY - menu.radius - menu.cardWidth / 2

                width: (menu.radius + menu.cardWidth / 2) * 2
                height: width

                radius: width / 2
                antialiasing: true

                color: Theme.diskFill
                border.width: 1
                border.color: Theme.diskEdge

                // Turns with the wheel, off the same animated angle the cards
                // use, which is the only thing that makes the disk read as the
                // object carrying them rather than as decoration behind them.
                rotation: menu.tiltSign * menu.wheelAngle
            }

            // ─── the wallpapers on it ────────────────────────────────

            Item {
                anchors.fill: parent

                // Inert while a swap runs, so a second click cannot race the
                // first, but not dimmed for it. Dimming the whole wheel and
                // snapping it back was a flash in the middle of the change
                // rather than part of it — the selected card's own ring
                // carries the wait instead.
                enabled: !Wallpapers.applying

                // One delegate per slot on the rim, not per file: a slot is a
                // mounting point on the disk, and the folder is wrapped round
                // it as many times as it takes to fill the arc.
                Repeater {
                    model: menu.slots

                    delegate: Card {
                        required property int index

                        ordinal: index
                        path: menu.count > 0 ? Wallpapers.files[index % menu.count] : ""
                    }
                }
            }

            // ─── what you are looking at ─────────────────────────────
            //
            // Left of the wheel, where there is nothing else. The wheel owns
            // the right of the screen and the reading owns the left.

            Column {
                id: caption

                // Set against the wheel rather than pinned to the far edge of
                // the screen: the reading belongs to the wallpaper that has
                // come round to the front, and a caption marooned in the
                // opposite corner does not read as being about anything.
                width: 440

                // centreX - radius is the middle of the selected card, not its
                // edge, so its own half-width has to come off too — and it is
                // the scaled-up one, which is wider than the rest.
                x: Math.max(64, stage.centreX - menu.radius - menu.cardWidth * 0.62 - width - 64)
                anchors.verticalCenter: parent.verticalCenter

                spacing: 10

                PanelText {
                    width: parent.width
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                    text: menu.focused.length > 0 ? Wallpapers.displayName(menu.focused) : "No wallpapers found"
                    font.pixelSize: 34
                    font.weight: Font.DemiBold
                }

                PanelText {
                    width: parent.width
                    horizontalAlignment: Text.AlignRight
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap

                    text: {
                        if (Wallpapers.error.length > 0)
                            return Wallpapers.error;
                        if (Wallpapers.applying)
                            return "Applying…";
                        if (Wallpapers.isCurrent(menu.focused))
                            return "On the desktop now";
                        if (menu.count === 0)
                            return Wallpapers.directory;

                        // Spelt out rather than glyphed: this is the
                        // proportional face, and an arrow symbol here falls
                        // back to another font at the wrong size.
                        return (menu.file + 1) + " of " + menu.count + "  ·  scroll to turn, Enter to set";
                    }

                    color: Wallpapers.error.length > 0 ? Theme.urgent : Theme.muted
                }
            }
        }
    }

    // ─── one wallpaper on the rim ────────────────────────────────────

    component Card: Item {
        id: card

        property string path: ""
        property int ordinal: 0

        // Where this card sits on the rim right now, in degrees from the
        // selection point. Derived from the wheel's animated angle rather than
        // from the index, so it is already smooth — nothing below needs a
        // Behavior of its own, and nothing can drift out of step with anything
        // else, because it is all one number.
        //
        // Wrapped to the near half of the disk: a card that has travelled past
        // the far side is described as coming round the other way instead,
        // which is what turns the arc into an endless belt. The swap happens
        // at half a turn away, well behind the disk and off screen, so nothing
        // is ever seen jumping.
        readonly property real angle: menu.wrapAngle(card.ordinal * menu.step - menu.wheelAngle)
        readonly property real radians: card.angle * Math.PI / 180

        // The same distance expressed in notches, which is what the size and
        // fade curves are written against.
        readonly property real notches: Math.abs(card.angle) / menu.step

        readonly property bool front: card.ordinal === menu.slot
        readonly property bool live: Wallpapers.isCurrent(card.path)

        // Only the arc that is actually on screen is built.
        visible: card.notches <= menu.reach

        width: menu.cardWidth
        height: menu.cardHeight

        // Swung round the disk. The selection point is the leftmost point of
        // the circle, so a card at zero notches sits square in the middle of
        // the free edge and everything else curves away above and below it.
        x: stage.centreX - menu.radius * Math.cos(card.radians) - width / 2
        y: stage.centreY + menu.radius * Math.sin(card.radians) - height / 2

        rotation: menu.tiltSign * card.angle

        // Continuous in the angle rather than switched on the index: the card
        // grows as it arrives at the selection point instead of popping the
        // moment the selection changes under it.
        scale: 0.92 + 0.20 * Math.max(0, 1 - card.notches)

        // A shallow falloff, and no shading over the image itself. Enough for
        // the arc to have some depth, nowhere near enough to push these into a
        // background — every card on the rim stays a wallpaper you can judge.
        // The last notch fades out so the far ones leave the arc rather than
        // being cut off by the edge of the screen.
        opacity: {
            const rim = menu.reach - 0.5;
            if (card.notches > rim)
                return 0;

            const leaving = Math.min(1, rim - card.notches);
            return Math.max(0.7, 1 - card.notches * 0.06) * leaving;
        }

        // Nearest the selection point sits on top, by the same angle.
        z: 100 - card.notches

        ClippingRectangle {
            id: frame

            anchors.fill: parent
            radius: 18
            antialiasing: true
            color: Qt.rgba(1, 1, 1, 0.05)

            Image {
                anchors.fill: parent

                // A hair oversized, so the clip never catches a seam on the
                // rounded corners when the card is mid-turn.
                anchors.margins: -1

                source: "file://" + encodeURI(card.path)
                fillMode: Image.PreserveAspectCrop

                // Capped near the card's real size: decoding a 4K jpeg for
                // every wallpaper in the folder costs a visible hitch on open.
                sourceSize.width: menu.cardWidth
                asynchronous: true
                cache: true
                smooth: true
                mipmap: true

                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        // Drawn over the clip so the ring is not cut off by it.
        Rectangle {
            anchors.fill: parent
            radius: frame.radius
            antialiasing: true
            color: "transparent"

            border.width: card.front ? 2 : 1
            border.color: {
                if (card.front && card.live)
                    return Theme.accent;
                if (card.front)
                    return Qt.rgba(1, 1, 1, 0.75);
                return Theme.glassBorder;
            }

            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.hoverDuration
                    easing.type: Easing.OutCubic
                }
            }

            // The wait, carried by the card being applied rather than by
            // dimming everything. Breathes for as long as pywal is running and
            // is simply not running the rest of the time, so there is no
            // flash-and-restore around the change.
            SequentialAnimation on opacity {
                running: Wallpapers.applying && card.front
                loops: Animation.Infinite
                alwaysRunToEnd: true

                NumberAnimation { to: 0.35; duration: 480; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.00; duration: 480; easing.type: Easing.InOutSine }
            }
        }

        // The one actually on the desktop gets a mark as well as a ring: on a
        // busy photograph an accent border alone disappears into the image.
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 9

            width: 22
            height: 22
            radius: 999
            antialiasing: true
            color: Theme.accent

            opacity: card.live ? 1 : 0
            scale: card.live ? 1 : 0.4

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 340
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.6
                }
            }

            Glyph {
                anchors.centerIn: parent
                text: "󰄬"
                font.pixelSize: 13
                color: "white"
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            // A card on the rim is a target to turn to; the one at the
            // selection point is the choice itself. One click does whichever
            // the card is for.
            onClicked: {
                if (card.front)
                    menu.applyFocused();
                else
                    menu.index += menu.shortest(card.ordinal - menu.slot, menu.slots);
            }
        }
    }
}
