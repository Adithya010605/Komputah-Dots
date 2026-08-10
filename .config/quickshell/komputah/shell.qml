import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

ShellRoot {
    id: root

    property var activePlayer: null
    property bool mediaOpen: false
    property bool pomoOpen: false
    property bool audioOpen: false
    property var pomo: ({
        "preset": 25,
        "running": false,
        "paused": false,
        "remaining": 1500,
        "todayCount": 0,
        "todayMinutes": 0
    })
    property string outputIcon: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && Pipewire.defaultAudioSink.audio.muted ? "󰝟" : "󰕾"
    property int outputPercent: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Math.round(Pipewire.defaultAudioSink.audio.volume * 100) : 0

    function closePopovers(except) {
        if (except !== "media")
            mediaOpen = false;

        if (except !== "pomo")
            pomoOpen = false;

        if (except !== "audio")
            audioOpen = false;

    }

    function runPomo(action, value) {
        let command = ["bash", Quickshell.shellPath("scripts/pomodoro.sh"), action];
        if (value !== undefined)
            command.push(String(value));

        Quickshell.execDetached(command);
        pomoPoll.restart();
    }

    function formatDuration(seconds) {
        const safe = Math.max(0, seconds || 0);
        return Math.floor(safe / 60).toString().padStart(2, "0") + ":" + (safe % 60).toString().padStart(2, "0");
    }

    function formatStudyTime(minutes) {
        const hours = Math.floor(minutes / 60);
        const remainder = minutes % 60;
        return hours > 0 ? hours + "h " + remainder + "m" : remainder + "m";
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    Process {
        id: pomoStatus

        command: ["bash", Quickshell.shellPath("scripts/pomodoro.sh"), "status"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.pomo = JSON.parse(text);
                } catch (error) {
                    console.warn("Invalid Pomodoro status:", error);
                }
            }
        }

    }

    Timer {
        id: pomoPoll

        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            if (!pomoStatus.running)
                pomoStatus.running = true;

        }
    }

    PanelWindow {
        id: panel

        margins.top: 9
        exclusiveZone: 52
        implicitHeight: 52
        color: "transparent"

        anchors {
            top: true
            left: true
            right: true
        }

        Rectangle {
            id: bar

            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(1450, parent.width - 28)
            height: 43
            radius: height / 2
            color: "#5714141c"
            border.color: "#33ffffff"
            border.width: 1

            RowLayout {
                anchors.centerIn: parent
                spacing: 7

                GlassChip {
                    text: Hyprland.activeToplevel ? Hyprland.activeToplevel.appId : "Desktop"
                    width: 126
                }

                Text {
                    text: "|"
                    color: "#88ffffff"
                    font.pixelSize: 15
                }

                GlassChip {
                    text: "󰍹  " + (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.name : "1")
                    width: 122
                    accent: true
                }

                Text {
                    text: "|"
                    color: "#88ffffff"
                    font.pixelSize: 15
                }

                GlassChip {
                    id: mediaChip

                    width: 245
                    clickable: true
                    text: root.activePlayer ? (root.activePlayer.isPlaying ? "  " : "󰏤  ") + (root.activePlayer.trackTitle || root.activePlayer.identity) : "  Nothing playing"
                    onClicked: {
                        root.mediaOpen = !root.mediaOpen;
                        root.closePopovers("media");
                    }
                }

                Text {
                    text: "|"
                    color: "#88ffffff"
                    font.pixelSize: 15
                }

                GlassChip {
                    width: 105
                    text: Qt.formatTime(new Date(), "hh:mm AP")
                }

                GlassChip {
                    id: pomoChip

                    width: 104
                    clickable: true
                    text: root.pomo.running ? (root.pomo.paused ? "󰏤 " : "󰔟 ") + root.formatDuration(root.pomo.remaining) : "󰔟 " + root.pomo.preset + "m"
                    onClicked: {
                        root.pomoOpen = !root.pomoOpen;
                        root.closePopovers("pomo");
                    }
                }

                GlassChip {
                    id: audioChip

                    width: 92
                    clickable: true
                    text: root.outputIcon + "  " + root.outputPercent + "%"
                    onClicked: {
                        root.audioOpen = !root.audioOpen;
                        root.closePopovers("audio");
                    }
                }

            }

        }

        PopupWindow {
            anchor.window: panel
            anchor.rect.x: bar.x + mediaChip.x - 74
            anchor.rect.y: bar.y + bar.height + 8
            width: 394
            height: 248
            visible: root.mediaOpen
            color: "transparent"

            GlassCard {
                anchors.fill: parent
                anchors.margins: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 16

                    Rectangle {
                        Layout.preferredWidth: 132
                        Layout.preferredHeight: 132
                        radius: 16
                        color: "#1fffffff"
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: root.activePlayer ? root.activePlayer.trackArtUrl : ""
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                        }

                        Text {
                            anchors.centerIn: parent
                            text: ""
                            font.family: "GeistMono Nerd Font"
                            font.pixelSize: 38
                            color: "#b3ffffff"
                        }

                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 7

                        Text {
                            Layout.fillWidth: true
                            text: root.activePlayer ? (root.activePlayer.trackTitle || "Unknown title") : "Nothing is playing"
                            color: "white"
                            font.family: "GeistMono Nerd Font"
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.activePlayer ? (root.activePlayer.trackArtist || root.activePlayer.identity) : "Start a player to see it here"
                            color: "#b3ffffff"
                            font.family: "GeistMono Nerd Font"
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        Item {
                            Layout.fillHeight: true
                        }

                        RowLayout {
                            spacing: 10

                            ControlButton {
                                label: "󰒮"
                                enabled: root.activePlayer && root.activePlayer.canGoPrevious
                                onClicked: root.activePlayer.previous()
                            }

                            ControlButton {
                                label: root.activePlayer && root.activePlayer.isPlaying ? "󰏤" : "󰐊"
                                primary: true
                                enabled: root.activePlayer && root.activePlayer.canTogglePlaying
                                onClicked: root.activePlayer.togglePlaying()
                            }

                            ControlButton {
                                label: "󰒭"
                                enabled: root.activePlayer && root.activePlayer.canGoNext
                                onClicked: root.activePlayer.next()
                            }

                        }

                    }

                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 18
                    height: 1
                    color: "#22ffffff"
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 11
                    spacing: 8

                    Text {
                        text: "Players"
                        color: "#88ffffff"
                        font.family: "GeistMono Nerd Font"
                        font.pixelSize: 11
                    }

                    Repeater {
                        model: Mpris.players

                        delegate: Rectangle {
                            required property MprisPlayer modelData

                            width: playerName.implicitWidth + 14
                            height: 20
                            radius: 10
                            color: root.activePlayer === modelData ? "#33ffffff" : "transparent"
                            border.color: "#22ffffff"
                            Component.onCompleted: {
                                if (!root.activePlayer || modelData.isPlaying)
                                    root.activePlayer = modelData;

                            }

                            Text {
                                id: playerName

                                anchors.centerIn: parent
                                text: modelData.identity
                                color: "#ccffffff"
                                font.family: "GeistMono Nerd Font"
                                font.pixelSize: 10
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.activePlayer = parent.modelData
                            }

                        }

                    }

                }

            }

        }

        PopupWindow {
            anchor.window: panel
            anchor.rect.x: bar.x + pomoChip.x - 105
            anchor.rect.y: bar.y + bar.height + 8
            width: 330
            height: 302
            visible: root.pomoOpen
            color: "transparent"

            GlassCard {
                anchors.fill: parent
                anchors.margins: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 19
                    spacing: 13

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "󰔟  Focus session"
                            color: "white"
                            font.family: "GeistMono Nerd Font"
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: root.pomo.paused ? "Paused" : root.pomo.running ? "Running" : "Ready"
                            color: root.pomo.running ? "#d5f5be" : "#b3ffffff"
                            font.family: "GeistMono Nerd Font"
                            font.pixelSize: 11
                        }

                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.pomo.running ? root.formatDuration(root.pomo.remaining) : root.pomo.preset + ":00"
                        color: "white"
                        font.family: "GeistMono Nerd Font"
                        font.pixelSize: 48
                        font.weight: Font.Light
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 10

                        ControlButton {
                            label: "−"
                            onClicked: root.runPomo("preset", Math.max(5, root.pomo.preset - 5))
                        }

                        ControlButton {
                            label: root.pomo.running && !root.pomo.paused ? "󰏤" : "󰐊"
                            primary: true
                            onClicked: root.runPomo("toggle")
                        }

                        ControlButton {
                            label: "＋"
                            onClicked: root.runPomo("preset", Math.min(120, root.pomo.preset + 5))
                        }

                        ControlButton {
                            label: "󰜺"
                            onClicked: root.runPomo("stop")
                        }

                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#22ffffff"
                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "TODAY"
                            color: "#88ffffff"
                            font.family: "GeistMono Nerd Font"
                            font.pixelSize: 10
                            font.letterSpacing: 1.5
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: root.pomo.todayCount + " pomodoros"
                            color: "white"
                            font.family: "GeistMono Nerd Font"
                            font.pixelSize: 12
                        }

                    }

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Study time"
                            color: "#b3ffffff"
                            font.family: "GeistMono Nerd Font"
                            font.pixelSize: 12
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Text {
                            text: root.formatStudyTime(root.pomo.todayMinutes)
                            color: "white"
                            font.family: "GeistMono Nerd Font"
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }

                    }

                }

            }

        }

        PopupWindow {
            anchor.window: panel
            anchor.rect.x: bar.x + audioChip.x - 225
            anchor.rect.y: bar.y + bar.height + 8
            width: 450
            height: 500
            visible: root.audioOpen
            color: "transparent"

            GlassCard {
                anchors.fill: parent
                anchors.margins: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 19
                    spacing: 12

                    Text {
                        text: "󰓃  Audio routing"
                        color: "white"
                        font.family: "GeistMono Nerd Font"
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }

                    AudioLevel {
                        Layout.fillWidth: true
                        label: "Output"
                        device: Pipewire.defaultAudioSink
                    }

                    AudioLevel {
                        Layout.fillWidth: true
                        label: "Input"
                        device: Pipewire.defaultAudioSource
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#22ffffff"
                    }

                    Text {
                        text: "OUTPUT DEVICES"
                        color: "#88ffffff"
                        font.family: "GeistMono Nerd Font"
                        font.pixelSize: 10
                        font.letterSpacing: 1.5
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 72
                        clip: true
                        spacing: 5
                        model: Pipewire.nodes

                        delegate: DeviceRow {
                            required property var modelData

                            width: ListView.view.width
                            visible: modelData.audio && !modelData.isStream && modelData.isSink
                            label: modelData.description || modelData.nickname || modelData.name
                            selected: Pipewire.defaultAudioSink === modelData
                            onClicked: Pipewire.preferredDefaultAudioSink = modelData
                        }

                    }

                    Text {
                        text: "INPUT DEVICES"
                        color: "#88ffffff"
                        font.family: "GeistMono Nerd Font"
                        font.pixelSize: 10
                        font.letterSpacing: 1.5
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 72
                        clip: true
                        spacing: 5
                        model: Pipewire.nodes

                        delegate: DeviceRow {
                            required property var modelData

                            width: ListView.view.width
                            visible: modelData.audio && !modelData.isStream && !modelData.isSink
                            label: modelData.description || modelData.nickname || modelData.name
                            selected: Pipewire.defaultAudioSource === modelData
                            onClicked: Pipewire.preferredDefaultAudioSource = modelData
                        }

                    }

                    Text {
                        text: "ACTIVE AUDIO SOURCES"
                        color: "#88ffffff"
                        font.family: "GeistMono Nerd Font"
                        font.pixelSize: 10
                        font.letterSpacing: 1.5
                    }

                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 5
                        model: Pipewire.nodes

                        delegate: DeviceRow {
                            required property var modelData

                            width: ListView.view.width
                            visible: modelData.audio && modelData.isStream
                            label: modelData.description || modelData.nickname || modelData.name
                            selected: false
                        }

                    }

                }

            }

        }

    }

    component GlassCard: Rectangle {
        radius: 22
        color: "#e615151d"
        border.color: "#44ffffff"
        border.width: 1
    }

    component GlassChip: Rectangle {
        property string text: ""
        property bool clickable: false
        property bool accent: false

        signal clicked()

        implicitHeight: 27
        radius: height / 2
        color: chipMouse.containsMouse && clickable ? "#33ffffff" : "#24ffffff"
        border.color: accent ? "#73c2d9ff" : "#38ffffff"
        border.width: 1

        Text {
            anchors.centerIn: parent
            width: parent.width - 20
            text: parent.text
            color: "white"
            font.family: "GeistMono Nerd Font"
            font.pixelSize: 12
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }

        MouseArea {
            id: chipMouse

            anchors.fill: parent
            hoverEnabled: parent.clickable
            cursorShape: parent.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (parent.clickable)
                    parent.clicked();

            }
        }

    }

    component ControlButton: Rectangle {
        property string label: ""
        property bool primary: false

        signal clicked()

        implicitWidth: primary ? 42 : 32
        implicitHeight: primary ? 42 : 32
        radius: width / 2
        color: buttonMouse.containsMouse ? (primary ? "#b3c2d9ff" : "#33ffffff") : (primary ? "#80c2d9ff" : "#1fffffff")
        opacity: enabled ? 1 : 0.35

        Text {
            anchors.centerIn: parent
            text: parent.label
            color: "white"
            font.family: "GeistMono Nerd Font"
            font.pixelSize: parent.primary ? 18 : 14
        }

        MouseArea {
            id: buttonMouse

            anchors.fill: parent
            hoverEnabled: parent.enabled
            cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (parent.enabled)
                    parent.clicked();

            }
        }

    }

    component AudioLevel: ColumnLayout {
        property string label: ""
        property var device: null

        spacing: 6

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: parent.label
                color: "#b3ffffff"
                font.family: "GeistMono Nerd Font"
                font.pixelSize: 12
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: parent.device && parent.device.audio ? Math.round(parent.device.audio.volume * 100) + "%" : "--"
                color: "white"
                font.family: "GeistMono Nerd Font"
                font.pixelSize: 12
            }

        }

        Rectangle {
            Layout.fillWidth: true
            height: 7
            radius: 4
            color: "#2bffffff"

            Rectangle {
                width: parent.width * Math.min(1, Math.max(0, parent.parent.device && parent.parent.device.audio ? parent.parent.device.audio.volume : 0))
                height: parent.height
                radius: parent.radius
                color: "#b3c2d9ff"
            }

            MouseArea {
                function setVolume(position) {
                    parent.parent.device.audio.volume = Math.max(0, Math.min(1.5, position / parent.width * 1.5));
                }

                anchors.fill: parent
                enabled: parent.parent.device && parent.parent.device.audio
                onPressed: setVolume(mouse.x)
                onPositionChanged: {
                    if (pressed)
                        setVolume(mouse.x);

                }
            }

        }

        Text {
            Layout.fillWidth: true
            text: parent.device ? (parent.device.description || parent.device.nickname || parent.device.name) : "No device"
            color: "#80ffffff"
            font.family: "GeistMono Nerd Font"
            font.pixelSize: 10
            elide: Text.ElideRight
        }

    }

    component DeviceRow: Rectangle {
        property string label: ""
        property bool selected: false

        signal clicked()

        height: visible ? 28 : 0
        radius: 10
        color: selected ? "#33c2d9ff" : rowMouse.containsMouse ? "#24ffffff" : "transparent"
        border.color: selected ? "#66c2d9ff" : "#22ffffff"

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 11
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 38
            text: parent.label
            color: "#e6ffffff"
            font.family: "GeistMono Nerd Font"
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: parent.selected ? "󰄬" : ""
            color: "#d5f5be"
            font.family: "GeistMono Nerd Font"
            font.pixelSize: 12
        }

        MouseArea {
            id: rowMouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }

    }

}
