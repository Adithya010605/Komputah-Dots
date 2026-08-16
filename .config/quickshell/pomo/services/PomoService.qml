pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string script: "/home/adi/.config/waybar/scripts/pomo.sh"

    // ─── timer ───────────────────────────────────────────────────────
    property int presetMinutes: 20
    property int timeLeft: presetMinutes * 60
    property bool running: false
    property bool paused: false

    readonly property string label: paused ? "Paused" : (running ? "Focus" : "Ready")
    readonly property real progress: {
        const span = Math.max(1, presetMinutes * 60);
        return running ? 1 - (timeLeft / span) : 0;
    }

    // ─── study stats ─────────────────────────────────────────────────
    property int todayMinutes: 0
    property int todaySessions: 0
    property int weekMinutes: 0
    property int weekSessions: 0
    property int totalMinutes: 0
    property int totalSessions: 0
    property int streak: 0
    property int bestDayMinutes: 0
    property int activeDays: 0
    property var week: []

    // `week` arrives oldest -> newest ending today, which starts on a random
    // weekday. Re-slot it into a Sun..Sat calendar week so the strip always
    // reads left-to-right as a week; days that have not happened yet stay
    // empty rather than borrowing last week's numbers.
    readonly property var weekCalendar: {
        const names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
        const todayIndex = new Date().getDay();

        const slots = [];
        for (let i = 0; i < 7; i++)
            slots.push({
                    "day": names[i],
                    "minutes": 0,
                    "today": i === todayIndex,
                    "future": i > todayIndex
                });

        for (let i = 0; i < week.length; i++) {
            const daysAgo = (week.length - 1) - i;
            const slot = todayIndex - daysAgo;
            if (slot >= 0)
                slots[slot].minutes = week[i].minutes;
        }

        return slots;
    }

    readonly property int weekPeak: {
        let peak = 0;
        for (const day of weekCalendar)
            peak = Math.max(peak, day.minutes);
        return peak;
    }

    // ─── actions ─────────────────────────────────────────────────────

    function refresh() {
        stateProcess.running = false;
        stateProcess.exec([root.script, "state"]);
    }

    function run(command) {
        actionProcess.exec([root.script, command]);
        refreshDelay.restart();
    }

    function toggle() { run("toggle"); }
    function reset() { run("reset"); }
    function presetNext() { run("preset-next"); }
    function presetPrev() { run("preset-prev"); }

    // ─── formatting ──────────────────────────────────────────────────

    function formatTime(seconds) {
        const safe = Math.max(0, seconds);
        return String(Math.floor(safe / 60)).padStart(2, "0") + ":" + String(safe % 60).padStart(2, "0");
    }

    function formatDuration(minutes) {
        if (minutes < 60)
            return minutes + "m";

        const hours = Math.floor(minutes / 60);
        const mins = minutes % 60;
        return mins === 0 ? hours + "h" : hours + "h " + mins + "m";
    }

    // GitHub-style buckets: 0 is an empty cell, 1..4 shade darker -> lighter
    // against the peak of the displayed week.
    function heatLevel(minutes) {
        if (minutes <= 0 || weekPeak <= 0)
            return 0;

        const ratio = minutes / weekPeak;
        if (ratio >= 0.75)
            return 4;
        if (ratio >= 0.5)
            return 3;
        if (ratio >= 0.25)
            return 2;
        return 1;
    }

    function applyState(raw) {
        const trimmed = raw.trim();
        if (trimmed.length === 0)
            return;

        let data;
        try {
            data = JSON.parse(trimmed);
        } catch (error) {
            console.warn("pomo: invalid state payload:", trimmed);
            return;
        }

        root.presetMinutes = data.preset_minutes;
        root.timeLeft = data.running ? data.remaining_seconds : data.preset_minutes * 60;
        root.running = data.running;
        root.paused = data.paused;

        root.todayMinutes = data.today_minutes;
        root.todaySessions = data.today_sessions;
        root.weekMinutes = data.week_minutes;
        root.weekSessions = data.week_sessions;
        root.totalMinutes = data.total_minutes;
        root.totalSessions = data.total_sessions;
        root.streak = data.streak;
        root.bestDayMinutes = data.best_day_minutes;
        root.activeDays = data.active_days;
        root.week = data.week;
    }

    Process {
        id: stateProcess

        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.applyState(text)
        }
    }

    Process {
        id: actionProcess
    }

    // The countdown ticks locally so the display stays smooth without
    // spawning a shell every second.
    Timer {
        interval: 1000
        running: root.running && !root.paused
        repeat: true

        onTriggered: {
            if (root.timeLeft > 1) {
                root.timeLeft -= 1;
                return;
            }

            // Hand the finish to the backend so the session gets logged.
            root.timeLeft = 0;
            root.refresh();
        }
    }

    // Periodic resync: picks up stats, preset changes and anything the
    // waybar module did behind our back.
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        id: refreshDelay

        interval: 120
        repeat: false
        onTriggered: root.refresh()
    }
}
