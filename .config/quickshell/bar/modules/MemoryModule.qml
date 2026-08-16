import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/components"

// Memory pressure as a filling pie.
BarPill {
    id: pill

    interactive: false

    BarText {
        text: SysInfo.memoryGlyph + " " + SysInfo.memoryPercent + "%"
    }
}
