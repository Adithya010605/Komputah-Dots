pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "root:/"
import "root:/components"

// The launcher.
//
// Like the wallpaper picker and unlike everything else in the shell, this does
// not drip: it has no module on the bar and nothing to hang from. It is
// summoned by Super+R and it is a card — one glass surface, centred, sitting in
// the upper third of a blurred desktop.
//
// It sits high rather than in the middle because the results grow downward out
// of the box. Centring the card would mean the whole thing crept upward as the
// list filled, and the row you were about to press would move out from under
// your finger while you were reading it. Anchored near the top, the box you are
// typing into never moves at all.
//
// Everything on screen comes from Launcher.results, which is a plain array
// rebuilt whenever the query changes. There is no model, no delegate state and
// nothing to keep in step — the selection is an integer into that array, and it
// goes back to the top whenever the array changes underneath it.
Scope {
    id: launcher

    // Kept alive briefly past the close so the fade can finish playing.
    property bool open: false
    property bool rendered: false

    property int selected: 0

    readonly property int count: Launcher.count

    // ─── opening and closing ─────────────────────────────────────────

    function show() {
        if (launcher.open)
            return;

        // Always a fresh box. A launcher that opens holding what you typed
        // last time is one that has to be cleared before it can be used, and
        // clearing it is the first thing anybody does.
        Launcher.query = "";
        launcher.selected = 0;

        // The only moment the rates are worth thinking about: asked for here
        // rather than on a timer, so a machine that never converts anything
        // never makes the request. Does nothing when the cache is current.
        Rates.refresh();

        unrender.stop();
        launcher.rendered = true;
        launcher.open = true;
    }

    function hide() {
        launcher.open = false;
        unrender.restart();
    }

    function toggle() {
        if (launcher.open)
            launcher.hide();
        else
            launcher.show();
    }

    Timer {
        id: unrender

        interval: Theme.launcherUnrenderDelay
        repeat: false
        onTriggered: {
            if (launcher.open)
                return;

            launcher.rendered = false;
            Launcher.query = "";
        }
    }

    // ─── moving through the list ─────────────────────────────────────

    // Wraps at both ends. The list is short enough to see all of at once, so
    // running off the bottom to get back to the top is quicker than reversing.
    function move(delta) {
        if (launcher.count === 0)
            return;

        launcher.selected = ((launcher.selected + delta) % launcher.count + launcher.count) % launcher.count;
    }

    function activate() {
        if (Launcher.activate(launcher.selected))
            launcher.hide();
    }

    // The results are rebuilt on every keystroke and the old selection index
    // means nothing against the new list, so it goes back to the top — which
    // is also where the best match now is.
    Connections {
        target: Launcher

        function onResultsChanged() {
            launcher.selected = 0;
        }
    }

    // ─── the surface ─────────────────────────────────────────────────

    PanelWindow {
        id: window

        visible: launcher.rendered
        color: "transparent"

        // Reaches the top of the screen rather than starting below the bar.
        // Only the mode is set: assigning exclusiveZone at all puts the window
        // back into normal exclusion, zone or no zone.
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.namespace: "quickshell-launcher"
        WlrLayershell.layer: WlrLayer.Overlay

        // Exclusive while open. Every keystroke belongs to the box, including
        // the ones that would otherwise be Hyprland bindings — typing an
        // application's name should not also be driving the compositor.
        WlrLayershell.keyboardFocus: launcher.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        // The field takes the focus when the surface is mapped, not when the
        // launcher is asked to open: at that point this window does not exist
        // yet and forcing focus into it does nothing. One tick of slack lets
        // the compositor hand the keyboard over first.
        onVisibleChanged: {
            if (visible)
                takeFocus.restart();
            else
                field.text = "";
        }

        Timer {
            id: takeFocus

            interval: 1
            repeat: false
            onTriggered: field.forceActiveFocus()
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.scrim
            opacity: launcher.open ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: launcher.open ? Theme.launcherFadeIn : Theme.launcherFadeOut
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: launcher.hide()
            }
        }

        // ─── the card ────────────────────────────────────────────────

        Rectangle {
            id: card

            width: Math.min(Theme.launcherWidth, window.width - Theme.padding * 4)

            // Grows downward from a fixed top edge. The box you are typing
            // into is at the same place on screen from the moment it opens to
            // the moment it closes, however many results are under it.
            x: (window.width - width) / 2
            y: Math.round(window.height * Theme.launcherTopFraction) + (launcher.open ? 0 : Theme.launcherRiseDistance)

            implicitHeight: contents.implicitHeight
            height: implicitHeight

            radius: Theme.launcherRadius
            antialiasing: true
            clip: true

            color: Theme.glass
            border.width: 1
            border.color: Theme.glassBorder

            opacity: launcher.open ? 1 : 0
            scale: launcher.open ? 1 : Theme.launcherRestScale

            Behavior on y {
                NumberAnimation {
                    duration: Theme.launcherRise
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: launcher.open ? Theme.launcherFadeIn : Theme.launcherFadeOut
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.launcherRise
                    easing.type: Easing.OutCubic
                }
            }

            // The card resizes as results come and go, and it stretches to
            // them rather than snapping — the same behaviour the bar has when
            // a module appears on it.
            Behavior on height {
                NumberAnimation {
                    duration: Theme.launcherRise
                    easing.type: Easing.OutCubic
                }
            }

            // The same faint wallpaper wash every other surface carries, so
            // this is made of the same glass as the bar it never touches.
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                antialiasing: true
                color: Theme.glassTint
            }

            ColumnLayout {
                id: contents

                width: parent.width
                spacing: 0

                // ─── the box ─────────────────────────────────────────

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.launcherFieldHeight

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.padding + 6
                        anchors.rightMargin: Theme.padding + 6
                        spacing: 14

                        Glyph {
                            text: "󰍉"
                            font.pixelSize: 18
                            color: field.text.length > 0 ? Theme.accent : Theme.muted

                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.hoverDuration
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        TextInput {
                            id: field

                            Layout.fillWidth: true

                            verticalAlignment: TextInput.AlignVCenter
                            font.family: Theme.fontFamily
                            font.pixelSize: 19
                            font.weight: Font.Medium
                            color: Theme.text
                            selectionColor: Theme.accentSoft
                            selectedTextColor: Theme.text
                            selectByMouse: true
                            clip: true

                            // The field owns the text and Launcher owns the
                            // query; this is the one place they meet. Bound
                            // this way round because the field is what a person
                            // types into and everything else only reads.
                            onTextChanged: Launcher.query = text

                            // Navigation is handled here rather than on an
                            // ancestor because a single-line TextInput accepts
                            // Return itself and would swallow it before it
                            // reached anything above. Keys.onPressed runs ahead
                            // of the field's own handling, so this gets first
                            // refusal on every key and passes the rest straight
                            // through to the text.
                            Keys.onPressed: event => {
                                switch (event.key) {
                                case Qt.Key_Escape:
                                    launcher.hide();
                                    break;
                                case Qt.Key_Up:
                                    launcher.move(-1);
                                    break;
                                case Qt.Key_Down:
                                case Qt.Key_Tab:
                                    launcher.move(1);
                                    break;
                                case Qt.Key_Backtab:
                                    launcher.move(-1);
                                    break;
                                case Qt.Key_Return:
                                case Qt.Key_Enter:
                                    launcher.activate();
                                    break;
                                // The readline pair, for hands already there.
                                case Qt.Key_N:
                                    if (!(event.modifiers & Qt.ControlModifier))
                                        return;
                                    launcher.move(1);
                                    break;
                                case Qt.Key_P:
                                    if (!(event.modifiers & Qt.ControlModifier))
                                        return;
                                    launcher.move(-1);
                                    break;
                                default:
                                    return;
                                }

                                event.accepted = true;
                            }

                            PanelText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: field.text.length === 0
                                text: "Search, or do a sum"
                                font.pixelSize: 19
                                color: Theme.muted
                            }
                        }

                        // What Enter will do, spelt out rather than glyphed: it
                        // is a caption on an action, and captions are set in
                        // the proportional face.
                        PanelText {
                            visible: text.length > 0
                            text: {
                                const row = Launcher.results[launcher.selected];
                                if (!row)
                                    return "";
                                if (row.kind === "app")
                                    return "Enter to open";
                                if (row.kind === "answer")
                                    return "Enter to copy";
                                return "";
                            }
                            font.pixelSize: 11
                            color: Theme.muted
                        }
                    }
                }

                // ─── the results ─────────────────────────────────────

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    visible: launcher.count > 0
                    color: Theme.divider
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: launcher.count > 0 ? 8 : 0
                    Layout.bottomMargin: launcher.count > 0 ? 8 : 0
                    spacing: 2

                    Repeater {
                        model: Launcher.results

                        delegate: ResultRow {
                            required property var modelData
                            required property int index

                            result: modelData
                            ordinal: index
                        }
                    }
                }

                // Nothing found, which is worth saying rather than collapsing
                // to a bare box that looks like it is still thinking. Only once
                // something has been typed: an empty box on a fresh machine has
                // nothing to report.
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.launcherRowHeight
                    visible: launcher.count === 0 && Launcher.query.trim().length > 0

                    PanelText {
                        anchors.centerIn: parent
                        text: "Nothing matches that"
                        font.pixelSize: 13
                        color: Theme.muted
                    }
                }
            }
        }
    }

    // ─── one row ─────────────────────────────────────────────────────

    component ResultRow: Rectangle {
        id: line

        required property var result
        required property int ordinal

        readonly property bool isAnswer: line.result.kind === "answer" || line.result.kind === "problem"
        readonly property bool current: line.ordinal === launcher.selected

        Layout.fillWidth: true
        Layout.leftMargin: 8
        Layout.rightMargin: 8
        Layout.preferredHeight: line.isAnswer ? Theme.launcherAnswerHeight : Theme.launcherRowHeight

        radius: 14
        antialiasing: true

        color: line.current ? Theme.launcherSelection : "transparent"
        border.width: 1
        border.color: line.current ? Theme.launcherSelectionEdge : "transparent"

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

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 16
            spacing: 14

            // An application shows its own icon; an answer shows a glyph in the
            // accent, because there is no icon for the number 42.
            Item {
                Layout.preferredWidth: line.isAnswer ? 28 : 32
                Layout.preferredHeight: Layout.preferredWidth
                Layout.alignment: Qt.AlignVCenter

                readonly property string themed: !line.isAnswer && line.result.icon.length > 0 ? Quickshell.iconPath(line.result.icon, true) : ""

                IconImage {
                    anchors.fill: parent
                    visible: parent.themed.length > 0
                    source: parent.themed
                    asynchronous: true
                }

                // Entries with no icon, or an icon name the theme does not
                // have. A blank square in the column would break the run of
                // rows more than a stand-in does.
                Glyph {
                    anchors.centerIn: parent
                    visible: line.isAnswer || parent.themed.length === 0
                    text: line.isAnswer ? line.result.glyph : "󰣆"
                    font.pixelSize: line.isAnswer ? 21 : 18
                    color: line.result.kind === "problem" ? Theme.urgent : (line.isAnswer ? Theme.accent : Theme.muted)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: line.isAnswer ? 3 : 1

                PanelText {
                    Layout.fillWidth: true
                    text: line.result.title
                    elide: Text.ElideRight

                    // The answer is the thing on screen worth reading, so it is
                    // set at a size you can read without stopping.
                    font.pixelSize: line.isAnswer ? 26 : 14
                    font.weight: line.isAnswer ? Font.DemiBold : Font.Medium
                    color: line.result.kind === "problem" ? Theme.urgent : Theme.text
                }

                PanelText {
                    Layout.fillWidth: true
                    visible: line.result.subtitle.length > 0
                    text: line.result.subtitle
                    elide: Text.ElideRight
                    font.pixelSize: 11
                    color: Theme.muted
                }

                // Where a rate came from and how old it is. Under the
                // conversion rather than beside it: it is a footnote on the
                // answer, and a footnote does not compete for the same line.
                PanelText {
                    Layout.fillWidth: true
                    visible: line.result.note.length > 0
                    text: line.result.note
                    elide: Text.ElideRight
                    font.pixelSize: 10
                    color: Theme.muted
                    opacity: 0.8
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            // Hovering moves the selection rather than drawing a second
            // highlight of its own. There is one selected row at a time, and
            // the mouse and the arrow keys are two ways of choosing it.
            //
            // Driven by movement rather than by entering: a row that arrives
            // under a pointer nobody has touched has not been hovered, it has
            // been landed on, and taking the selection there would undo what
            // the query just chose.
            onPositionChanged: launcher.selected = line.ordinal

            onClicked: {
                launcher.selected = line.ordinal;
                launcher.activate();
            }
        }
    }
}
