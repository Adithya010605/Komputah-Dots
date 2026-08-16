import QtQuick
import QtQuick.Layouts
import Quickshell
import "root:/"
import "root:/components"

// Time, with the date on click — waybar's format-alt, faded across so the two
// faces read as one object turning over.
BarPill {
    id: pill

    property bool showingDate: false

    // What is actually on screen. Held separately from `showingDate` so the
    // swap lands while the label is invisible, mid-fade.
    property bool renderingDate: false

    onTriggered: pill.showingDate = !pill.showingDate
    onShowingDateChanged: flip.restart()

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    SequentialAnimation {
        id: flip

        NumberAnimation {
            target: label
            property: "opacity"
            to: 0
            duration: 90
            easing.type: Easing.OutCubic
        }

        ScriptAction {
            script: pill.renderingDate = pill.showingDate
        }

        NumberAnimation {
            target: label
            property: "opacity"
            to: 1
            duration: 170
            easing.type: Easing.OutCubic
        }
    }

    BarText {
        id: label

        text: pill.renderingDate ? Qt.formatDateTime(clock.date, "ddd, dd MMM") : Qt.formatDateTime(clock.date, "hh:mm AP")
    }
}
