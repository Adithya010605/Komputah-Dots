pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/components"

// What the machine is doing: three levels, a minute of history behind each, and
// the readings that only make sense as a number next to them.
DripPanel {
    id: panel

    name: "system"
    panelWidth: 348

    // The discrete GPU is only polled while its numbers are on screen.
    Binding {
        target: SysMon
        property: "detailed"
        value: panel.open
    }

    function gib(kib) {
        return (kib / 1048576).toFixed(1);
    }

    body: Component {
        ColumnLayout {
            spacing: 14

            // ─── header ──────────────────────────────────────────────

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                PanelText {
                    Layout.fillWidth: true
                    text: "system"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                PillButton {
                    label: "󰅖"
                    compact: true
                    onTriggered: PanelState.close()
                }
            }

            // ─── processor ───────────────────────────────────────────

            Meter {
                glyph: "󰻠"
                caption: "cpu"
                percent: SysMon.cpuPercent
                values: SysMon.cpuHistory

                chips: [
                    {
                        "text": SysMon.cpuTemp.toFixed(0) + "°",
                        // This part idles in the sixties, so the ramp starts
                        // above that — a chip that is always amber says
                        // nothing when the machine is actually working.
                        "color": Theme.heatOf(SysMon.cpuTemp, 70, 95)
                    },
                    {
                        "text": SysMon.cpuPower.toFixed(0) + "W",
                        "color": Theme.heatOf(SysMon.cpuPower, 30, 58)
                    }
                ]
            }

            // ─── the cores ───────────────────────────────────────────
            //
            // One column per logical core, in the order the kernel lists them,
            // so a single pinned thread reads as one tall bar in a flat row
            // rather than disappearing into the average above.

            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: -6
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Repeater {
                        model: SysMon.cores

                        delegate: Item {
                            required property real modelData

                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: 26

                            Rectangle {
                                anchors.fill: parent
                                radius: 4
                                antialiasing: true
                                color: Theme.plotFloor
                            }

                            Rectangle {
                                id: load

                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom

                                // A core that is doing nothing still shows a
                                // sliver, so the row reads as sixteen things
                                // rather than as gaps.
                                height: Math.max(2, parent.height * modelData / 100)
                                radius: 4
                                antialiasing: true

                                color: Theme.withAlpha(Theme.accentBase, 0.35 + 0.55 * modelData / 100)

                                Behavior on height {
                                    NumberAnimation {
                                        duration: SysMon.sampleInterval - 60
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Behavior on color {
                                    ColorAnimation {
                                        duration: SysMon.sampleInterval - 60
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                    }
                }

                PanelText {
                    text: SysMon.cores.length + " threads"
                    font.pixelSize: 9
                    color: Theme.muted
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.divider
            }

            // ─── graphics ────────────────────────────────────────────

            Meter {
                glyph: "󰢮"
                caption: "gpu"
                percent: SysMon.gpuPercent
                values: SysMon.gpuHistory
                cadence: SysMon.detailInterval

                // Nothing to say yet on the first poll, and nothing to say at
                // all if the card is asleep.
                dimmed: !SysMon.gpuKnown

                chips: SysMon.gpuKnown ? [
                    {
                        "text": SysMon.gpuTemp.toFixed(0) + "°",
                        "color": Theme.heatOf(SysMon.gpuTemp, 60, 87)
                    },
                    {
                        // Measured against the limit the card is actually held
                        // to, so the chip means "near its ceiling" rather than
                        // a number that only means something on one machine.
                        "text": SysMon.gpuPower.toFixed(0) + "W",
                        "color": Theme.heatOf(SysMon.gpuPower, (SysMon.gpuPowerLimit > 0 ? SysMon.gpuPowerLimit : 60) * 0.45, SysMon.gpuPowerLimit > 0 ? SysMon.gpuPowerLimit : 60)
                    }
                ] : []

                footer: SysMon.gpuKnown ? "tgp " + SysMon.gpuPower.toFixed(1) + " / " + SysMon.gpuPowerLimit.toFixed(0) + " W   ·   vram " + panel.gib(SysMon.gpuVramUsed * 1024) + " / " + panel.gib(SysMon.gpuVramTotal * 1024) + " GiB" : "asleep"
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.divider
            }

            // ─── memory ──────────────────────────────────────────────

            Meter {
                glyph: "󰍛"
                caption: "memory"
                percent: SysInfo.memoryPercent
                values: SysMon.memHistory
                midline: false

                footer: panel.gib(SysInfo.memoryUsedKb) + " / " + panel.gib(SysInfo.memoryTotalKb) + " GiB in use"
            }
        }
    }

    // One reading: what it is, where it has been, and the numbers that only a
    // number can carry.
    component Meter: ColumnLayout {
        id: meter

        property string glyph: ""
        property string caption: ""
        property real percent: 0
        property var values: []
        property int cadence: SysMon.sampleInterval
        property bool midline: true
        property bool dimmed: false
        property string footer: ""

        // [{ text, color }] — temperature, watts, whatever the reading needs.
        property var chips: []

        Layout.fillWidth: true
        spacing: 8

        opacity: meter.dimmed ? 0.45 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.hoverDuration
                easing.type: Easing.OutCubic
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 7

            Glyph {
                text: meter.glyph
                font.pixelSize: 13
                color: Theme.muted
            }

            PanelText {
                Layout.fillWidth: true
                text: meter.caption
                font.pixelSize: 11
                color: Theme.muted
            }

            Repeater {
                model: meter.chips

                delegate: Rectangle {
                    required property var modelData

                    implicitWidth: chipText.implicitWidth + 14
                    implicitHeight: 20
                    radius: 999
                    antialiasing: true

                    color: Theme.withAlpha(modelData.color, 0.16)
                    border.width: 1
                    border.color: Theme.withAlpha(modelData.color, 0.34)

                    Behavior on color {
                        ColorAnimation {
                            duration: 420
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 420
                            easing.type: Easing.OutCubic
                        }
                    }

                    PanelText {
                        id: chipText

                        anchors.centerIn: parent
                        text: modelData.text
                        font.family: Theme.monoFamily
                        font.pixelSize: 10
                        color: modelData.color

                        Behavior on color {
                            ColorAnimation {
                                duration: 420
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }

            PanelText {
                // Fixed width so the trace below never shifts sideways as the
                // reading crosses ten and a hundred percent.
                Layout.preferredWidth: 40
                horizontalAlignment: Text.AlignRight

                text: Math.round(meter.percent) + "%"
                font.family: Theme.monoFamily
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
        }

        Plot {
            Layout.fillWidth: true
            values: meter.values
            cadence: meter.cadence
            midline: meter.midline
        }

        PanelText {
            visible: meter.footer.length > 0
            text: meter.footer
            font.pixelSize: 9
            color: Theme.muted
        }
    }
}
