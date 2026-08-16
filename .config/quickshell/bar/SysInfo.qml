pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Memory pressure, straight from /proc/meminfo.
//
// "Used" here is total minus available, which is what you actually feel —
// reclaimable cache is not pressure.
Singleton {
    id: root

    property int memoryPercent: 0

    // The same five-step pie the waybar module drew.
    readonly property string memoryGlyph: {
        if (memoryPercent < 20)
            return "○";
        if (memoryPercent < 40)
            return "◔";
        if (memoryPercent < 60)
            return "◑";
        if (memoryPercent < 80)
            return "◕";
        return "●";
    }

    function parseMeminfo(raw) {
        let total = 0;
        let available = 0;

        for (const line of raw.split("\n")) {
            const match = line.match(/^(MemTotal|MemAvailable):\s+(\d+)/);
            if (!match)
                continue;

            if (match[1] === "MemTotal")
                total = parseInt(match[2], 10);
            else
                available = parseInt(match[2], 10);
        }

        if (total <= 0)
            return;

        root.memoryPercent = Math.round(((total - available) / total) * 100);
    }

    FileView {
        id: meminfo

        path: "/proc/meminfo"
        preload: true
        blockLoading: true

        onLoaded: root.parseMeminfo(text())
    }

    // /proc does not emit change notifications, so it gets re-read on the same
    // cadence the waybar module polled at.
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: meminfo.reload()
    }
}
