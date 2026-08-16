import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/"
import "root:/components"

// The workspace strip, drawn as dots.
//
// Plain rounded rectangles rather than a font glyph: a rectangle stays crisp at
// any size and can stretch, so the focused workspace grows into a capsule
// instead of scaling a circle up and resampling it. Three states, one accent —
// focused takes the wallpaper accent at full strength, occupied a soft wash of
// the same colour, empty a bare hint of white.
BarPill {
    id: pill

    // The dots handle their own clicks, but the strip as a whole still scrolls.
    interactive: false
    scrollable: true
    hPad: 8
    contentSpacing: Theme.workspaceDotSpacing

    onScrolled: up => Hypr.cycleWorkspace(!up)

    Repeater {
        model: Hypr.workspaceIds

        delegate: Item {
            id: slot

            required property var modelData

            readonly property int workspaceId: modelData
            readonly property bool focused: Hypr.focusedWorkspace === workspaceId
            readonly property bool occupied: Hypr.isOccupied(workspaceId)

            // Animated here rather than on the rectangle so the slot in the row
            // grows with the dot instead of the neighbours jumping at the end.
            property real dotWidth: focused ? Theme.workspaceDotActive : Theme.workspaceDot

            // The capsule stretches out of the dot with a little weight to it,
            // the same springy settle the panels drip on.
            Behavior on dotWidth {
                NumberAnimation {
                    duration: 280
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.8
                }
            }

            // A few pixels of slack around the dot keeps the click target
            // comfortable without spacing the strip out.
            Layout.preferredWidth: dotWidth + 6
            Layout.preferredHeight: pill.implicitHeight

            Rectangle {
                id: dot

                anchors.centerIn: parent

                width: slot.dotWidth
                height: Theme.workspaceDot
                radius: 999
                antialiasing: true

                color: {
                    if (slot.focused)
                        return Theme.workspaceActive;
                    if (hover.hovered)
                        return Theme.workspaceHover;
                    return slot.occupied ? Theme.workspaceOccupied : Theme.workspaceEmpty;
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.hoverDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }

            HoverHandler {
                id: hover

                cursorShape: Qt.PointingHandCursor
            }

            MouseArea {
                anchors.fill: parent
                onClicked: Hypr.focusWorkspace(slot.workspaceId)
            }
        }
    }
}
