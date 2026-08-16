import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/components"

// Screen brightness, driven by the wheel.
//
// Keeps the slow sun-pulse the waybar module had on hover — the glyph breathes
// while the cursor is on it, and settles back the moment it leaves.
BarPill {
    id: pill

    scrollable: true
    onScrolled: up => Brightness.step(up)

    SequentialAnimation {
        id: pulse

        running: pill.hovered
        loops: Animation.Infinite

        NumberAnimation {
            target: label
            property: "glow"
            to: 1
            duration: 900
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            target: label
            property: "glow"
            to: 0
            duration: 900
            easing.type: Easing.InOutSine
        }
    }

    // Stopping a looping animation leaves the value wherever it was, so the
    // glyph is eased back to rest explicitly.
    onHoveredChanged: {
        if (!pill.hovered)
            settle.restart();
    }

    NumberAnimation {
        id: settle

        target: label
        property: "glow"
        to: 0
        duration: 320
        easing.type: Easing.OutCubic
    }

    BarText {
        id: label

        // 0 at rest, 1 at the top of the breath.
        property real glow: 0

        // The breath is carried by colour alone — a scaled label resamples the
        // glyph and comes out ragged.
        text: Brightness.icon + "  " + Brightness.percent + "%"
        color: Qt.lighter(Theme.text, 1 + glow * 0.15)
    }
}
