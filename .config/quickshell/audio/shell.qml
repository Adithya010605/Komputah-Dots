pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire

ShellRoot {
    id: root

    // ─── open / close state ──────────────────────────────────────────
    property bool popupOpen: true
    property bool popupRendered: true

    // Centre of the waybar module the panel hangs from, written by the
    // launcher from the calibrated module position.
    property real anchorX: 960

    // ─── geometry ────────────────────────────────────────────────────
    // Layers anchored to the top are already placed below waybar's exclusive
    // zone, so nothing here needs to know the bar's height.
    readonly property int edgeMargin: 8
    readonly property int cardWidth: 336
    // Slack below the card so the springy overshoot at the end of the drip
    // is not clipped by the layer surface.
    readonly property int overshootRoom: 18

    // ─── palette (mirrors ~/.config/waybar/style.css) ─────────────────
    property var wal: ({
            "special": {
                "background": "#0d0d0d",
                "foreground": "#a1bac4"
            },
            "colors": {
                "color4": "#638574",
                "color6": "#497497",
                "color12": "#8fb3a1"
            }
        })

    readonly property color glass: Qt.rgba(20 / 255, 20 / 255, 28 / 255, 0.34)
    readonly property color glassBorder: Qt.rgba(1, 1, 1, 0.12)
    readonly property color pill: Qt.rgba(1, 1, 1, 0.14)
    readonly property color pillBorder: Qt.rgba(1, 1, 1, 0.22)
    readonly property color pillHover: Qt.rgba(1, 1, 1, 0.20)
    readonly property color pillHoverBorder: Qt.rgba(1, 1, 1, 0.30)
    readonly property color divider: Qt.rgba(1, 1, 1, 0.10)
    readonly property color text: "white"
    readonly property color muted: Qt.rgba(1, 1, 1, 0.55)
    readonly property color accent: withAlpha(pick("color12", "#8fb3a1"), 0.85)
    readonly property color accentSoft: withAlpha(pick("color12", "#8fb3a1"), 0.30)

    // The active device only needs to read as "this one" — a full accent wash
    // fought with the sliders sitting on top of it.
    readonly property color selectedTint: withAlpha(pick("color12", "#8fb3a1"), 0.13)
    readonly property color selectedTintHover: withAlpha(pick("color12", "#8fb3a1"), 0.18)

    readonly property int cardRadius: 26
    readonly property int padding: 16

    // Proportional face for everything readable, the Nerd Font purely for
    // glyphs — same split as the pomodoro and media panels.
    readonly property string fontFamily: "Adwaita Sans"
    readonly property string iconFamily: "GeistMono Nerd Font"

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
        objects: [...root.sinks, ...root.sources, ...root.streams]
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

    function pick(key, fallback) {
        return (wal && wal.colors && wal.colors[key]) ? wal.colors[key] : fallback;
    }

    function withAlpha(hex, opacity) {
        const c = Qt.color(hex);
        return Qt.rgba(c.r, c.g, c.b, opacity);
    }

    function applyAnchor(raw) {
        const parsed = parseFloat(raw);
        if (!isNaN(parsed))
            root.anchorX = parsed;
    }

    function openPopup() {
        root.popupRendered = true;
        root.popupOpen = true;
    }

    function closePopup() {
        root.popupOpen = false;
        unrenderDelay.restart();
    }

    // A cold start comes from clicking the waybar icon, so open against the
    // anchor the launcher wrote just before spawning us.
    Component.onCompleted: {
        applyAnchor(anchorFile.text());
        openPopup();
    }

    // ─── external state ──────────────────────────────────────────────

    FileView {
        id: walFile

        path: "/home/adi/.cache/wal/colors.json"
        preload: true
        blockLoading: true
        watchChanges: true

        onFileChanged: reload()
        onTextChanged: {
            const raw = text().trim();
            if (raw.length === 0)
                return;

            try {
                root.wal = JSON.parse(raw);
            } catch (error) {
                console.warn("audio: could not parse wal colors");
            }
        }
    }

    FileView {
        id: anchorFile

        path: "/tmp/audio_popup_x"
        preload: true
        blockLoading: true
    }

    Timer {
        id: unrenderDelay

        interval: 280
        repeat: false
        onTriggered: {
            if (!root.popupOpen)
                root.popupRendered = false;
        }
    }

    IpcHandler {
        target: "audio"

        function toggle(x: string): void {
            root.applyAnchor(x);

            if (root.popupOpen)
                root.closePopup();
            else
                root.openPopup();
        }

        // Named open/close rather than show/hide: `show` is also an
        // `ipc` subcommand and the CLI swallows it before the call.
        function open(x: string): void {
            root.applyAnchor(x);
            root.openPopup();
        }

        function close(): void { root.closePopup(); }
    }

    // ─── click-outside catcher ───────────────────────────────────────
    // Its own namespace so no blur rule applies to the transparent sheet.

    PanelWindow {
        id: catcher

        visible: root.popupRendered
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.namespace: "quickshell-audio-catcher"
        WlrLayershell.layer: WlrLayer.Top

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closePopup()
        }
    }

    // ─── the panel ───────────────────────────────────────────────────

    PanelWindow {
        id: popup

        visible: root.popupRendered
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.namespace: "quickshell-audio"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.popupOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        implicitWidth: root.cardWidth
        implicitHeight: panelBody.cardHeight + root.overshootRoom

        anchors {
            top: true
            left: true
        }

        margins {
            left: {
                const ideal = root.anchorX - popup.implicitWidth / 2;
                const limit = (popup.screen ? popup.screen.width : 1920) - popup.implicitWidth - root.edgeMargin;
                return Math.round(Math.max(root.edgeMargin, Math.min(limit, ideal)));
            }
        }

        Item {
            id: panelBody

            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: root.closePopup()

            readonly property int cardHeight: content.implicitHeight + root.padding * 2

            // The drip. `reveal` is the exposed height, growing downward from
            // the bar's underside; the card is pinned above it and hangs
            // through, so the top corners are clipped square and the join
            // reads as one continuous surface with waybar.
            Item {
                id: clipper

                x: 0
                y: 0
                width: parent.width
                height: reveal
                clip: true

                property real reveal: root.popupOpen ? panelBody.cardHeight : 0

                // Surface tension: the column narrows at the pinch and springs
                // back out to full width as the droplet settles.
                property real neck: root.popupOpen ? 1 : 0.84

                transform: Scale {
                    origin.x: clipper.width / 2
                    origin.y: 0
                    xScale: clipper.neck
                }

                Behavior on reveal {
                    NumberAnimation {
                        duration: root.popupOpen ? 400 : 190
                        easing.type: root.popupOpen ? Easing.OutBack : Easing.InCubic
                        easing.overshoot: 0.55
                    }
                }

                Behavior on neck {
                    NumberAnimation {
                        duration: root.popupOpen ? 440 : 170
                        easing.type: root.popupOpen ? Easing.OutBack : Easing.InCubic
                        easing.overshoot: 0.9
                    }
                }

                Rectangle {
                    id: card

                    // Lifted by one radius so its rounded top sits above the
                    // clip line — only the free-hanging bottom edge stays
                    // rounded.
                    y: -root.cardRadius
                    width: parent.width
                    // Tracks the reveal exactly, so the overshoot elongates
                    // the card instead of exposing a gap beneath it.
                    height: clipper.reveal + root.cardRadius

                    color: root.glass
                    border.color: root.glassBorder
                    border.width: 1
                    radius: root.cardRadius
                    antialiasing: true

                    ColumnLayout {
                        id: content

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: root.padding
                        // Offsets the card's lift, keeping the content padded
                        // from the visible top edge rather than the hidden one.
                        anchors.topMargin: root.padding + root.cardRadius
                        spacing: 12

                        opacity: root.popupOpen ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: root.popupOpen ? 200 : 120
                                easing.type: Easing.OutCubic
                            }
                        }

                        // ─── header ──────────────────────────────────────

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.alignment: Qt.AlignVCenter
                                width: 7
                                height: 7
                                radius: 999
                                antialiasing: true
                                color: Pipewire.defaultAudioSink && !Pipewire.defaultAudioSink.audio.muted ? root.accent : root.muted
                            }

                            Label {
                                Layout.fillWidth: true
                                text: "Audio"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }

                            PillButton {
                                label: "󰅖"
                                compact: true
                                onTriggered: root.closePopup()
                            }
                        }

                        // ─── outputs ─────────────────────────────────────

                        SectionLabel {
                            caption: "Output"
                            count: root.sinks.length
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: root.sinks

                                delegate: DeviceRow {
                                    required property var modelData

                                    node: modelData
                                    isSink: true
                                    selected: root.isDefaultSink(modelData)
                                    onSelectRequested: Pipewire.preferredDefaultAudioSink = modelData
                                }
                            }
                        }

                        // ─── inputs ──────────────────────────────────────

                        SectionLabel {
                            caption: "Input"
                            count: root.sources.length
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                model: root.sources

                                delegate: DeviceRow {
                                    required property var modelData

                                    node: modelData
                                    isSink: false
                                    selected: root.isDefaultSource(modelData)
                                    onSelectRequested: Pipewire.preferredDefaultAudioSource = modelData
                                }
                            }
                        }

                        // ─── per-application streams ─────────────────────

                        SectionLabel {
                            caption: "Apps"
                            count: root.streams.length
                            visible: root.streams.length > 0
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.streams.length > 0
                            spacing: 6

                            Repeater {
                                model: root.streams

                                delegate: DeviceRow {
                                    required property var modelData

                                    node: modelData
                                    isSink: true
                                    isStream: true
                                    label: root.streamTitle(modelData)
                                    sublabel: root.streamLabel(modelData)
                                    glyph: "󰝚"
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ─── shared components ───────────────────────────────────────────

    component Label: Text {
        font.family: root.fontFamily
        font.weight: Font.Medium
        color: root.text
        renderType: Text.NativeRendering
    }

    component Glyph: Text {
        font.family: root.iconFamily
        color: root.text

        // Not NativeRendering, unlike the text components above: the
        // native rasteriser hints icon outlines onto the pixel grid and
        // at these sizes the thin gaps inside a glyph snap shut, which
        // turns headphones and wifi fans into smears of bars.
        renderType: Text.QtRendering
    }

    component SectionLabel: RowLayout {
        id: section

        property string caption: ""
        property int count: 0

        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 6

        Label {
            text: section.caption
            font.pixelSize: 9
            font.weight: Font.DemiBold
            color: root.muted
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            implicitHeight: 1
            color: root.divider
        }

        Label {
            text: section.count
            font.pixelSize: 9
            color: root.muted
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

        readonly property string rowLabel: label.length > 0 ? label : root.deviceLabel(node)
        readonly property string rowGlyph: glyph.length > 0 ? glyph : root.deviceIcon(node, isSink)
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
                return rowHover.containsMouse ? root.selectedTintHover : root.selectedTint;
            return rowHover.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05);
        }

        Behavior on color {
            ColorAnimation {
                duration: 140
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
                    color: row.selected ? root.accent : root.text
                    opacity: row.isMuted ? 0.4 : 1
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Label {
                        Layout.fillWidth: true
                        text: row.rowLabel
                        font.pixelSize: 11
                        font.weight: row.selected ? Font.DemiBold : Font.Medium
                        elide: Text.ElideRight
                        opacity: row.isMuted ? 0.5 : 1
                    }

                    Label {
                        Layout.fillWidth: true
                        text: row.sublabel
                        visible: text.length > 0 && text !== row.rowLabel
                        font.pixelSize: 9
                        color: root.muted
                        elide: Text.ElideRight
                    }
                }

                Label {
                    text: root.volumePercent(row.node) + "%"
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: row.isMuted ? root.muted : root.text
                }

                PillButton {
                    label: row.muteGlyph
                    compact: true
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
            color: root.pill

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * slider.value
                radius: 999
                antialiasing: true
                color: slider.dimmed ? root.muted : root.accent

                Behavior on width {
                    enabled: !drag.pressed

                    NumberAnimation {
                        duration: 140
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

            color: slider.dimmed ? root.muted : root.accent
            border.width: 1
            border.color: root.pillHoverBorder
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

    component PillButton: Item {
        id: button

        signal triggered

        property string label: ""
        property bool wide: false
        property bool compact: false
        property bool highlighted: false

        implicitWidth: wide ? 64 : 28
        implicitHeight: 28
        opacity: enabled ? 1 : 0.32

        Behavior on opacity {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            id: surface

            anchors.fill: parent
            radius: 999
            antialiasing: true

            color: {
                if (button.highlighted)
                    return mouse.containsMouse ? root.accent : root.accentSoft;
                return mouse.containsMouse ? root.pillHover : root.pill;
            }
            border.width: 1
            border.color: mouse.containsMouse ? root.pillHoverBorder : root.pillBorder

            scale: mouse.pressed && button.enabled ? 0.93 : 1

            Behavior on color {
                ColorAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 110
                    easing.type: Easing.OutCubic
                }
            }
        }

        Glyph {
            anchors.centerIn: parent
            text: button.label
            font.pixelSize: button.compact ? 11 : 15
            scale: surface.scale
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            hoverEnabled: true
            enabled: button.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: button.triggered()
        }
    }
}
