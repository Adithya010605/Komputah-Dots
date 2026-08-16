import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/components"

// The bell. Click drops the notification log, right-click silences the shell.
//
// The count is the whole readout: an empty bell is a bell with nothing behind
// it, so the pill stays as narrow as a glyph until something arrives.
BarPill {
    id: pill

    readonly property int count: Notices.count

    hPad: 10
    contentSpacing: 5
    panelName: "notifications"
    active: PanelState.isOpen("notifications")

    onTriggered: PanelState.toggle("notifications", pill.screenCenter())
    onSecondary: Notices.silent = !Notices.silent

    // A new one arriving while the panel is shut should be felt on the bar,
    // not just counted — one soft swell of the accent and back.
    Connections {
        target: Notices

        function onPopupIdsChanged() {
            if (Notices.popupIds.length > 0)
                nudge.restart();
        }
    }

    SequentialAnimation {
        id: nudge

        NumberAnimation {
            target: bell
            property: "swell"
            to: 1
            duration: 180
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: bell
            property: "swell"
            to: 0
            duration: 520
            easing.type: Easing.OutCubic
        }
    }

    BarText {
        id: bell

        // 0 at rest, 1 at the top of the swell. Carried by colour alone: a
        // scaled glyph resamples and comes out ragged at bar sizes.
        property real swell: 0

        text: {
            if (Notices.silent)
                return "󰂛";
            return pill.count > 0 ? "󰂚" : "󰂜";
        }

        readonly property color base: {
            if (Notices.silent)
                return Theme.muted;
            if (Notices.hasUrgent)
                return Theme.urgent;
            return pill.count > 0 ? Theme.text : Theme.muted;
        }

        // No Behavior here: the swell is already an animation, and a second one
        // chasing it turns the flash into a smear.
        color: bell.swell > 0 ? Qt.tint(bell.base, Theme.withAlpha(Theme.accentBase, bell.swell)) : bell.base
    }

    // The count sits beside the bell rather than as a badge on it: a badge at
    // this size is a smear, and the number is the point.
    BarText {
        text: pill.count
        visible: pill.count > 0 && !Notices.silent
        color: Notices.hasUrgent ? Theme.urgent : Theme.text
    }
}
