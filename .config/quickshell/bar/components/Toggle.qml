import QtQuick
import "root:/"

// The switch used for the radio toggles in the settings panel.
//
// Rectangles only, so nothing here resamples: the knob slides, the track takes
// the accent, and the whole thing stays crisp.
Item {
    id: toggle

    signal toggled(bool value)

    property bool checked: false
    property bool busy: false

    implicitWidth: 38
    implicitHeight: 21

    opacity: enabled ? 1 : 0.35

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.hoverDuration
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: track

        anchors.fill: parent
        radius: 999
        antialiasing: true

        color: toggle.checked ? Theme.accent : Theme.pill
        border.width: 1
        border.color: {
            if (toggle.checked)
                return Theme.accentSoft;
            return mouse.containsMouse ? Theme.pillHoverBorder : Theme.pillBorder;
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
    }

    Rectangle {
        id: knob

        y: (parent.height - height) / 2
        x: toggle.checked ? parent.width - width - 3 : 3

        width: parent.height - 6
        height: width
        radius: 999
        antialiasing: true

        color: Theme.text
        opacity: toggle.busy ? 0.55 : 1

        // Springy on the way over, so the switch has the same weight as
        // everything else in the shell.
        Behavior on x {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutBack
                easing.overshoot: 1.4
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.hoverDuration
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        enabled: toggle.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.toggled(!toggle.checked)
    }
}
