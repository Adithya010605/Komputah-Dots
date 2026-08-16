pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Backlight level for the panel's own display, read and driven through
// brightnessctl — the same device and curve the waybar module used.
Singleton {
    id: root

    readonly property string device: "amdgpu_bl1"

    property int percent: 0
    property bool known: false

    readonly property string icon: {
        if (percent < 34)
            return "󰃞";
        if (percent < 67)
            return "󰃟";
        return "󰃠";
    }

    function refresh() {
        if (readProcess.running)
            return;
        readProcess.running = true;
    }

    // -e4 -n2 matches the waybar bindings: a perceptual curve that never
    // bottoms the panel out completely.
    function step(up) {
        writeProcess.exec(["brightnessctl", "-d", root.device, "-e4", "-n2", "set", up ? "5%+" : "5%-"]);

        // brightnessctl has already applied the change by the time it exits,
        // so read back rather than guessing the new curve position.
        settleTimer.restart();
    }

    Process {
        id: readProcess

        command: ["brightnessctl", "-d", root.device, "-m"]

        stdout: StdioCollector {
            waitForEnd: true

            onStreamFinished: {
                // device,class,current,percent%,max
                const fields = text.trim().split(",");
                if (fields.length < 4)
                    return;

                const parsed = parseInt(fields[3].replace("%", ""), 10);
                if (isNaN(parsed))
                    return;

                root.percent = parsed;
                root.known = true;
            }
        }
    }

    Process {
        id: writeProcess
    }

    Timer {
        id: settleTimer

        interval: 60
        repeat: false
        onTriggered: root.refresh()
    }

    // Brightness also changes from function keys and hypridle, so it is polled
    // rather than assumed to only move when the bar moves it.
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
