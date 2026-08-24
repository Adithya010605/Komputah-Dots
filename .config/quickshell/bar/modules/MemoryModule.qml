import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/components"

// Memory pressure as a filling pie, and the door to everything else the
// machine is doing.
BarPill {
    id: pill

    panelName: "system"
    active: PanelState.isOpen(pill.panelName)

    onTriggered: PanelState.toggle(pill.panelName, pill.screenCenter())

    BarText {
        text: SysInfo.memoryGlyph + " " + SysInfo.memoryPercent + "%"
    }
}
