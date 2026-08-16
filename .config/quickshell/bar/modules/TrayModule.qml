import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import "root:/"
import "root:/components"

// The status icons, in one pill. Left click activates, right click opens the
// item's own menu, and the wheel is passed through to it.
BarPill {
    id: pill

    interactive: false
    hPad: 11
    contentSpacing: 8

    // An empty tray should not leave an empty pill sitting on the bar.
    visible: SystemTray.items.values.length > 0

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: entry

            required property var modelData

            Layout.preferredWidth: 17
            Layout.preferredHeight: 17

            IconImage {
                id: icon

                anchors.fill: parent
                source: entry.modelData.icon
                asynchronous: true

                // Hover lifts the icon out of its resting dim rather than
                // scaling it — a resampled 17px icon loses its edges.
                opacity: {
                    if (entry.modelData.status === Status.Passive)
                        return hover.hovered ? 0.75 : 0.55;
                    return hover.hovered ? 1 : 0.82;
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.hoverDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }

            HoverHandler {
                id: hover

                cursorShape: Qt.PointingHandCursor
            }

            QsMenuAnchor {
                id: menu

                menu: entry.modelData.menu
                anchor.item: entry
                anchor.edges: Edges.Bottom
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                onClicked: mouse => {
                    // Items that only carry a menu have nothing to activate, so
                    // a left click should open the menu too.
                    if (mouse.button === Qt.RightButton || entry.modelData.onlyMenu) {
                        if (entry.modelData.hasMenu)
                            menu.open();
                        return;
                    }

                    if (mouse.button === Qt.MiddleButton)
                        entry.modelData.secondaryActivate();
                    else
                        entry.modelData.activate();
                }

                onWheel: wheel => {
                    if (wheel.angleDelta.y !== 0)
                        entry.modelData.scroll(wheel.angleDelta.y, false);
                    if (wheel.angleDelta.x !== 0)
                        entry.modelData.scroll(wheel.angleDelta.x, true);
                }
            }
        }
    }
}
