import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/components"

// The pomodoro countdown. Click opens the panel, right-click stops the run,
// and the wheel steps the preset — the same bindings as before.
BarPill {
    id: pill

    scrollable: true
    panelName: "pomo"
    active: PanelState.isOpen("pomo")

    // The run, drawn as a level filling the pill: the countdown tells you how
    // long is left, the fill tells you how far in you are without being read.
    progress: PomoService.running ? PomoService.progress : 0

    // A paused run holds its level but drains the colour out of it, so a
    // stopped clock never looks like a running one out of the corner of an eye.
    progressColor: PomoService.paused ? Qt.rgba(1, 1, 1, 0.13) : Theme.accentSoft
    progressEdge: PomoService.paused ? Qt.rgba(1, 1, 1, 0.28) : Theme.accent

    onTriggered: PanelState.toggle("pomo", pill.screenCenter())
    onSecondary: PomoService.stop()
    onScrolled: up => up ? PomoService.presetNext() : PomoService.presetPrev()

    BarText {
        text: PomoService.barText

        // The running countdown stays plain white; a paused one recedes.
        color: PomoService.paused ? Theme.muted : Theme.text

        Behavior on color {
            ColorAnimation {
                duration: Theme.hoverDuration
                easing.type: Easing.OutCubic
            }
        }

        // A slow breath while the clock is actually running, so the bar has one
        // quiet sign of life without becoming a distraction.
        SequentialAnimation on opacity {
            running: PomoService.running && !PomoService.paused
            loops: Animation.Infinite
            alwaysRunToEnd: true

            NumberAnimation {
                to: 0.62
                duration: 1400
                easing.type: Easing.InOutSine
            }

            NumberAnimation {
                to: 1
                duration: 1400
                easing.type: Easing.InOutSine
            }
        }
    }
}
