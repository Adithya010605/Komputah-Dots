pragma ComponentBehavior: Bound

import QtQml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris

ShellRoot {
    id: root

    // ─── open / close state ──────────────────────────────────────────
    property bool popupOpen: true
    property bool popupRendered: true

    // Horizontal centre the card aims for, written by the waybar launcher
    // from the cursor position so the panel drops out of the icon you clicked.
    property real anchorX: 960

    // Which player the hero section is driving. Held by identity rather than
    // index so it survives players appearing and disappearing underneath it.
    property string activeId: ""

    // ─── geometry ────────────────────────────────────────────────────
    // Layers anchored to the top are already placed below waybar's exclusive
    // zone, so nothing here needs to know the bar's height.
    readonly property int edgeMargin: 8
    readonly property int cardWidth: 348
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

    readonly property int cardRadius: 26
    readonly property int padding: 16
    readonly property int artRadius: 14

    // One player card: artwork row, progress, transport. Fixed so the deck can
    // snap a whole card at a time.
    readonly property int deckHeight: 152

    // Proportional face for everything readable, the Nerd Font purely for
    // glyphs — same split as the pomodoro panel.
    readonly property string fontFamily: "Adwaita Sans"
    readonly property string iconFamily: "GeistMono Nerd Font"

    // ─── players ─────────────────────────────────────────────────────

    readonly property var players: Mpris.players.values

    readonly property var active: {
        const list = players;
        if (list.length === 0)
            return null;

        for (const player of list) {
            if (playerId(player) === root.activeId)
                return player;
        }

        return list[0];
    }

    function playerId(player) {
        return player ? (player.dbusName || player.identity || "") : "";
    }

    function playerIcon(player) {
        const name = (playerId(player) + " " + (player && player.identity ? player.identity : "")).toLowerCase();

        if (name.includes("spotify"))
            return "󰝚";
        if (name.includes("firefox") || name.includes("zen"))
            return "󰈹";
        if (name.includes("chrom"))
            return "󰊯";
        if (name.includes("vlc") || name.includes("mpv"))
            return "󰕼";
        return "󰎇";
    }

    function trackTitle(player) {
        if (!player)
            return "";
        return player.trackTitle && player.trackTitle.length > 0 ? player.trackTitle : (player.identity || "Unknown track");
    }

    function trackSubtitle(player) {
        if (!player)
            return "";

        const parts = [];
        if (player.trackArtist && player.trackArtist.length > 0)
            parts.push(player.trackArtist);
        if (player.trackAlbum && player.trackAlbum.length > 0 && player.trackAlbum !== player.trackArtist)
            parts.push(player.trackAlbum);

        return parts.join(" · ");
    }

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds <= 0)
            return "0:00";

        const total = Math.floor(seconds);
        const mins = Math.floor(total / 60);
        return mins + ":" + String(total % 60).padStart(2, "0");
    }

    // Position does not notify on its own, so it is re-read on a tick.
    property int positionTick: 0

    function livePosition(player) {
        positionTick;
        return player && player.positionSupported ? player.position : 0;
    }

    function progressOf(player) {
        if (!player || !player.lengthSupported || !player.positionSupported)
            return 0;
        if (!(player.length > 0))
            return 0;

        return Math.max(0, Math.min(1, livePosition(player) / player.length));
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

    // When did each player last start playing. D-Bus order says nothing about
    // what you are actually listening to, so recency decides instead.
    property var startedAt: ({})

    function markStarted(id) {
        if (id.length === 0)
            return;

        const stamps = root.startedAt;
        stamps[id] = Date.now();
        root.startedAt = stamps;
    }

    Instantiator {
        model: Mpris.players

        delegate: QtObject {
            required property var modelData

            readonly property bool sounding: modelData.isPlaying

            onSoundingChanged: {
                if (sounding)
                    root.markStarted(root.playerId(modelData));
            }

            Component.onCompleted: {
                if (sounding)
                    root.markStarted(root.playerId(modelData));
            }
        }
    }

    // Opening should land on whatever is actually making noise — and when
    // several are, on the one started most recently.
    function selectSounding() {
        const list = players;
        if (list.length === 0)
            return;

        let target = -1;
        let best = -1;

        for (let i = 0; i < list.length; i++) {
            if (!list[i].isPlaying)
                continue;

            const stamp = root.startedAt[playerId(list[i])] ?? 0;
            if (stamp >= best) {
                best = stamp;
                target = i;
            }
        }

        // Nothing playing at all: fall back to the most recent thing that was.
        if (target < 0) {
            for (let i = 0; i < list.length; i++) {
                const stamp = root.startedAt[playerId(list[i])] ?? 0;
                if (stamp >= best) {
                    best = stamp;
                    target = i;
                }
            }
        }

        if (target < 0)
            target = 0;

        root.activeId = playerId(list[target]);
        if (deck)
            deck.currentIndex = target;
    }

    function openPopup() {
        root.popupRendered = true;
        root.popupOpen = true;
        selectSounding();
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
                console.warn("media: could not parse wal colors");
            }
        }
    }

    FileView {
        id: anchorFile

        path: "/tmp/media_popup_x"
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

    Timer {
        interval: 1000
        running: root.popupRendered
        repeat: true
        onTriggered: root.positionTick++
    }

    IpcHandler {
        target: "media"

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

    PanelWindow {
        id: catcher

        visible: root.popupRendered
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.namespace: "quickshell-media-catcher"
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

        WlrLayershell.namespace: "quickshell-media"
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
                                color: root.active && root.active.isPlaying ? root.accent : root.muted

                                SequentialAnimation on opacity {
                                    running: root.active !== null && root.active.isPlaying
                                    loops: Animation.Infinite
                                    alwaysRunToEnd: true

                                    NumberAnimation { to: 0.30; duration: 950; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.00; duration: 950; easing.type: Easing.InOutSine }
                                }
                            }

                            Label {
                                Layout.fillWidth: true
                                text: root.players.length === 0 ? "Nothing playing" : (root.active && root.active.isPlaying ? "Now playing" : "Paused")
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }

                            PillButton {
                                label: "󰅖"
                                compact: true
                                onTriggered: root.closePopup()
                            }
                        }

                        // ─── the players ─────────────────────────────────
                        //
                        // One full card per source, snapped one at a time, with
                        // a dot rail alongside standing in for the count.

                        RowLayout {
                            Layout.fillWidth: true
                            visible: root.players.length > 0
                            spacing: 10

                            ListView {
                                id: deck

                                Layout.fillWidth: true
                                Layout.preferredHeight: root.deckHeight

                                model: Mpris.players
                                clip: true
                                orientation: ListView.Vertical
                                snapMode: ListView.SnapOneItem
                                highlightRangeMode: ListView.StrictlyEnforceRange
                                preferredHighlightBegin: 0
                                preferredHighlightEnd: root.deckHeight
                                boundsBehavior: Flickable.StopAtBounds
                                highlightMoveDuration: 260
                                cacheBuffer: root.deckHeight * 3
                                interactive: count > 1
                                maximumFlickVelocity: 1800

                                // A wheel notch should step exactly one card
                                // rather than throwing the deck across several.
                                WheelHandler {
                                    enabled: deck.count > 1
                                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

                                    onWheel: event => {
                                        if (event.angleDelta.y < 0)
                                            deck.incrementCurrentIndex();
                                        else if (event.angleDelta.y > 0)
                                            deck.decrementCurrentIndex();
                                    }
                                }

                                // Scrolling the deck is what picks a player, so
                                // the dots and the rest of the panel follow it.
                                onCurrentIndexChanged: {
                                    const list = root.players;
                                    if (currentIndex >= 0 && currentIndex < list.length)
                                        root.activeId = root.playerId(list[currentIndex]);
                                }

                                delegate: Item {
                                    id: entry

                                    required property var modelData

                                    width: deck.width
                                    height: root.deckHeight

                                    ColumnLayout {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 10

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 12

                                            Artwork {
                                                Layout.alignment: Qt.AlignVCenter
                                                size: 76
                                                radius: root.artRadius
                                                source: entry.modelData.trackArtUrl
                                                glyph: root.playerIcon(entry.modelData)
                                                glyphSize: 26
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.alignment: Qt.AlignVCenter
                                                spacing: 3

                                                Label {
                                                    Layout.fillWidth: true
                                                    text: root.trackTitle(entry.modelData)
                                                    font.pixelSize: 14
                                                    font.weight: Font.DemiBold
                                                    elide: Text.ElideRight
                                                    maximumLineCount: 2
                                                    wrapMode: Text.Wrap
                                                }

                                                Label {
                                                    Layout.fillWidth: true
                                                    text: root.trackSubtitle(entry.modelData)
                                                    visible: text.length > 0
                                                    font.pixelSize: 11
                                                    color: root.muted
                                                    elide: Text.ElideRight
                                                }

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    Layout.topMargin: 2
                                                    spacing: 5

                                                    Glyph {
                                                        text: entry.modelData.isPlaying ? "󰎇" : "󰏤"
                                                        font.pixelSize: 9
                                                        color: entry.modelData.isPlaying ? root.accent : root.muted
                                                    }

                                                    Label {
                                                        Layout.fillWidth: true
                                                        text: entry.modelData.identity || ""
                                                        visible: text.length > 0
                                                        font.pixelSize: 9
                                                        color: root.muted
                                                        elide: Text.ElideRight
                                                    }
                                                }
                                            }
                                        }

                                        // ─── progress ────────────────────

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            visible: entry.modelData.lengthSupported && entry.modelData.length > 0
                                            spacing: 5

                                            Rectangle {
                                                Layout.fillWidth: true
                                                implicitHeight: 3
                                                radius: 999
                                                antialiasing: true
                                                color: root.pill

                                                Rectangle {
                                                    anchors.left: parent.left
                                                    anchors.top: parent.top
                                                    anchors.bottom: parent.bottom
                                                    width: parent.width * root.progressOf(entry.modelData)
                                                    radius: 999
                                                    antialiasing: true
                                                    color: root.accent

                                                    Behavior on width {
                                                        NumberAnimation {
                                                            duration: 420
                                                            easing.type: Easing.OutCubic
                                                        }
                                                    }
                                                }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true

                                                Label {
                                                    text: root.formatTime(entry.modelData.positionSupported ? root.livePosition(entry.modelData) : 0)
                                                    font.pixelSize: 9
                                                    color: root.muted
                                                }

                                                Item { Layout.fillWidth: true }

                                                Label {
                                                    text: root.formatTime(entry.modelData.length)
                                                    font.pixelSize: 9
                                                    color: root.muted
                                                }
                                            }
                                        }

                                        // ─── transport ───────────────────

                                        RowLayout {
                                            Layout.alignment: Qt.AlignHCenter
                                            spacing: 8

                                            PillButton {
                                                label: "󰒮"
                                                compact: true
                                                enabled: entry.modelData.canGoPrevious
                                                onTriggered: entry.modelData.previous()
                                            }

                                            PillButton {
                                                label: entry.modelData.isPlaying ? "󰏤" : "󰐊"
                                                wide: true
                                                highlighted: true
                                                enabled: entry.modelData.canTogglePlaying
                                                onTriggered: entry.modelData.togglePlaying()
                                            }

                                            PillButton {
                                                label: "󰒭"
                                                compact: true
                                                enabled: entry.modelData.canGoNext
                                                onTriggered: entry.modelData.next()
                                            }
                                        }
                                    }
                                }
                            }

                            // ─── dot rail ────────────────────────────────

                            ColumnLayout {
                                Layout.alignment: Qt.AlignVCenter
                                visible: root.players.length > 1
                                spacing: 6

                                Repeater {
                                    model: Mpris.players

                                    delegate: Rectangle {
                                        id: dot

                                        required property var modelData
                                        required property int index

                                        readonly property bool isCurrent: index === deck.currentIndex

                                        implicitWidth: 6
                                        implicitHeight: dot.isCurrent ? 16 : 6
                                        radius: 999
                                        antialiasing: true

                                        color: {
                                            if (dot.isCurrent)
                                                return root.accent;
                                            return modelData.isPlaying ? root.accentSoft : root.pill;
                                        }

                                        Behavior on implicitHeight {
                                            NumberAnimation {
                                                duration: 220
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        Behavior on color {
                                            ColorAnimation {
                                                duration: 180
                                                easing.type: Easing.OutCubic
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -5
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: deck.currentIndex = dot.index
                                        }
                                    }
                                }
                            }
                        }

                        // ─── empty state ─────────────────────────────────

                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: root.players.length === 0
                            spacing: 6

                            Glyph {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 6
                                text: "󰝛"
                                font.pixelSize: 30
                                color: root.muted
                            }

                            Label {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.bottomMargin: 6
                                text: "No media players running"
                                font.pixelSize: 10
                                color: root.muted
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

    // Album art, falling back to the player's own glyph when a track carries
    // no artwork — plenty of browser sources do not.
    component Artwork: ClippingRectangle {
        id: art

        property int size: 76
        property string source: ""
        property string glyph: ""
        property int glyphSize: 26

        implicitWidth: size
        implicitHeight: size
        color: root.pill
        border.color: root.pillBorder
        border.width: 1
        antialiasing: true

        Glyph {
            anchors.centerIn: parent
            visible: image.status !== Image.Ready
            text: art.glyph
            font.pixelSize: art.glyphSize
            color: root.muted
        }

        Image {
            id: image

            anchors.fill: parent
            source: art.source
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: art.size * 2
            sourceSize.height: art.size * 2
            visible: status === Image.Ready
        }
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
}
