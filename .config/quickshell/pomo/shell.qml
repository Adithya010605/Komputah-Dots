pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "services" as Pomo

ShellRoot {
    id: root

    // ─── open / close state ──────────────────────────────────────────
    property bool popupOpen: true
    property bool popupRendered: true

    // Horizontal centre the card aims for, written by the waybar launcher
    // from the cursor position so the panel drops out of the icon you clicked.
    property real anchorX: 960

    // ─── geometry ────────────────────────────────────────────────────
    // Layers anchored to the top are already placed below waybar's exclusive
    // zone, so nothing here needs to know the bar's height.
    readonly property int edgeMargin: 8
    readonly property int cardWidth: 302
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

    // Heat scale for the week strip: empty cells are barely-there white, the
    // rest ramp darker -> lighter in the accent, GitHub-style.
    readonly property color heatEmpty: Qt.rgba(1, 1, 1, 0.07)
    readonly property color heatFuture: Qt.rgba(1, 1, 1, 0.035)
    readonly property var heatScale: [withAlpha(pick("color12", "#8fb3a1"), 0.26), withAlpha(pick("color12", "#8fb3a1"), 0.46), withAlpha(pick("color12", "#8fb3a1"), 0.68), withAlpha(pick("color12", "#8fb3a1"), 0.92)]

    readonly property int cardRadius: 26
    readonly property int padding: 16

    // Seven square cells plus even gaps, sized to the card so the strip and
    // the stat row below it share one grid.
    readonly property int cellGap: 6
    readonly property int cellSize: Math.floor((cardWidth - padding * 2 - cellGap * 6) / 7)

    // Proportional face for everything readable, mono kept for the countdown
    // (stable digit widths) and the Nerd Font purely for glyphs.
    readonly property string fontFamily: "Adwaita Sans"
    readonly property string monoFamily: "GeistMono Nerd Font"
    readonly property string iconFamily: "GeistMono Nerd Font"

    function heatColor(entry) {
        if (entry.future)
            return heatFuture;

        const level = Pomo.PomoService.heatLevel(entry.minutes);
        return level === 0 ? heatEmpty : heatScale[level - 1];
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
        Pomo.PomoService.refresh();
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
                console.warn("pomo: could not parse wal colors");
            }
        }
    }

    FileView {
        id: anchorFile

        path: "/tmp/break_popup_x"
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
        target: "pomo"

        // The launcher hands over the cursor x it captured, so the panel
        // lines up with whatever icon was clicked.
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
    // Stops below the bar, keeping the waybar icon clickable for toggling.

    PanelWindow {
        id: catcher

        visible: root.popupRendered
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.namespace: "quickshell-pomo-catcher"
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

        WlrLayershell.namespace: "quickshell-pomo"
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
                        spacing: 14

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
                                color: Pomo.PomoService.running ? root.accent : root.muted
                                opacity: 1

                                SequentialAnimation on opacity {
                                    running: Pomo.PomoService.running && !Pomo.PomoService.paused
                                    loops: Animation.Infinite
                                    alwaysRunToEnd: true

                                    NumberAnimation { to: 0.30; duration: 950; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.00; duration: 950; easing.type: Easing.InOutSine }
                                }
                            }

                            Label {
                                Layout.fillWidth: true
                                text: Pomo.PomoService.label
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }

                            PillButton {
                                label: "󰅖"
                                compact: true
                                onTriggered: root.closePopup()
                            }
                        }

                        // ─── dial ────────────────────────────────────────

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 132
                            Layout.preferredHeight: 132

                            Canvas {
                                id: ring

                                anchors.fill: parent

                                property real progress: Pomo.PomoService.progress
                                property color trackColor: root.pill
                                property color fillColor: Pomo.PomoService.paused ? root.accentSoft : root.accent

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

                                Label {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: Pomo.PomoService.formatTime(Pomo.PomoService.timeLeft)
                                    font.family: root.monoFamily
                                    font.pixelSize: 30
                                    font.weight: Font.DemiBold
                                }

                                Label {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: Pomo.PomoService.presetMinutes + " min"
                                    font.pixelSize: 11
                                    color: root.muted
                                }
                            }
                        }

                        // ─── controls ────────────────────────────────────

                        RowLayout {
                            Layout.alignment: Qt.AlignHCenter
                            spacing: 8

                            PillButton {
                                label: "󰍴"
                                compact: true
                                enabled: !Pomo.PomoService.running
                                onTriggered: Pomo.PomoService.presetPrev()
                            }

                            PillButton {
                                label: Pomo.PomoService.running && !Pomo.PomoService.paused ? "󰏤" : "󰐊"
                                wide: true
                                highlighted: true
                                onTriggered: Pomo.PomoService.toggle()
                            }

                            PillButton {
                                label: "󰜉"
                                compact: true
                                enabled: Pomo.PomoService.running
                                onTriggered: Pomo.PomoService.reset()
                            }

                            PillButton {
                                label: "󰐕"
                                compact: true
                                enabled: !Pomo.PomoService.running
                                onTriggered: Pomo.PomoService.presetNext()
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            implicitHeight: 1
                            color: root.divider
                        }

                        // ─── headline stats ──────────────────────────────

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: root.cellGap

                            Stat {
                                caption: "today"
                                value: Pomo.PomoService.formatDuration(Pomo.PomoService.todayMinutes)
                            }

                            Stat {
                                caption: "this week"
                                value: Pomo.PomoService.formatDuration(Pomo.PomoService.weekMinutes)
                            }

                            Stat {
                                caption: "streak"
                                value: Pomo.PomoService.streak + "d"
                                accented: Pomo.PomoService.streak > 0
                            }
                        }

                        // ─── the week, Sun -> Sat ────────────────────────

                        ColumnLayout {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 2
                            spacing: 6

                            RowLayout {
                                Layout.alignment: Qt.AlignHCenter
                                spacing: root.cellGap

                                Repeater {
                                    model: Pomo.PomoService.weekCalendar

                                    delegate: Rectangle {
                                        id: cell

                                        required property var modelData

                                        implicitWidth: root.cellSize
                                        implicitHeight: root.cellSize
                                        radius: 8
                                        antialiasing: true

                                        color: root.heatColor(modelData)
                                        border.width: modelData.today ? 1 : 0
                                        border.color: root.pillHoverBorder

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
                                spacing: root.cellGap

                                Repeater {
                                    model: Pomo.PomoService.weekCalendar

                                    delegate: Label {
                                        required property var modelData

                                        Layout.preferredWidth: root.cellSize
                                        horizontalAlignment: Text.AlignHCenter
                                        text: modelData.day.charAt(0)
                                        font.pixelSize: 9
                                        color: modelData.today ? root.text : root.muted
                                    }
                                }
                            }
                        }

                        // ─── all time ────────────────────────────────────

                        Label {
                            Layout.fillWidth: true
                            Layout.topMargin: 2
                            horizontalAlignment: Text.AlignHCenter
                            text: Pomo.PomoService.totalSessions + " sessions · " + Pomo.PomoService.formatDuration(Pomo.PomoService.totalMinutes) + " · " + Pomo.PomoService.activeDays + " days"
                            font.pixelSize: 10
                            color: root.muted
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
        renderType: Text.NativeRendering
    }

    component PillButton: Item {
        id: button

        signal triggered

        property string label: ""
        property bool wide: false
        property bool compact: false
        property bool highlighted: false

        implicitWidth: wide ? 64 : 34
        implicitHeight: 34
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

            Behavior on border.color {
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
            font.pixelSize: button.compact ? 13 : 15
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

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: stat.value
                font.pixelSize: 15
                font.weight: Font.DemiBold
                color: stat.accented ? root.accent : root.text
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                text: stat.caption
                font.pixelSize: 9
                color: root.muted
            }
        }
    }
}
