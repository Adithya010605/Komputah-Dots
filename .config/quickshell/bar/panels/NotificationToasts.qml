pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "root:/"
import "root:/components"

// What arrives, as it arrives — mako's popup corner, moved onto the bar.
//
// It is the same drip every panel uses, hanging off the bell rather than off a
// click, so a notification reads as coming out of the shell rather than
// appearing beside it. It never takes the keyboard and never eats a click
// anywhere but on itself.
DripPanel {
    id: toasts

    name: "toasts"
    panelWidth: Theme.toastWidth

    anchorModule: "notifications"
    catchesClicks: false
    takesFocus: false

    // Nothing to pop up over the log itself: the panel already shows it, and
    // two surfaces hanging from the same module is one too many.
    open: Notices.popups.length > 0 && !PanelState.isOpen("notifications")

    body: Component {
        ColumnLayout {
            spacing: 8

            Repeater {
                model: Notices.popups

                delegate: Toast {
                    required property var modelData

                    Layout.fillWidth: true
                    notice: modelData
                }
            }
        }
    }

    component Toast: Rectangle {
        id: toast

        property var notice: null

        readonly property bool urgent: toast.notice && toast.notice.urgency === NotificationUrgency.Critical

        implicitHeight: content.implicitHeight + 18
        radius: 16
        antialiasing: true

        color: {
            if (toast.urgent)
                return Theme.urgentSoft;
            return hover.hovered ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05);
        }

        border.width: 1
        border.color: toast.urgent ? Theme.withAlpha("#e06c75", 0.35) : Theme.pillBorder

        Behavior on color {
            ColorAnimation {
                duration: Theme.hoverDuration
                easing.type: Easing.OutCubic
            }
        }

        // Reading one should not run its clock out from under you, so the
        // countdown holds while the cursor is on it and starts again from the
        // top when it leaves.
        Timer {
            interval: Math.max(1200, Notices.timeoutOf(toast.notice))
            running: !hover.hovered && Notices.timeoutOf(toast.notice) > 0
            repeat: false
            onTriggered: Notices.hidePopup(toast.notice)
        }

        HoverHandler {
            id: hover
        }

        // Clicking the toast takes it off the bar but leaves it in the log —
        // dismissing outright is what the ✕ is for.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    Notices.dismiss(toast.notice);
                else
                    Notices.hidePopup(toast.notice);
            }
        }

        RowLayout {
            id: content

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 11
            anchors.rightMargin: 9
            spacing: 9

            Icon {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 1
                notice: toast.notice
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                PanelText {
                    Layout.fillWidth: true
                    text: Notices.appLabel(toast.notice)
                    font.pixelSize: 9
                    color: toast.urgent ? Theme.urgent : Theme.muted
                    elide: Text.ElideRight
                }

                PanelText {
                    Layout.fillWidth: true
                    text: Notices.summaryOf(toast.notice)
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                }

                PanelText {
                    Layout.fillWidth: true
                    text: Notices.bodyOf(toast.notice)
                    visible: text.length > 0
                    font.pixelSize: 10
                    color: Theme.muted
                    elide: Text.ElideRight
                    maximumLineCount: 3
                    wrapMode: Text.Wrap
                }
            }

            PillButton {
                Layout.alignment: Qt.AlignTop
                label: "󰅖"
                compact: true
                size: 22
                glyphSize: 10
                opacity: hover.hovered ? 1 : 0.3
                onTriggered: Notices.dismiss(toast.notice)

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.hoverDuration
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    component Icon: ClippingRectangle {
        id: icon

        property var notice: null
        property int size: 30

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
        radius: 10
        color: Theme.pill
        border.color: Theme.pillBorder
        border.width: 1
        antialiasing: true

        Glyph {
            anchors.centerIn: parent
            visible: image.status !== Image.Ready
            text: Notices.glyphFor(icon.notice)
            font.pixelSize: 14
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
}
