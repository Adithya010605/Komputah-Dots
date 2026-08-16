pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "root:/"
import "root:/components"

// Outputs, inputs, and whatever each application is doing on its own.
DripPanel {
    id: panel

    name: "audio"
    panelWidth: 336

    // The active device only needs to read as "this one" — a full accent wash
    // fought with the sliders sitting on top of it.
    readonly property color selectedTint: Theme.withAlpha(Theme.accentBase, 0.13)
    readonly property color selectedTintHover: Theme.withAlpha(Theme.accentBase, 0.18)

    // ─── devices ─────────────────────────────────────────────────────

    function audioNodes(wantSink) {
        const found = [];
        for (const node of Pipewire.nodes.values) {
            // Streams are per-application, handled in their own section.
            if (!node.audio || node.isStream)
                continue;
            if (node.isSink === wantSink)
                found.push(node);
        }
        return found;
    }

    readonly property var sinks: audioNodes(true)
    readonly property var sources: audioNodes(false)

    readonly property var streams: {
        const found = [];
        for (const node of Pipewire.nodes.values) {
            if (!node.audio || !node.isStream || !node.isSink)
                continue;

            // speech-dispatcher parks a silent placeholder stream that is
            // always present and never worth a row.
            if (streamLabel(node).toLowerCase().includes("speech-dispatcher"))
                continue;

            found.push(node);
        }
        return found;
    }

    // Every node the panel reads has to be tracked, or its volume and mute
    // state never populate.
    PwObjectTracker {
        objects: [...panel.sinks, ...panel.sources, ...panel.streams]
    }

    function deviceLabel(node) {
        if (!node)
            return "";
        return node.description || node.nickname || node.name || "Unknown device";
    }

    function streamLabel(node) {
        if (!node)
            return "";

        const props = node.properties ?? {};
        return props["application.name"] || node.description || node.name || "Application";
    }

    // What the stream is actually playing. Browsers put the tab title here,
    // which is the only place per-tab media surfaces at all — MPRIS collapses
    // every tab into one player.
    function streamTitle(node) {
        if (!node)
            return "";

        const props = node.properties ?? {};
        const media = props["media.name"] ?? "";

        // Generic placeholders are worse than nothing; fall back to the app.
        if (media.length === 0 || media.toLowerCase() === "playback" || media.toLowerCase() === "audiostream")
            return streamLabel(node);

        return media;
    }

    function deviceIcon(node, isSink) {
        const label = (deviceLabel(node) + " " + (node && node.name ? node.name : "")).toLowerCase();

        if (!isSink)
            return label.includes("webcam") || label.includes("usb") ? "󰍬" : "󰍮";

        if (label.includes("hdmi") || label.includes("displayport"))
            return "󰡁";
        if (label.includes("bluez") || label.includes("bluetooth"))
            return "󰂰";
        if (label.includes("headphone") || label.includes("headset"))
            return "󰋋";
        if (label.includes("usb") || label.includes("spark"))
            return "󰓃";
        return "󰕾";
    }

    function isDefaultSink(node) {
        return Pipewire.defaultAudioSink && node && Pipewire.defaultAudioSink.id === node.id;
    }

    function isDefaultSource(node) {
        return Pipewire.defaultAudioSource && node && Pipewire.defaultAudioSource.id === node.id;
    }

    function volumePercent(node) {
        if (!node || !node.audio)
            return 0;
        return Math.round(node.audio.volume * 100);
    }

    body: Component {
        ColumnLayout {
            spacing: 12

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
                    color: Pipewire.defaultAudioSink && !Pipewire.defaultAudioSink.audio.muted ? Theme.accent : Theme.muted
                }

                PanelText {
                    Layout.fillWidth: true
                    text: "Audio"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                PillButton {
                    label: "󰅖"
                    compact: true
                    size: 28
                    glyphSize: 11
                    onTriggered: PanelState.close()
                }
            }

            // ─── outputs ─────────────────────────────────────────────

            SectionLabel {
                caption: "Output"
                count: panel.sinks.length
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: panel.sinks

                    delegate: DeviceRow {
                        required property var modelData

                        node: modelData
                        isSink: true
                        selected: panel.isDefaultSink(modelData)
                        onSelectRequested: Pipewire.preferredDefaultAudioSink = modelData
                    }
                }
            }

            // ─── inputs ──────────────────────────────────────────────

            SectionLabel {
                caption: "Input"
                count: panel.sources.length
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: panel.sources

                    delegate: DeviceRow {
                        required property var modelData

                        node: modelData
                        isSink: false
                        selected: panel.isDefaultSource(modelData)
                        onSelectRequested: Pipewire.preferredDefaultAudioSource = modelData
                    }
                }
            }

            // ─── per-application streams ─────────────────────────────

            SectionLabel {
                caption: "Apps"
                count: panel.streams.length
                visible: panel.streams.length > 0
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: panel.streams.length > 0
                spacing: 6

                Repeater {
                    model: panel.streams

                    delegate: DeviceRow {
                        required property var modelData

                        node: modelData
                        isSink: true
                        isStream: true
                        label: panel.streamTitle(modelData)
                        sublabel: panel.streamLabel(modelData)
                        glyph: "󰝚"
                    }
                }
            }
        }
    }

    // ─── panel-local components ──────────────────────────────────────

    component SectionLabel: RowLayout {
        id: section

        property string caption: ""
        property int count: 0

        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 6

        PanelText {
            text: section.caption
            font.pixelSize: 9
            font.weight: Font.DemiBold
            color: Theme.muted
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: 1
            color: Theme.divider
        }

        PanelText {
            text: section.count
            font.pixelSize: 9
            color: Theme.muted
        }
    }

    // A device or stream: pick it, mute it, drag its level.
    component DeviceRow: Rectangle {
        id: row

        signal selectRequested

        property var node: null
        property bool isSink: true
        property bool isStream: false
        property bool selected: false
        property string label: ""
        property string sublabel: ""
        property string glyph: ""

        readonly property string rowLabel: label.length > 0 ? label : panel.deviceLabel(node)
        readonly property string rowGlyph: glyph.length > 0 ? glyph : panel.deviceIcon(node, isSink)
        readonly property bool isMuted: node && node.audio ? node.audio.muted : false

        // A microphone row gets microphone glyphs — a speaker icon on an input
        // reads as the wrong control entirely.
        readonly property string muteGlyph: {
            if (!row.isSink && !row.isStream)
                return row.isMuted ? "󰍭" : "󰍬";
            return row.isMuted ? "󰝟" : "󰕾";
        }

        Layout.fillWidth: true
        implicitHeight: rowContent.implicitHeight + 16

        radius: 16
        antialiasing: true
        color: {
            if (row.selected)
                return rowHover.containsMouse ? panel.selectedTintHover : panel.selectedTint;
            return rowHover.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05);
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.hoverDuration
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            id: rowHover

            anchors.fill: parent
            hoverEnabled: true
            // Streams have no "default" to switch to, so only devices arm the
            // whole row as a target.
            cursorShape: row.isStream ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: {
                if (!row.isStream && !row.selected)
                    row.selectRequested();
            }
        }

        ColumnLayout {
            id: rowContent

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 7

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Glyph {
                    text: row.rowGlyph
                    font.pixelSize: 13
                    color: row.selected ? Theme.accent : Theme.text
                    opacity: row.isMuted ? 0.4 : 1
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    PanelText {
                        Layout.fillWidth: true
                        text: row.rowLabel
                        font.pixelSize: 11
                        font.weight: row.selected ? Font.DemiBold : Font.Medium
                        elide: Text.ElideRight
                        opacity: row.isMuted ? 0.5 : 1
                    }

                    PanelText {
                        Layout.fillWidth: true
                        text: row.sublabel
                        visible: text.length > 0 && text !== row.rowLabel
                        font.pixelSize: 9
                        color: Theme.muted
                        elide: Text.ElideRight
                    }
                }

                PanelText {
                    text: panel.volumePercent(row.node) + "%"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: row.isMuted ? Theme.muted : Theme.text
                }

                PillButton {
                    label: row.muteGlyph
                    compact: true
                    size: 28
                    glyphSize: 11
                    onTriggered: {
                        if (row.node && row.node.audio)
                            row.node.audio.muted = !row.node.audio.muted;
                    }
                }
            }

            VolumeSlider {
                Layout.fillWidth: true
                node: row.node
                dimmed: row.isMuted
            }
        }
    }

    // Drag, click or scroll to set a node's level.
    component VolumeSlider: Item {
        id: slider

        property var node: null
        property bool dimmed: false

        readonly property real value: node && node.audio ? Math.min(1, node.audio.volume) : 0

        implicitHeight: 14

        function applyAt(px) {
            if (!node || !node.audio)
                return;

            const ratio = Math.max(0, Math.min(1, px / Math.max(1, slider.width)));
            node.audio.volume = ratio;
        }

        function nudge(delta) {
            if (!node || !node.audio)
                return;

            node.audio.volume = Math.max(0, Math.min(1, node.audio.volume + delta));
        }

        Rectangle {
            id: track

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 999
            antialiasing: true
            color: Theme.pill

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * slider.value
                radius: 999
                antialiasing: true
                color: slider.dimmed ? Theme.muted : Theme.accent

                Behavior on width {
                    enabled: !drag.pressed

                    NumberAnimation {
                        duration: Theme.hoverDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        Rectangle {
            id: knob

            x: Math.max(0, Math.min(parent.width - width, track.width * slider.value - width / 2))
            anchors.verticalCenter: parent.verticalCenter
            width: 12
            height: 12
            radius: 999
            antialiasing: true

            color: slider.dimmed ? Theme.muted : Theme.accent
            border.width: 1
            border.color: Theme.pillHoverBorder
            scale: drag.pressed ? 1.25 : (drag.containsMouse ? 1.12 : 1)

            Behavior on scale {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }
        }

        MouseArea {
            id: drag

            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            onPressed: mouse => slider.applyAt(mouse.x + 4)
            onPositionChanged: mouse => {
                if (pressed)
                    slider.applyAt(mouse.x + 4);
            }
            onWheel: wheel => slider.nudge(wheel.angleDelta.y > 0 ? 0.02 : -0.02)
        }
    }
}
