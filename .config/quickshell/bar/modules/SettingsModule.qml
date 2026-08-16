import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell.Networking
import "root:/"
import "root:/components"

// The radios, in one place.
//
// Wi-Fi and bluetooth used to be their own pills; they are toggles you touch
// occasionally, not numbers you read constantly, so the bar keeps a single gear
// and the panel underneath holds each of them in full.
BarPill {
    id: pill

    readonly property var adapter: Bluetooth.defaultAdapter

    // The gear picks up the accent when either radio is actually carrying a
    // connection, which is the only at-a-glance state worth keeping on the bar.
    readonly property bool anyConnected: {
        if (Networking.connectivity === NetworkConnectivity.Full)
            return true;

        if (pill.adapter && pill.adapter.enabled) {
            for (const device of Bluetooth.devices.values) {
                if (device && device.connected)
                    return true;
            }
        }

        return false;
    }

    panelName: "settings"
    active: PanelState.isOpen("settings")

    onTriggered: PanelState.toggle("settings", pill.screenCenter())

    BarText {
        text: "󰒓"
        color: pill.anyConnected ? Theme.text : Theme.muted

        Behavior on color {
            ColorAnimation {
                duration: Theme.hoverDuration
                easing.type: Easing.OutCubic
            }
        }
    }
}
