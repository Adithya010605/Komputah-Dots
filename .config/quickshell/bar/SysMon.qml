pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What the machine is doing right now, and what it has been doing for the last
// minute.
//
// Everything cheap — /proc and hwmon, which are plain reads — runs for as long
// as the bar is up, so a plot is already full by the time you open it. Anything
// that costs a process spawn runs only while something is looking at it: on a
// hybrid laptop nvidia-smi wakes the discrete GPU, and waking it once a second
// for a panel nobody has open is a battery leak.
Singleton {
    id: root

    // One sample past the visible window, so the newest can slide in from the
    // right while the oldest slides off the left.
    readonly property int capacity: 61

    readonly property int sampleInterval: 1000
    readonly property int detailInterval: 1500

    // Raised by whatever is showing the numbers.
    property bool detailed: false

    // ─── cpu ─────────────────────────────────────────────────────────

    property real cpuPercent: 0

    // Percent busy per logical core, in /proc/stat order.
    property var cores: []

    property real cpuTemp: 0

    // Package power — the APU's PPT rail, which covers the cores and the
    // integrated graphics together.
    property real cpuPower: 0

    // ─── gpu ─────────────────────────────────────────────────────────

    property bool gpuKnown: false
    property real gpuPercent: 0
    property real gpuTemp: 0

    // Board power and the limit it is being held to, in watts.
    property real gpuPower: 0
    property real gpuPowerLimit: 0

    property real gpuVramUsed: 0
    property real gpuVramTotal: 0

    // ─── plots ───────────────────────────────────────────────────────

    property var cpuHistory: []
    property var memHistory: []
    property var gpuHistory: []

    function push(series, value) {
        const next = series.slice();
        next.push(value);

        while (next.length > root.capacity)
            next.shift();

        return next;
    }

    // ─── cpu sampling ────────────────────────────────────────────────
    //
    // /proc/stat counts jiffies since boot, so a reading on its own says
    // nothing — only the delta against the previous tick is a load.

    property var prevTotals: []
    property var prevBusies: []

    function sampleCpu(raw) {
        const totals = [];
        const busies = [];

        for (const line of raw.split("\n")) {
            // The cpu lines are first in the file; the moment one is not, the
            // rest of the file is other counters.
            if (!line.startsWith("cpu"))
                break;

            const values = line.trim().split(/\s+/).slice(1).map(v => parseInt(v, 10));
            if (values.length < 5)
                continue;

            let total = 0;
            for (const value of values)
                total += value;

            // Waiting on IO is not the processor being busy.
            const idle = values[3] + values[4];

            totals.push(total);
            busies.push(total - idle);
        }

        if (totals.length === 0)
            return;

        const previous = root.prevTotals;
        root.prevTotals = totals;

        const previousBusy = root.prevBusies;
        root.prevBusies = busies;

        // The first tick has nothing to subtract from.
        if (previous.length !== totals.length)
            return;

        const percents = [];

        for (let i = 0; i < totals.length; i++) {
            const span = totals[i] - previous[i];
            percents.push(span <= 0 ? 0 : Math.max(0, Math.min(100, ((busies[i] - previousBusy[i]) / span) * 100)));
        }

        // Index zero is the aggregate line; the rest are the cores themselves.
        root.cpuPercent = percents[0];
        root.cores = percents.slice(1);

        root.cpuHistory = root.push(root.cpuHistory, root.cpuPercent);
        root.memHistory = root.push(root.memHistory, SysInfo.memoryPercent);
    }

    FileView {
        id: stat

        path: "/proc/stat"
        preload: true
        blockLoading: true

        onLoaded: root.sampleCpu(text())
    }

    // ─── sensors ─────────────────────────────────────────────────────
    //
    // hwmon numbering is whatever order the drivers happened to probe in, so
    // it is resolved by name once at startup rather than hardcoded.

    property string cpuHwmon: ""
    property string apuHwmon: ""

    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do echo \"$(cat $d/name 2>/dev/null) $d\"; done"]

        stdout: StdioCollector {
            waitForEnd: true

            onStreamFinished: {
                for (const line of text.trim().split("\n")) {
                    const parts = line.split(" ");
                    if (parts.length < 2)
                        continue;

                    if (parts[0] === "k10temp" || parts[0] === "coretemp")
                        root.cpuHwmon = parts[1];
                    else if (parts[0] === "amdgpu")
                        root.apuHwmon = parts[1];
                }
            }
        }
    }

    FileView {
        id: cpuTempFile

        path: root.cpuHwmon.length > 0 ? root.cpuHwmon + "/temp1_input" : ""

        // Millidegrees.
        onLoaded: root.cpuTemp = parseInt(text(), 10) / 1000
    }

    FileView {
        id: cpuPowerFile

        path: root.apuHwmon.length > 0 ? root.apuHwmon + "/power1_input" : ""

        // Microwatts.
        onLoaded: root.cpuPower = parseInt(text(), 10) / 1000000
    }

    // ─── the discrete gpu ────────────────────────────────────────────

    function parseGpu(raw) {
        const fields = raw.trim().split(",").map(v => parseFloat(v));

        // A dGPU that is powered down answers with nothing usable, which is a
        // reading in itself: there is no load to report.
        if (fields.length < 6 || isNaN(fields[0])) {
            root.gpuKnown = false;
            return;
        }

        root.gpuTemp = fields[0];
        root.gpuPower = isNaN(fields[1]) ? 0 : fields[1];
        root.gpuPowerLimit = isNaN(fields[2]) ? 0 : fields[2];
        root.gpuPercent = isNaN(fields[3]) ? 0 : fields[3];
        root.gpuVramUsed = fields[4];
        root.gpuVramTotal = fields[5];
        root.gpuKnown = true;

        root.gpuHistory = root.push(root.gpuHistory, root.gpuPercent);
    }

    Process {
        id: gpuProbe

        command: ["nvidia-smi", "--query-gpu=temperature.gpu,power.draw,enforced.power.limit,utilization.gpu,memory.used,memory.total", "--format=csv,noheader,nounits"]

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseGpu(text)
        }

        onExited: code => {
            if (code !== 0)
                root.gpuKnown = false;
        }
    }

    // ─── clocks ──────────────────────────────────────────────────────
    //
    // /proc and sysfs emit no change notification, so both are re-read rather
    // than watched.

    Timer {
        interval: root.sampleInterval
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            stat.reload();

            if (root.cpuHwmon.length > 0)
                cpuTempFile.reload();
            if (root.apuHwmon.length > 0)
                cpuPowerFile.reload();
        }
    }

    Timer {
        interval: root.detailInterval
        running: root.detailed
        repeat: true
        triggeredOnStart: true

        // Skipped rather than queued if the last spawn has not come back, so a
        // slow nvidia-smi cannot pile up behind itself.
        onTriggered: {
            if (!gpuProbe.running)
                gpuProbe.running = true;
        }
    }
}
