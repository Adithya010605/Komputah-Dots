import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "root:/"

// One module on the bar.
//
// Geometry matches waybar's module rule exactly; the difference is that this
// one reacts — it brightens under the cursor, sinks when clicked, and glows
// with the accent for as long as its panel is hanging beneath it.
//
// All of that is done with colour. Scaling the pill scaled the text inside it
// too, and text rendered at a fractional size reads as choppy and pixelated —
// worse on hover, when the eye is already on it.
Rectangle {
    id: pill

    signal triggered
    signal secondary
    signal scrolled(bool up)

    // Off for modules that handle their own clicks internally, like the
    // workspace strip — the pill still hovers and still scrolls.
    property bool interactive: true
    property bool scrollable: false

    // True while this module's panel is open, which is the only thing tying a
    // hanging panel back to the thing that spawned it.
    property bool active: false

    property int hPad: Theme.modulePadH
    property int contentSpacing: 6

    // How far a module's own progress has got, 0 to 1. Anything above zero
    // fills the pill from the left with the wallpaper accent — the pill itself
    // becomes the progress bar, so a running timer needs no extra chrome on the
    // bar to be readable at a glance.
    property real progress: 0
    property color progressColor: Theme.accentSoft
    property color progressEdge: Theme.accent

    readonly property bool hovered: hover.hovered

    default property alias content: inner.data

    implicitWidth: inner.implicitWidth + hPad * 2
    implicitHeight: Theme.moduleHeight

    radius: 999
    antialiasing: true

    color: {
        if (pill.active)
            return Theme.pillActive;
        if (click.pressed && pill.interactive)
            return Theme.pillPress;
        return hover.hovered ? Theme.pillHover : Theme.pill;
    }

    border.width: 1
    border.color: {
        if (pill.active)
            return Theme.pillActiveBorder;
        return hover.hovered ? Theme.pillHoverBorder : Theme.pillBorder;
    }

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

    // The panel this module drops, if any. Naming it lets the module keep its
    // position on file, so a keybind can open the panel in the right place
    // without a click to derive one from.
    property string panelName: ""

    // Where this module sits on screen, for a panel to hang from. The bar
    // window spans the full width of the display, so scene coordinates are
    // already screen coordinates.
    function screenCenter() {
        return pill.mapToItem(null, pill.width / 2, 0).x;
    }

    Component.onCompleted: {
        if (pill.panelName.length > 0)
            PanelState.setAnchorSource(pill.panelName, pill);
    }

    // The fill, clipped to the pill's own shape so it ends on the curve rather
    // than on a straight edge inside it. Declared before the content so it sits
    // behind the text.
    ClippingRectangle {
        anchors.fill: parent
        anchors.margins: 1

        visible: pill.progress > 0
        color: "transparent"
        radius: pill.radius
        antialiasing: true

        Rectangle {
            id: level

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            width: parent.width * Math.max(0, Math.min(1, pill.progress))
            color: pill.progressColor

            // The countdown steps once a second; easing across the whole step
            // is what makes it read as a level rising rather than as a bar
            // clicking forward.
            Behavior on width {
                NumberAnimation {
                    duration: 950
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.hoverDuration
                    easing.type: Easing.OutCubic
                }
            }

            // The surface of it: one bright line where the level has got to,
            // the way the leading edge of a liquid catches light.
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                width: 2
                visible: pill.progress > 0.005 && pill.progress < 0.995
                color: pill.progressEdge

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.hoverDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    RowLayout {
        id: inner

        anchors.centerIn: parent
        spacing: pill.contentSpacing
    }

    // A hover handler rather than the mouse area's own hover, so modules that
    // manage their own clicks still light up as one pill.
    HoverHandler {
        id: hover

        cursorShape: pill.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
    }

    // Wheel is handled separately from clicks so a module can be scrollable
    // without swallowing the clicks of the buttons inside it.
    WheelHandler {
        enabled: pill.scrollable
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        property real accumulated: 0

        onWheel: event => {
            // Touchpads deliver a stream of small deltas; collecting them into
            // notch-sized steps stops one gesture firing a dozen times.
            accumulated += event.angleDelta.y;

            while (accumulated >= 120) {
                accumulated -= 120;
                pill.scrolled(true);
            }
            while (accumulated <= -120) {
                accumulated += 120;
                pill.scrolled(false);
            }
        }
    }

    MouseArea {
        id: click

        anchors.fill: parent
        enabled: pill.interactive
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                pill.secondary();
            else
                pill.triggered();
        }
    }
}
