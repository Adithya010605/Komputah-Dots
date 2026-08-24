pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell.Networking
import "root:/"
import "root:/components"

// The radios, in full: Wi-Fi and bluetooth, each with everything you would
// otherwise open nm-connection-editor or blueman for.
//
// Both used to be pills on the bar. They are settings rather than readouts, so
// they live here under one gear instead of eating two slots of bar.
DripPanel {
    id: panel

    name: "settings"
    panelWidth: 380

    readonly property color rowTint: Qt.rgba(1, 1, 1, 0.05)
    readonly property color rowTintHover: Qt.rgba(1, 1, 1, 0.09)
    readonly property color rowSelected: Theme.withAlpha(Theme.accentBase, 0.13)
    readonly property color rowSelectedHover: Theme.withAlpha(Theme.accentBase, 0.18)

    // ─── wi-fi ───────────────────────────────────────────────────────

    readonly property var wifiDevice: {
        for (const device of Networking.devices.values) {
            if (device.type === DeviceType.Wifi)
                return device;
        }
        return null;
    }

    readonly property bool wifiReady: panel.wifiDevice !== null && Networking.wifiEnabled

    readonly property var activeNetwork: {
        if (!panel.wifiDevice)
            return null;

        for (const network of panel.wifiDevice.networks.values) {
            if (network.connected)
                return network;
        }
        return null;
    }

    // Connected first, then anything already known, then the strongest of the
    // rest — the order you would pick from yourself.
    readonly property var networks: {
        if (!panel.wifiReady)
            return [];

        const found = [];
        for (const network of panel.wifiDevice.networks.values) {
            // A sweep in progress can leave a torn-down entry in the model for
            // an instant; it is not a network you could pick.
            if (network && network.name.length > 0)
                found.push(network);
        }

        found.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.known !== b.known)
                return a.known ? -1 : 1;
            return b.signalStrength - a.signalStrength;
        });

        return found;
    }

    // Browsing shows everything in the air. At rest the list is only what you
    // actually use — the network you are on and the ones you have saved — so
    // the panel does not open as a wall of strangers' router names.
    property bool wifiBrowsing: false

    readonly property var visibleNetworks: {
        if (panel.wifiBrowsing)
            return panel.networks;

        const mine = panel.networks.filter(network => network && (network.connected || network.known));

        // Nothing saved yet means the short list would be empty, which reads as
        // a broken panel rather than a tidy one.
        return mine.length > 0 ? mine : panel.networks.slice(0, 3);
    }

    readonly property int hiddenNetworks: panel.networks.length - panel.visibleNetworks.length

    // The network waiting on a password, if any. Cleared whenever the panel
    // closes so it never reopens mid-entry.
    property var pskTarget: null
    property string wifiError: ""

    onOpenChanged: {
        panel.pskTarget = null;
        panel.wifiError = "";
        panel.wifiBrowsing = false;
        panel.btPairing = false;

        // Scanning costs radio time, so it only runs while the list is on
        // screen to be read.
        if (panel.wifiDevice)
            panel.wifiDevice.scannerEnabled = panel.open;

        if (!panel.open && panel.adapter)
            panel.adapter.discovering = false;
    }

    function browseWifi(on) {
        panel.wifiBrowsing = on;

        // Opening the full list is also the moment to go looking for what is
        // out there, rather than showing whatever the last sweep found.
        if (on && panel.wifiDevice) {
            panel.wifiDevice.scannerEnabled = false;
            panel.wifiDevice.scannerEnabled = true;
        }
    }

    function signalGlyph(strength) {
        // NetworkManager reports 0–100; a fraction is normalised the same way
        // the bluetooth battery is.
        const percent = strength <= 1 ? strength * 100 : strength;

        if (percent >= 75)
            return "󰤨";
        if (percent >= 55)
            return "󰤥";
        if (percent >= 35)
            return "󰤢";
        if (percent >= 15)
            return "󰤟";
        return "󰤯";
    }

    function signalPercent(strength) {
        return Math.round(strength <= 1 ? strength * 100 : strength);
    }

    function isSecured(network) {
        if (!network)
            return false;
        return network.security !== WifiSecurityType.Open && network.security !== WifiSecurityType.Owe;
    }

    function securityLabel(network) {
        if (!panel.isSecured(network))
            return "Open";
        return WifiSecurityType.toString(network.security);
    }

    function stateLabel(state) {
        switch (state) {
        case ConnectionState.Connecting:
            return "Connecting…";
        case ConnectionState.Disconnecting:
            return "Disconnecting…";
        case ConnectionState.Connected:
            return "Connected";
        default:
            return "";
        }
    }

    // ─── bluetooth ───────────────────────────────────────────────────

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btReady: panel.adapter !== null && panel.adapter.enabled

    // Pairing mode: the adapter goes discoverable-and-discovering, and anything
    // in range joins the list. Off again the moment you are done, because an
    // adapter left scanning eats battery and never settles.
    property bool btPairing: false

    function pairMode(on) {
        panel.btPairing = on;

        if (panel.adapter)
            panel.adapter.discovering = on;
    }

    readonly property var btDevices: {
        if (!panel.btReady)
            return [];

        const found = [];
        for (const device of Bluetooth.devices.values) {
            if (!device)
                continue;

            // Unpaired strangers are only worth listing while you are actually
            // looking for something to pair.
            if (!device.paired && !panel.btPairing)
                continue;
            found.push(device);
        }

        found.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.paired !== b.paired)
                return a.paired ? -1 : 1;
            return (a.deviceName || "").localeCompare(b.deviceName || "");
        });

        return found;
    }

    readonly property int btConnectedCount: {
        let count = 0;
        for (const device of Bluetooth.devices.values) {
            if (device && device.connected)
                count++;
        }
        return count;
    }

    function btGlyph(device) {
        if (!device)
            return "󰂯";

        const hint = ((device.icon || "") + " " + (device.deviceName || "")).toLowerCase();

        if (hint.includes("headset") || hint.includes("headphone"))
            return "󰋋";
        if (hint.includes("audio") || hint.includes("speaker"))
            return "󰓃";
        if (hint.includes("mouse"))
            return "󰍽";
        if (hint.includes("keyboard"))
            return "󰌌";
        if (hint.includes("phone"))
            return "󰄜";
        if (hint.includes("watch"))
            return "󰖉";
        if (hint.includes("computer") || hint.includes("laptop"))
            return "󰌢";
        return "󰂯";
    }

    function btBattery(device) {
        if (!device || !device.batteryAvailable)
            return "";

        const raw = device.battery;
        return Math.round(raw <= 1 ? raw * 100 : raw) + "%";
    }

    function btStatus(device) {
        if (!device)
            return "";

        switch (device.state) {
        case BluetoothDeviceState.Connecting:
            return "Connecting…";
        case BluetoothDeviceState.Disconnecting:
            return "Disconnecting…";
        }

        if (device.pairing)
            return "Pairing…";
        if (device.connected)
            return "Connected";
        if (device.paired)
            return "Paired";
        return "Available";
    }

    // ─── panel-local components ──────────────────────────────────────

    // A section title with its own radio toggle and one optional action.
    component SectionHeader: RowLayout {
        id: header

        signal toggled(bool value)
        signal acted

        property string caption: ""
        property string glyph: ""
        property string detail: ""

        property bool toggleVisible: false
        property bool checked: false
        property bool toggleEnabled: true

        property string action: ""
        property bool actionVisible: false
        property bool actionHighlighted: false

        Layout.fillWidth: true
        Layout.topMargin: 2
        spacing: 9

        Glyph {
            text: header.glyph
            font.pixelSize: 15
            color: header.checked ? Theme.accent : Theme.muted

            Behavior on color {
                ColorAnimation {
                    duration: Theme.hoverDuration
                    easing.type: Easing.OutCubic
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            PanelText {
                Layout.fillWidth: true
                text: header.caption
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            PanelText {
                Layout.fillWidth: true
                text: header.detail
                visible: text.length > 0
                font.pixelSize: 9
                color: Theme.muted
                elide: Text.ElideRight
            }
        }

        PillButton {
            visible: header.actionVisible
            label: header.action
            highlighted: header.actionHighlighted
            compact: true
            size: 28
            glyphSize: 12
            onTriggered: header.acted()
        }

        Toggle {
            visible: header.toggleVisible
            checked: header.checked
            enabled: header.toggleEnabled
            onToggled: on => header.toggled(on)
        }
    }

    // A list that grows with its contents up to a point, then scrolls.
    component ScrollList: Flickable {
        id: list

        property int maxHeight: 200
        property var model: []
        property Component rowDelegate: null

        implicitHeight: Math.min(list.maxHeight, column.implicitHeight)
        contentHeight: column.implicitHeight
        contentWidth: width

        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 4000

        ColumnLayout {
            id: column

            width: list.width
            spacing: 6

            Repeater {
                model: list.model
                delegate: list.rowDelegate
            }
        }
    }

    // The row that ends a section: opens the full list, or puts the adapter
    // into pairing mode. Slimmer than a device row and lit while its mode is
    // running, so it reads as a switch you have flipped rather than a button
    // you pressed once.
    component ActionRow: Rectangle {
        id: action

        signal activated

        property string glyph: ""
        property string caption: ""
        property string detail: ""
        property bool highlighted: false
        property bool busy: false

        implicitHeight: 34
        radius: 999
        antialiasing: true

        color: {
            if (action.highlighted)
                return actionHover.containsMouse ? panel.rowSelectedHover : panel.rowSelected;
            return actionHover.containsMouse ? panel.rowTintHover : panel.rowTint;
        }

        border.width: 1
        border.color: action.highlighted ? Theme.accentSoft : Qt.rgba(1, 1, 1, 0.08)

        Behavior on color {
            ColorAnimation {
                duration: Theme.hoverDuration
                easing.type: Easing.OutCubic
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.hoverDuration
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            id: actionHover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: action.activated()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 8

            Glyph {
                text: action.glyph
                font.pixelSize: 12
                color: action.highlighted ? Theme.accent : Theme.muted
            }

            PanelText {
                Layout.fillWidth: true
                text: action.caption
                font.pixelSize: 11
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            PanelText {
                text: action.detail
                visible: text.length > 0
                font.pixelSize: 9
                color: Theme.muted
            }

            // A slow pulse while the radio is out looking, so the row shows
            // that something is happening without a spinner to animate.
            Rectangle {
                id: pulse

                Layout.alignment: Qt.AlignVCenter
                visible: action.busy
                width: 6
                height: 6
                radius: 999
                antialiasing: true
                color: Theme.accent

                SequentialAnimation {
                    running: action.busy
                    loops: Animation.Infinite
                    alwaysRunToEnd: true

                    NumberAnimation {
                        target: pulse
                        property: "opacity"
                        to: 0.25
                        duration: 620
                        easing.type: Easing.InOutSine
                    }

                    NumberAnimation {
                        target: pulse
                        property: "opacity"
                        to: 1
                        duration: 620
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }

    // The shared shell of a list row: tinted, rounded, and lit when it is the
    // one currently carrying the connection.
    component ListRow: Rectangle {
        id: shell

        property bool selected: false
        property alias hovered: shellHover.containsMouse
        property bool clickable: true

        signal activated

        default property alias rowContent: holder.data

        Layout.fillWidth: true
        implicitHeight: holder.implicitHeight + 16

        radius: 16
        antialiasing: true

        color: {
            if (shell.selected)
                return shellHover.containsMouse ? panel.rowSelectedHover : panel.rowSelected;
            return shellHover.containsMouse ? panel.rowTintHover : panel.rowTint;
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.hoverDuration
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            id: shellHover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: shell.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: {
                if (shell.clickable)
                    shell.activated();
            }
        }

        ColumnLayout {
            id: holder

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8
        }
    }

    // ─── wi-fi row ───────────────────────────────────────────────────

    component WifiRow: ListRow {
        id: wifi

        required property var modelData

        // An access point can disappear between one sweep and the next —
        // NetworkManager drops it, the object behind this row goes with it, and
        // every binding below would fault on null. Everything the row reads is
        // funnelled through these guards so a vanishing neighbour is a row that
        // quietly empties rather than a wall of TypeErrors.
        readonly property var network: modelData
        readonly property bool alive: network !== null && network !== undefined

        readonly property bool isConnected: wifi.alive && network.connected
        readonly property bool isKnown: wifi.alive && network.known
        readonly property bool isChanging: wifi.alive && network.stateChanging
        readonly property string title: wifi.alive ? network.name : ""
        readonly property real strength: wifi.alive ? network.signalStrength : 0

        readonly property bool secured: wifi.alive && panel.isSecured(network)
        readonly property bool askingPsk: wifi.alive && panel.pskTarget === network

        visible: wifi.alive
        selected: wifi.isConnected
        clickable: wifi.alive && !wifi.isChanging

        onActivated: {
            if (!wifi.alive || wifi.isConnected)
                return;

            panel.wifiError = "";

            // A network that is already known has its secret on file; an
            // unknown secured one has to be asked for.
            if (wifi.isKnown || !wifi.secured) {
                panel.pskTarget = null;
                wifi.network.connect();
                return;
            }

            panel.pskTarget = wifi.askingPsk ? null : wifi.network;
        }

        Connections {
            target: wifi.alive ? wifi.network : null

            function onConnectionFailed(reason) {
                panel.wifiError = wifi.title + ": " + ConnectionFailReason.toString(reason);
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Glyph {
                text: panel.signalGlyph(wifi.strength)
                font.pixelSize: 14
                color: wifi.isConnected ? Theme.accent : Theme.text
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                PanelText {
                    Layout.fillWidth: true
                    text: wifi.title
                    font.pixelSize: 11
                    font.weight: wifi.isConnected ? Font.DemiBold : Font.Medium
                    elide: Text.ElideRight
                }

                PanelText {
                    Layout.fillWidth: true
                    font.pixelSize: 9
                    color: Theme.muted
                    elide: Text.ElideRight

                    text: {
                        if (!wifi.alive)
                            return "";

                        const state = panel.stateLabel(wifi.network.state);
                        if (state.length > 0 && wifi.isChanging)
                            return state;

                        const parts = [panel.signalPercent(wifi.strength) + "%", panel.securityLabel(wifi.network)];
                        if (wifi.isKnown && !wifi.isConnected)
                            parts.push("Saved");
                        return parts.join(" · ");
                    }
                }
            }

            Glyph {
                visible: wifi.secured
                text: "󰌾"
                font.pixelSize: 10
                color: Theme.muted
            }

            PillButton {
                visible: wifi.isConnected
                label: "󰅖"
                compact: true
                size: 26
                glyphSize: 10
                onTriggered: wifi.network.disconnect()
            }

            PillButton {
                visible: wifi.isKnown && !wifi.isConnected
                label: "󰩺"
                compact: true
                size: 26
                glyphSize: 10
                onTriggered: {
                    panel.pskTarget = null;
                    wifi.network.forget();
                }
            }
        }

        // ─── password entry ──────────────────────────────────────────

        RowLayout {
            Layout.fillWidth: true
            visible: wifi.askingPsk
            spacing: 6

            onVisibleChanged: {
                if (visible)
                    psk.forceActiveFocus();
                else
                    psk.text = "";
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 30
                radius: 999
                antialiasing: true
                color: Qt.rgba(0, 0, 0, 0.22)
                border.width: 1
                border.color: psk.activeFocus ? Theme.accentSoft : Theme.pillBorder

                Behavior on border.color {
                    ColorAnimation {
                        duration: Theme.hoverDuration
                        easing.type: Easing.OutCubic
                    }
                }

                TextInput {
                    id: psk

                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12

                    verticalAlignment: TextInput.AlignVCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    color: Theme.text
                    echoMode: TextInput.Password
                    selectByMouse: true
                    clip: true

                    onAccepted: wifi.submitPsk()

                    PanelText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: psk.text.length === 0 && !psk.activeFocus
                        text: "Password"
                        font.pixelSize: 11
                        color: Theme.muted
                    }
                }
            }

            PillButton {
                label: "󰌘"
                compact: true
                size: 30
                glyphSize: 12
                highlighted: psk.text.length > 0
                enabled: psk.text.length > 0
                onTriggered: wifi.submitPsk()
            }
        }

        function submitPsk() {
            if (!wifi.alive || psk.text.length === 0)
                return;

            panel.wifiError = "";
            wifi.network.connectWithPsk(psk.text);
            panel.pskTarget = null;
        }
    }

    // ─── bluetooth row ───────────────────────────────────────────────

    component BluetoothRow: ListRow {
        id: bt

        required property var modelData

        // Discovery churns: bluez publishes a stranger, drops it a few seconds
        // later, and the object under this row goes with it. Same guard as the
        // wi-fi rows — read the device once, defensively, and let the rest of
        // the row work off plain values.
        readonly property var device: modelData
        readonly property bool alive: device !== null && device !== undefined

        readonly property bool isConnected: bt.alive && device.connected
        readonly property bool isPaired: bt.alive && device.paired
        readonly property bool isPairing: bt.alive && device.pairing
        readonly property bool isTrusted: bt.alive && device.trusted
        readonly property string title: bt.alive ? (device.deviceName || device.name || device.address) : ""

        visible: bt.alive
        selected: bt.isConnected
        clickable: bt.alive && !bt.isPairing

        onActivated: {
            if (!bt.alive)
                return;

            if (bt.isConnected) {
                bt.device.disconnect();
                return;
            }

            // Connecting to something never paired pairs it first; bluez does
            // the rest of the handshake itself.
            if (!bt.isPaired)
                bt.device.pair();
            else
                bt.device.connect();
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Glyph {
                text: panel.btGlyph(bt.device)
                font.pixelSize: 14
                color: bt.isConnected ? Theme.accent : Theme.text
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                PanelText {
                    Layout.fillWidth: true
                    text: bt.title
                    font.pixelSize: 11
                    font.weight: bt.isConnected ? Font.DemiBold : Font.Medium
                    elide: Text.ElideRight
                }

                PanelText {
                    Layout.fillWidth: true
                    font.pixelSize: 9
                    color: Theme.muted
                    elide: Text.ElideRight

                    text: {
                        if (!bt.alive)
                            return "";

                        const parts = [panel.btStatus(bt.device)];

                        // Spelt out rather than glyphed: this line is
                        // PanelText, which is the proportional face, so
                        // a Nerd Font battery here falls back to another
                        // font and lands at the wrong size beside the
                        // words it sits in.
                        const battery = panel.btBattery(bt.device);
                        if (battery.length > 0)
                            parts.push("Battery " + battery);

                        if (bt.isPaired && !bt.isTrusted)
                            parts.push("Untrusted");

                        return parts.join(" · ");
                    }
                }
            }

            // Trust is the difference between a headset that reconnects itself
            // and one you have to click every morning.
            PillButton {
                visible: bt.isPaired
                label: bt.isTrusted ? "󰄬" : "󰝥"
                highlighted: bt.isTrusted
                compact: true
                size: 26
                glyphSize: 10
                onTriggered: bt.device.trusted = !bt.isTrusted
            }

            // An unpaired device gets an explicit pair button as well as the
            // row itself, so "what do I press" is never a guess.
            PillButton {
                visible: bt.alive && !bt.isPaired && !bt.isPairing
                label: "󰌘"
                highlighted: true
                compact: true
                size: 26
                glyphSize: 10
                onTriggered: bt.device.pair()
            }

            PillButton {
                visible: bt.isPairing
                label: "󰅖"
                compact: true
                size: 26
                glyphSize: 10
                onTriggered: bt.device.cancelPair()
            }

            PillButton {
                visible: bt.isPaired && !bt.isPairing
                label: "󰩺"
                compact: true
                size: 26
                glyphSize: 10
                onTriggered: bt.device.forget()
            }
        }
    }

    // ─── body ────────────────────────────────────────────────────────

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
                    color: Networking.connectivity === NetworkConnectivity.Full ? Theme.accent : Theme.muted
                }

                PanelText {
                    Layout.fillWidth: true
                    text: "Settings"
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

            // ─── wi-fi ───────────────────────────────────────────────

            SectionHeader {
                caption: "Wi-Fi"
                glyph: Networking.wifiEnabled ? "󰤨" : "󰤮"

                detail: {
                    if (!panel.wifiDevice)
                        return "No adapter";
                    if (!Networking.wifiHardwareEnabled)
                        return "Blocked by hardware switch";
                    if (!Networking.wifiEnabled)
                        return "Off";
                    if (panel.activeNetwork)
                        return panel.activeNetwork.name;
                    return "Not connected";
                }

                toggleVisible: true
                checked: Networking.wifiEnabled
                toggleEnabled: panel.wifiDevice !== null && Networking.wifiHardwareEnabled
                onToggled: on => {
                    panel.wifiError = "";
                    Networking.wifiEnabled = on;
                }

                action: "󰑐"
                actionVisible: panel.wifiReady
                onActed: {
                    // Kicking the scanner off and on again is what asks
                    // NetworkManager for a fresh sweep.
                    panel.wifiDevice.scannerEnabled = false;
                    panel.wifiDevice.scannerEnabled = true;
                }
            }

            PanelText {
                Layout.fillWidth: true
                visible: panel.wifiError.length > 0
                text: panel.wifiError
                font.pixelSize: 10
                color: Theme.muted
                wrapMode: Text.WordWrap
            }

            PanelText {
                Layout.fillWidth: true
                visible: panel.wifiReady && panel.networks.length === 0
                text: "Scanning…"
                font.pixelSize: 10
                color: Theme.muted
            }

            ScrollList {
                Layout.fillWidth: true
                visible: panel.wifiReady && panel.visibleNetworks.length > 0

                // The full list is given room to breathe; the short one only
                // ever holds a handful of rows.
                maxHeight: panel.wifiBrowsing ? 268 : 196
                model: panel.visibleNetworks

                rowDelegate: Component {
                    WifiRow {}
                }
            }

            ActionRow {
                Layout.fillWidth: true
                visible: panel.wifiReady

                glyph: panel.wifiBrowsing ? "󰅃" : "󰐷"
                caption: panel.wifiBrowsing ? "Show fewer" : "See all networks"

                detail: {
                    if (panel.wifiBrowsing)
                        return panel.networks.length + " in range";
                    if (panel.hiddenNetworks > 0)
                        return panel.hiddenNetworks + " more nearby";
                    return "";
                }

                busy: panel.wifiBrowsing && panel.networks.length === 0
                highlighted: panel.wifiBrowsing

                onActivated: panel.browseWifi(!panel.wifiBrowsing)
            }

            // ─── bluetooth ───────────────────────────────────────────

            SectionHeader {
                caption: "Bluetooth"
                glyph: {
                    if (!panel.btReady)
                        return "󰂲";
                    return panel.btConnectedCount > 0 ? "󰂱" : "󰂯";
                }

                detail: {
                    if (!panel.adapter)
                        return "No adapter";
                    if (!panel.adapter.enabled)
                        return "Off";
                    if (panel.btConnectedCount > 0)
                        return panel.btConnectedCount + (panel.btConnectedCount === 1 ? " device connected" : " devices connected");
                    return panel.btPairing ? "Searching…" : "No devices connected";
                }

                toggleVisible: true
                checked: panel.adapter ? panel.adapter.enabled : false
                toggleEnabled: panel.adapter !== null
                onToggled: on => {
                    // Switching the radio off has to take pairing mode with it,
                    // or the panel comes back up still hunting.
                    if (!on)
                        panel.pairMode(false);
                    panel.adapter.enabled = on;
                }
            }

            PanelText {
                Layout.fillWidth: true
                visible: panel.btReady && panel.btDevices.length === 0
                text: panel.btPairing ? "Searching for devices…" : "No paired devices"
                font.pixelSize: 10
                color: Theme.muted
            }

            ScrollList {
                Layout.fillWidth: true
                visible: panel.btReady && panel.btDevices.length > 0
                maxHeight: panel.btPairing ? 268 : 196
                model: panel.btDevices

                rowDelegate: Component {
                    BluetoothRow {}
                }
            }

            ActionRow {
                Layout.fillWidth: true
                visible: panel.btReady

                glyph: panel.btPairing ? "󰅖" : "󰐷"
                caption: panel.btPairing ? "Stop searching" : "Pair a new device"

                detail: {
                    if (!panel.btPairing)
                        return "";

                    const strangers = panel.btDevices.filter(device => device && !device.paired).length;
                    return strangers > 0 ? strangers + " found" : "";
                }

                busy: panel.btPairing
                highlighted: panel.btPairing

                onActivated: panel.pairMode(!panel.btPairing)
            }
        }
    }
}
