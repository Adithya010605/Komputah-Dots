import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/components"

// The focused window's class, at a fixed width so the centre of the bar does
// not shuffle every time you switch apps.
BarPill {
    id: pill

    interactive: false
    hPad: 13
    implicitWidth: Theme.windowModuleWidth

    // A title swap is a change of subject, so the word is faded out and the
    // new one faded in rather than snapping mid-glance.
    property string displayed: Hypr.windowLabel

    Connections {
        target: Hypr

        function onWindowLabelChanged() {
            swap.restart();
        }
    }

    SequentialAnimation {
        id: swap

        NumberAnimation {
            target: label
            property: "opacity"
            to: 0
            duration: 90
            easing.type: Easing.OutCubic
        }

        ScriptAction {
            script: pill.displayed = Hypr.windowLabel
        }

        NumberAnimation {
            target: label
            property: "opacity"
            to: 1
            duration: 160
            easing.type: Easing.OutCubic
        }
    }

    BarText {
        id: label

        Layout.preferredWidth: Theme.windowModuleWidth - pill.hPad * 2
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: pill.displayed
    }
}
