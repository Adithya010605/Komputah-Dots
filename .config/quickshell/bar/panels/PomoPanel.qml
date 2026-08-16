pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/components"

// The pomodoro panel: dial, controls, and what the week has looked like.
DripPanel {
    id: panel

    name: "pomo"
    panelWidth: 302

    // Seven square cells plus even gaps, sized to the card so the strip and
    // the stat row below it share one grid.
    readonly property int cellGap: 6
    readonly property int cellSize: Math.floor((panelWidth - Theme.padding * 2 - cellGap * 6) / 7)

    // Heat scale for the week strip: empty cells are barely-there white, the
    // rest ramp darker -> lighter in the accent, GitHub-style.
    readonly property color heatEmpty: Qt.rgba(1, 1, 1, 0.07)
    readonly property color heatFuture: Qt.rgba(1, 1, 1, 0.035)
    readonly property var heatScale: [Theme.withAlpha(Theme.accentBase, 0.26), Theme.withAlpha(Theme.accentBase, 0.46), Theme.withAlpha(Theme.accentBase, 0.68), Theme.withAlpha(Theme.accentBase, 0.92)]

    function heatColor(entry) {
        if (entry.future)
            return panel.heatFuture;

        const level = PomoService.heatLevel(entry.minutes);
        return level === 0 ? panel.heatEmpty : panel.heatScale[level - 1];
    }

    // Opening should show current numbers, not whatever was last polled.
    Connections {
        target: PanelState

        function onOpened(name) {
            if (name === panel.name)
                PomoService.refresh();
        }
    }

    body: Component {
        ColumnLayout {
            spacing: 14

            // ─── header ──────────────────────────────────────────────

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    width: 7
                    height: 7
                    radius: 999
                    antialiasing: true
                    color: PomoService.running ? Theme.accent : Theme.muted

                    SequentialAnimation on opacity {
                        running: PomoService.running && !PomoService.paused
                        loops: Animation.Infinite
                        alwaysRunToEnd: true

                        NumberAnimation { to: 0.30; duration: 950; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.00; duration: 950; easing.type: Easing.InOutSine }
                    }
                }

                PanelText {
                    Layout.fillWidth: true
                    text: PomoService.label
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                PillButton {
                    label: "󰅖"
                    compact: true
                    onTriggered: PanelState.close()
                }
            }

            // ─── dial ────────────────────────────────────────────────

            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 132
                Layout.preferredHeight: 132

                Canvas {
                    id: ring

                    anchors.fill: parent

                    property real progress: PomoService.progress
                    property color trackColor: Theme.pill
                    property color fillColor: PomoService.paused ? Theme.accentSoft : Theme.accent

                    onProgressChanged: requestPaint()
                    onTrackColorChanged: requestPaint()
                    onFillColorChanged: requestPaint()

                    Behavior on progress {
                        NumberAnimation {
                            duration: 320
                            easing.type: Easing.OutCubic
                        }
                    }

                    onPaint: {
                        const ctx = getContext("2d");
                        const centre = width / 2;
                        const radius = centre - 6;

                        ctx.reset();
                        ctx.lineWidth = 5;
                        ctx.lineCap = "round";

                        ctx.strokeStyle = trackColor;
                        ctx.beginPath();
                        ctx.arc(centre, centre, radius, 0, Math.PI * 2);
                        ctx.stroke();

                        if (progress <= 0)
                            return;

                        ctx.strokeStyle = fillColor;
                        ctx.beginPath();
                        ctx.arc(centre, centre, radius, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * progress);
                        ctx.stroke();
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    PanelText {
                        Layout.alignment: Qt.AlignHCenter
                        text: PomoService.formatTime(PomoService.timeLeft)
                        font.family: Theme.monoFamily
                        font.pixelSize: 30
                        font.weight: Font.DemiBold
                    }

                    PanelText {
                        Layout.alignment: Qt.AlignHCenter
                        text: PomoService.presetMinutes + " min"
                        font.pixelSize: 11
                        color: Theme.muted
                    }
                }
            }

            // ─── controls ────────────────────────────────────────────

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                PillButton {
                    label: "󰍴"
                    compact: true
                    enabled: !PomoService.running
                    onTriggered: PomoService.presetPrev()
                }

                PillButton {
                    label: PomoService.running && !PomoService.paused ? "󰏤" : "󰐊"
                    wide: true
                    highlighted: true
                    onTriggered: PomoService.toggle()
                }

                PillButton {
                    label: "󰜉"
                    compact: true
                    enabled: PomoService.running
                    onTriggered: PomoService.reset()
                }

                PillButton {
                    label: "󰐕"
                    compact: true
                    enabled: !PomoService.running
                    onTriggered: PomoService.presetNext()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 2
                implicitHeight: 1
                color: Theme.divider
            }

            // ─── headline stats ──────────────────────────────────────

            RowLayout {
                Layout.fillWidth: true
                spacing: panel.cellGap

                Stat {
                    caption: "today"
                    value: PomoService.formatDuration(PomoService.todayMinutes)
                }

                Stat {
                    caption: "this week"
                    value: PomoService.formatDuration(PomoService.weekMinutes)
                }

                Stat {
                    caption: "streak"
                    value: PomoService.streak + "d"
                    accented: PomoService.streak > 0
                }
            }

            // ─── the week, Sun -> Sat ────────────────────────────────

            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                spacing: 6

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: panel.cellGap

                    Repeater {
                        model: PomoService.weekCalendar

                        delegate: Rectangle {
                            required property var modelData

                            implicitWidth: panel.cellSize
                            implicitHeight: panel.cellSize
                            radius: 8
                            antialiasing: true

                            color: panel.heatColor(modelData)
                            border.width: modelData.today ? 1 : 0
                            border.color: Theme.pillHoverBorder

                            Behavior on color {
                                ColorAnimation {
                                    duration: 340
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: panel.cellGap

                    Repeater {
                        model: PomoService.weekCalendar

                        delegate: PanelText {
                            required property var modelData

                            Layout.preferredWidth: panel.cellSize
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData.day.charAt(0)
                            font.pixelSize: 9
                            color: modelData.today ? Theme.text : Theme.muted
                        }
                    }
                }
            }

            // ─── all time ────────────────────────────────────────────

            PanelText {
                Layout.fillWidth: true
                Layout.topMargin: 2
                horizontalAlignment: Text.AlignHCenter
                text: PomoService.totalSessions + " sessions · " + PomoService.formatDuration(PomoService.totalMinutes) + " · " + PomoService.activeDays + " days"
                font.pixelSize: 10
                color: Theme.muted
            }
        }
    }

    // Three equal tiles sharing the card's grid, gapped rather than divided —
    // the row lines up with the week strip beneath it.
    component Stat: Rectangle {
        id: stat

        property string caption: ""
        property string value: ""
        property bool accented: false

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: statContent.implicitHeight + 16

        radius: 14
        antialiasing: true
        color: Qt.rgba(1, 1, 1, 0.05)

        ColumnLayout {
            id: statContent

            anchors.centerIn: parent
            spacing: 2

            PanelText {
                Layout.alignment: Qt.AlignHCenter
                text: stat.value
                font.pixelSize: 15
                font.weight: Font.DemiBold
                color: stat.accented ? Theme.accent : Theme.text
            }

            PanelText {
                Layout.alignment: Qt.AlignHCenter
                text: stat.caption
                font.pixelSize: 9
                color: Theme.muted
            }
        }
    }
}
