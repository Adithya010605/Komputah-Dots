pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "root:/"
import "root:/components"
import "root:/modules"

// The bar, and everything that hangs off it.
ShellRoot {
    id: root

    PanelWindow {
        id: bar

        color: "transparent"

        WlrLayershell.namespace: "quickshell-bar"
        WlrLayershell.layer: WlrLayer.Top

        anchors {
            top: true
            left: true
            right: true
        }

        // The window spans the full width even though the bar does not, which
        // is what lets a module report its position in plain screen pixels.
        implicitHeight: Theme.barExclusive
        exclusiveZone: Theme.barExclusive

        Rectangle {
            id: surface

            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.barMarginTop

            // The bar is exactly as wide as what is on it, capped by the
            // configured ceiling and by the screen. It used to be pinned at the
            // ceiling, which left a long run of empty glass past the window
            // name on one side and past the gear on the other.
            width: Math.min(Theme.barWidth, parent.width - Theme.edgeMargin * 2, modules.implicitWidth + Theme.barPadEnds * 2)
            height: Theme.barHeight

            // Modules come and go — the battery when it is unplugged, the count
            // beside the bell — and the glass should stretch to them rather
            // than snapping to a new width.
            Behavior on width {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }

            // The bar no longer spans the display, so panels have to be told
            // where it starts and ends or they hang off the end of it. The
            // window is full width and centred, so these are screen pixels.
            Binding {
                target: PanelState
                property: "barLeft"
                value: (bar.width - surface.width) / 2
            }

            Binding {
                target: PanelState
                property: "barRight"
                value: (bar.width + surface.width) / 2
            }

            Binding {
                target: PanelState
                property: "barInset"
                value: surface.height / 2
            }

            radius: 999
            antialiasing: true

            color: Theme.glass
            border.width: 1
            border.color: Theme.glassBorder

            // The same faint wallpaper wash the panels carry, so the bar and
            // anything dripping out of it are made of one material.
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                antialiasing: true
                color: Theme.glassTint
            }

            RowLayout {
                id: modules

                anchors.centerIn: parent
                spacing: Theme.moduleSpacing

                WindowModule {}

                Separator {}

                WorkspacesModule {}

                Separator {}

                ClockModule {}
            }
        }
    }
}
