import QtQuick
import "root:/"
import "root:/components"

// The thin divider between the bar's groups. No pill, no background — just a
// mark in the gap.
BarText {
    text: "|"
    color: Qt.rgba(1, 1, 1, 0.5)
    verticalAlignment: Text.AlignVCenter
}
