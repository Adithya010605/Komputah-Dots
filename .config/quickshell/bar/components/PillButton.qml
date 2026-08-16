import QtQuick
import "root:/"

// The round control used throughout the panels.
Item {
    id: button

    signal triggered

    property string label: ""
    property bool wide: false
    property bool compact: false
    property bool highlighted: false

    // The audio panel packs these into device rows and needs a tighter button
    // than the transport controls use.
    property int size: 34
    property int glyphSize: compact ? 13 : 15

    implicitWidth: wide ? 64 : size
    implicitHeight: size
    opacity: enabled ? 1 : 0.32

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.hoverDuration
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: surface

        anchors.fill: parent
        radius: 999
        antialiasing: true

        // Pressed reads as a colour, not as a shrink: the glyph sitting on top
        // is text, and resampling text mid-press looks ragged.
        color: {
            if (button.highlighted)
                return mouse.containsMouse ? Theme.accent : Theme.accentSoft;
            if (mouse.pressed && button.enabled)
                return Theme.pillPress;
            return mouse.containsMouse ? Theme.pillHover : Theme.pill;
        }
        border.width: 1
        border.color: mouse.containsMouse ? Theme.pillHoverBorder : Theme.pillBorder

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

    Glyph {
        anchors.centerIn: parent
        text: button.label
        font.pixelSize: button.glyphSize
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        enabled: button.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: button.triggered()
    }
}
