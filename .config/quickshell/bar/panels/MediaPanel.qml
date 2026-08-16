pragma ComponentBehavior: Bound

import QtQml
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Mpris
import "root:/"
import "root:/components"

// One card per player, snapped a whole card at a time, with a dot rail
// standing in for the count.
DripPanel {
    id: panel

    name: "media"
    panelWidth: 348

    readonly property int artRadius: 14

    // One player card: artwork row, progress, transport. Fixed so the deck can
    // snap a whole card at a time.
    readonly property int deckHeight: 152

    // Position does not notify on its own, so it is re-read on a tick.
    property int positionTick: 0

    // Which card the deck is showing. Mirrored out to the shared player state
    // so the bar's title follows what you scrolled to.
    property int deckIndex: 0

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

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds <= 0)
            return "0:00";

        const total = Math.floor(seconds);
        const mins = Math.floor(total / 60);
        return mins + ":" + String(total % 60).padStart(2, "0");
    }

    Timer {
        interval: 1000
        running: panel.rendered
        repeat: true
        onTriggered: panel.positionTick++
    }

    // Opening should land on whatever is actually making noise.
    Connections {
        target: PanelState

        function onOpened(name) {
            if (name !== panel.name)
                return;

            Players.selectSounding();
            panel.deckIndex = Players.soundingIndex();
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
                    color: Players.active && Players.active.isPlaying ? Theme.accent : Theme.muted

                    SequentialAnimation on opacity {
                        running: Players.active !== null && Players.active.isPlaying
                        loops: Animation.Infinite
                        alwaysRunToEnd: true

                        NumberAnimation { to: 0.30; duration: 950; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.00; duration: 950; easing.type: Easing.InOutSine }
                    }
                }

                PanelText {
                    Layout.fillWidth: true
                    text: Players.players.length === 0 ? "Nothing playing" : (Players.active && Players.active.isPlaying ? "Now playing" : "Paused")
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                PillButton {
                    label: "󰅖"
                    compact: true
                    onTriggered: PanelState.close()
                }
            }

            // ─── the players ─────────────────────────────────────────

            RowLayout {
                Layout.fillWidth: true
                visible: Players.players.length > 0
                spacing: 10

                ListView {
                    id: deck

                    Layout.fillWidth: true
                    Layout.preferredHeight: panel.deckHeight

                    model: Mpris.players
                    clip: true
                    orientation: ListView.Vertical
                    snapMode: ListView.SnapOneItem
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: 0
                    preferredHighlightEnd: panel.deckHeight
                    boundsBehavior: Flickable.StopAtBounds
                    highlightMoveDuration: 260
                    cacheBuffer: panel.deckHeight * 3
                    interactive: count > 1
                    maximumFlickVelocity: 1800

                    currentIndex: panel.deckIndex

                    // A wheel notch should step exactly one card rather than
                    // throwing the deck across several.
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

                    // Scrolling the deck is what picks a player, so the dots
                    // and the bar's own title follow it.
                    onCurrentIndexChanged: {
                        panel.deckIndex = currentIndex;

                        const list = Players.players;
                        if (currentIndex >= 0 && currentIndex < list.length)
                            Players.activeId = Players.playerId(list[currentIndex]);
                    }

                    delegate: Item {
                        id: entry

                        required property var modelData

                        width: deck.width
                        height: panel.deckHeight

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
                                    radius: panel.artRadius
                                    source: entry.modelData.trackArtUrl
                                    glyph: Players.playerIcon(entry.modelData)
                                    glyphSize: 26
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 3

                                    PanelText {
                                        Layout.fillWidth: true
                                        text: Players.trackTitle(entry.modelData)
                                        font.pixelSize: 14
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        maximumLineCount: 2
                                        wrapMode: Text.Wrap
                                    }

                                    PanelText {
                                        Layout.fillWidth: true
                                        text: Players.trackSubtitle(entry.modelData)
                                        visible: text.length > 0
                                        font.pixelSize: 11
                                        color: Theme.muted
                                        elide: Text.ElideRight
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.topMargin: 2
                                        spacing: 5

                                        Glyph {
                                            text: entry.modelData.isPlaying ? "󰎇" : "󰏤"
                                            font.pixelSize: 9
                                            color: entry.modelData.isPlaying ? Theme.accent : Theme.muted
                                        }

                                        PanelText {
                                            Layout.fillWidth: true
                                            text: entry.modelData.identity || ""
                                            visible: text.length > 0
                                            font.pixelSize: 9
                                            color: Theme.muted
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }

                            // ─── progress ────────────────────────────

                            ColumnLayout {
                                Layout.fillWidth: true
                                visible: entry.modelData.lengthSupported && entry.modelData.length > 0
                                spacing: 5

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 3
                                    radius: 999
                                    antialiasing: true
                                    color: Theme.pill

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom
                                        width: parent.width * panel.progressOf(entry.modelData)
                                        radius: 999
                                        antialiasing: true
                                        color: Theme.accent

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

                                    PanelText {
                                        text: panel.formatTime(entry.modelData.positionSupported ? panel.livePosition(entry.modelData) : 0)
                                        font.pixelSize: 9
                                        color: Theme.muted
                                    }

                                    Item { Layout.fillWidth: true }

                                    PanelText {
                                        text: panel.formatTime(entry.modelData.length)
                                        font.pixelSize: 9
                                        color: Theme.muted
                                    }
                                }
                            }

                            // ─── transport ───────────────────────────

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

                // ─── dot rail ────────────────────────────────────────

                ColumnLayout {
                    Layout.alignment: Qt.AlignVCenter
                    visible: Players.players.length > 1
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
                                    return Theme.accent;
                                return modelData.isPlaying ? Theme.accentSoft : Theme.pill;
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

            // ─── empty state ─────────────────────────────────────────

            ColumnLayout {
                Layout.fillWidth: true
                visible: Players.players.length === 0
                spacing: 6

                // Filled and aligned rather than Layout.alignment: the latter
                // centres within the column's own width, which is not the
                // panel's width unless every ancestor stretched.
                Glyph {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    horizontalAlignment: Text.AlignHCenter
                    text: "󰝛"
                    font.pixelSize: 30
                    color: Theme.muted
                }

                PanelText {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 6
                    horizontalAlignment: Text.AlignHCenter
                    text: "No media players running"
                    font.pixelSize: 10
                    color: Theme.muted
                }
            }
        }
    }

    // Album art, falling back to the player's own glyph when a track carries no
    // artwork — plenty of browser sources do not.
    component Artwork: ClippingRectangle {
        id: art

        property int size: 76
        property string source: ""
        property string glyph: ""
        property int glyphSize: 26

        implicitWidth: size
        implicitHeight: size
        color: Theme.pill
        border.color: Theme.pillBorder
        border.width: 1
        antialiasing: true

        Glyph {
            anchors.centerIn: parent
            visible: image.status !== Image.Ready
            text: art.glyph
            font.pixelSize: art.glyphSize
            color: Theme.muted
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
}
