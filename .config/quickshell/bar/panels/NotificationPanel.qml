pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "root:/"
import "root:/components"

// Everything that has come in, newest first, with one button to sweep it all
// away — the panel mako never had.
DripPanel {
    id: panel

    name: "notifications"
    panelWidth: 352

    // The list is the panel; past this it scrolls rather than growing the drip
    // down past anything worth reading.
    readonly property int listMaxHeight: 330

    // "now" only moves when something is on screen to read it.
    property double now: Date.now()

    Timer {
        interval: 30000
        running: panel.rendered
        repeat: true
        triggeredOnStart: true
        onTriggered: panel.now = Date.now()
    }

    // Opening the panel is reading them, so the toasts stop competing for the
    // same corner of the screen.
    Connections {
        target: PanelState

        function onOpened(name) {
            if (name === panel.name)
                Notices.hideAllPopups();
        }
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
                    color: {
                        if (Notices.silent)
                            return Theme.muted;
                        if (Notices.hasUrgent)
                            return Theme.urgent;
                        return Notices.count > 0 ? Theme.accent : Theme.muted;
                    }
                }

                PanelText {
                    Layout.fillWidth: true
                    text: {
                        if (Notices.count === 0)
                            return Notices.silent ? "Silenced" : "Notifications";
                        return Notices.count + (Notices.count === 1 ? " notification" : " notifications");
                    }
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                // Do-not-disturb. Lit while it is on, so a quiet shell never
                // looks like a broken one.
                PillButton {
                    label: Notices.silent ? "󰂛" : "󰂚"
                    compact: true
                    size: 28
                    glyphSize: 12
                    highlighted: Notices.silent
                    onTriggered: Notices.silent = !Notices.silent
                }

                PillButton {
                    label: "󰎟"
                    compact: true
                    size: 28
                    glyphSize: 12
                    enabled: Notices.count > 0
                    onTriggered: Notices.clear()
                }

                PillButton {
                    label: "󰅖"
                    compact: true
                    size: 28
                    glyphSize: 11
                    onTriggered: PanelState.close()
                }
            }

            // ─── the log ─────────────────────────────────────────────

            Flickable {
                id: list

                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(panel.listMaxHeight, column.implicitHeight)
                visible: Notices.count > 0

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
                        model: Notices.log

                        delegate: NoticeRow {
                            required property var modelData

                            Layout.fillWidth: true
                            notice: modelData
                        }
                    }
                }
            }

            // ─── empty state ─────────────────────────────────────────

            ColumnLayout {
                Layout.fillWidth: true
                visible: Notices.count === 0
                spacing: 6

                // Centred by filling the row and aligning the text inside it:
                // Layout.alignment centres an item within the column's own
                // width, which is only the panel's width if every ancestor
                // stretched — one that did not leaves the glyph against the
                // left edge.
                Glyph {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    horizontalAlignment: Text.AlignHCenter
                    text: Notices.silent ? "󰂛" : "󰂜"
                    font.pixelSize: 30
                    color: Theme.muted
                }

                PanelText {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 6
                    horizontalAlignment: Text.AlignHCenter
                    text: Notices.silent ? "Silenced — nothing will pop up" : "All caught up"
                    font.pixelSize: 10
                    color: Theme.muted
                }
            }
        }
    }

    // ─── one entry ───────────────────────────────────────────────────

    component NoticeRow: Rectangle {
        id: row

        property var notice: null

        readonly property bool urgent: row.notice && row.notice.urgency === NotificationUrgency.Critical

        implicitHeight: content.implicitHeight + 20
        radius: 16
        antialiasing: true

        color: {
            if (row.urgent)
                return hover.hovered ? Theme.withAlpha("#e06c75", 0.16) : Theme.urgentSoft;
            return hover.hovered ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05);
        }

        border.width: 1
        border.color: row.urgent ? Theme.withAlpha("#e06c75", 0.35) : Theme.pillBorder

        Behavior on color {
            ColorAnimation {
                duration: Theme.hoverDuration
                easing.type: Easing.OutCubic
            }
        }

        HoverHandler {
            id: hover
        }

        RowLayout {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12
            anchors.rightMargin: 10
            spacing: 10

            NoticeIcon {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 1
                notice: row.notice
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    PanelText {
                        Layout.fillWidth: true
                        text: Notices.appLabel(row.notice)
                        font.pixelSize: 9
                        color: row.urgent ? Theme.urgent : Theme.muted
                        elide: Text.ElideRight
                    }

                    PanelText {
                        text: Notices.ageOf(row.notice, panel.now)
                        font.pixelSize: 9
                        color: Theme.muted
                    }
                }

                PanelText {
                    Layout.fillWidth: true
                    text: Notices.summaryOf(row.notice)
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                }

                PanelText {
                    Layout.fillWidth: true
                    text: Notices.bodyOf(row.notice)
                    visible: text.length > 0
                    font.pixelSize: 10
                    color: Theme.muted
                    elide: Text.ElideRight
                    maximumLineCount: 3
                    wrapMode: Text.Wrap
                }

                // Whatever the sender offered to do about it.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    visible: row.notice && row.notice.actions.length > 0
                    spacing: 6

                    Repeater {
                        model: row.notice ? row.notice.actions : []

                        delegate: ActionChip {
                            required property var modelData

                            action: modelData
                            notice: row.notice
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }
            }

            PillButton {
                Layout.alignment: Qt.AlignTop
                label: "󰅖"
                compact: true
                size: 24
                glyphSize: 10
                opacity: hover.hovered ? 1 : 0.35
                onTriggered: Notices.dismiss(row.notice)

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.hoverDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    // The sender's own image if it sent one, its icon if it sent that, and a
    // glyph read off the app name otherwise — the same fallback chain the
    // media panel's artwork uses.
    component NoticeIcon: ClippingRectangle {
        id: icon

        property var notice: null
        property int size: 34

        readonly property string source: {
            if (!icon.notice)
                return "";
            if (icon.notice.image && icon.notice.image.length > 0)
                return icon.notice.image;
            if (icon.notice.appIcon && icon.notice.appIcon.length > 0)
                return "image://icon/" + icon.notice.appIcon;
            return "";
        }

        implicitWidth: icon.size
        implicitHeight: icon.size
        radius: 11
        color: Theme.pill
        border.color: Theme.pillBorder
        border.width: 1
        antialiasing: true

        Glyph {
            anchors.centerIn: parent
            visible: image.status !== Image.Ready
            text: Notices.glyphFor(icon.notice)
            font.pixelSize: 15
            color: Theme.muted
        }

        Image {
            id: image

            anchors.fill: parent
            anchors.margins: 3
            source: icon.source
            asynchronous: true
            cache: true
            fillMode: Image.PreserveAspectFit
            sourceSize.width: icon.size * 2
            sourceSize.height: icon.size * 2
            visible: status === Image.Ready
        }
    }

    component ActionChip: Rectangle {
        id: chip

        property var action: null
        property var notice: null

        implicitWidth: label.implicitWidth + 18
        implicitHeight: 22
        radius: 999
        antialiasing: true

        color: chipHover.hovered ? Theme.pillHover : Theme.pill
        border.width: 1
        border.color: chipHover.hovered ? Theme.pillHoverBorder : Theme.pillBorder

        Behavior on color {
            ColorAnimation {
                duration: Theme.hoverDuration
                easing.type: Easing.OutCubic
            }
        }

        PanelText {
            id: label

            anchors.centerIn: parent
            text: chip.action ? chip.action.text : ""
            font.pixelSize: 10
        }

        HoverHandler {
            id: chipHover

            cursorShape: Qt.PointingHandCursor
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Notices.invoke(chip.notice, chip.action)
        }
    }
}
