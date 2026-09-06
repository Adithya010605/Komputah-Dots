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
// summoned by Win+R and it is a card — one frosted surface in the upper third
// of a desktop that is otherwise left exactly as it was, neither blurred nor
// dimmed. The picker takes the screen over because looking around it is the
// whole point; this is in the way of what you were doing for a second and a
// half, and it only has to be legible over it.
//
// It opens as the search field and nothing else, and grows the first time you
// type. So the rows only ever arrive in answer to a keystroke — which is what
// makes them worth animating in at all.
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

    // Bumped every time the card is summoned, and watched by the rows, which
    // replay their arrival on it.
    //
    // Needed because opening the launcher twice in a row usually does not change
    // the list at all: closing clears the query, so the second open is already
    // showing the same run of most-used applications the first one ended on, the
    // Repeater has no reason to rebuild anything, and the rows would simply be
    // there — the card sliding into a list that was already sitting in it. This
    // is how the cascade gets told that a new showing has begun even when the
    // contents of it have not moved.
    property int wave: 0

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
        launcher.wave++;
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

        // Nothing behind the card but a way out of it.
        //
        // No scrim, where the wallpaper picker has one: that surface is a place
        // you go and look around in, and dimming what is behind it is how it
        // takes the screen over. This one is in the way of what you were doing
        // for a second and a half, and there is no reason for the work behind it
        // to go dark and come back.
        //
        // Being genuinely transparent rather than nearly so is also what keeps
        // the desktop sharp, since the layer rule decides what to blur by alpha
        // and this sheet has none. See the rule in hyprland.lua.
        MouseArea {
            anchors.fill: parent
            onClicked: launcher.hide()
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

            // Arriving, the card carries a little past where it stops and eases
            // back — the same weighted settle the drip has, scaled down to the
            // fourteen pixels this one travels. Leaving, it falls away with the
            // ease running the other way round: a surface that gathers speed on
            // its way out is gone, where one that decelerates looks like it is
            // still deciding.
            Behavior on y {
                NumberAnimation {
                    duration: launcher.open ? Theme.launcherRise : Theme.launcherFadeOut
                    easing.type: launcher.open ? Easing.OutBack : Easing.InCubic
                    easing.overshoot: Theme.launcherOvershoot
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: launcher.open ? Theme.launcherRise : Theme.launcherFadeOut
                    easing.type: launcher.open ? Easing.OutBack : Easing.InCubic
                    easing.overshoot: Theme.launcherOvershoot
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: launcher.open ? Theme.launcherFadeIn : Theme.launcherFadeOut
                    easing.type: Easing.OutCubic
                }
            }

            // The card resizes as results come and go, and it stretches to
            // them rather than snapping — the same behaviour the bar has when
            // a module appears on it.
            //
            // Plain OutCubic, and no overshoot anywhere near it: this runs on
            // every keystroke, and an edge that bounces each time a letter lands
            // is not a card breathing, it is a card wobbling.
            Behavior on height {
                NumberAnimation {
                    duration: Theme.launcherResize
                    easing.type: Easing.OutCubic
                }
            }

            // The same lit glass the bar is made of, carrying a heavier wash of
            // the wallpaper than the panels do — see Theme.launcherWash for why
            // this one surface needs it.
            GlassSheen {
                tint: Theme.launcherWash
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

                        // In the accent whether or not anything has been typed.
                        // It used to come up grey and colour in on the first
                        // keystroke, which was a nice idea and the wrong one now
                        // that an empty card is *only* this row: the one mark on
                        // screen when the launcher opens should be the one that
                        // says what it is.
                        Glyph {
                            text: "󰍉"
                            font.pixelSize: 18
                            color: Theme.menuAccent
                        }

                        TextInput {
                            id: field

                            Layout.fillWidth: true

                            verticalAlignment: TextInput.AlignVCenter
                            font.family: Theme.fontFamily
                            font.pixelSize: 19
                            font.weight: Font.Medium
                            color: Theme.text
                            selectionColor: Theme.menuAccentSoft
                            selectedTextColor: Theme.text
                            selectByMouse: true
                            clip: true

                            // The caret in the wallpaper accent, at the weight
                            // of a stroke in the face it sits in rather than the
                            // hairline Qt draws by default. Left on Qt's own
                            // blink: a caret is the one thing on screen that is
                            // *supposed* to be a hard on and off, and softening
                            // it into a pulse would make the box look like it
                            // were thinking rather than waiting.
                            cursorDelegate: Rectangle {
                                width: 2
                                radius: 1
                                color: Theme.menuAccent
                            }

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
                            id: caption

                            readonly property string action: {
                                const row = Launcher.results[launcher.selected];
                                if (!row)
                                    return "";
                                if (row.kind === "app")
                                    return "Enter to open";
                                if (row.kind === "answer")
                                    return "Enter to copy";
                                return "";
                            }

                            // Held at its last words while it fades out, so the
                            // caption goes quiet rather than being cut off
                            // mid-sentence — the words only change once there is
                            // nothing on screen to change. Assigned rather than
                            // bound, because the binding that expresses this
                            // reads its own text and would be a loop.
                            property string held: ""

                            onActionChanged: {
                                if (caption.action.length > 0)
                                    caption.held = caption.action;
                            }

                            text: caption.held

                            opacity: caption.action.length > 0 ? 1 : 0
                            visible: opacity > 0

                            font.pixelSize: 11
                            color: Theme.menuAccent

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.launcherGlide
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }

                // ─── the results ─────────────────────────────────────

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    visible: launcher.count > 0
                    color: Theme.launcherRule
                }

                Item {
                    id: list

                    Layout.fillWidth: true
                    Layout.topMargin: launcher.count > 0 ? 8 : 0
                    Layout.bottomMargin: launcher.count > 0 ? 8 : 0
                    Layout.preferredHeight: rows.implicitHeight

                    // Where the selection sits, worked out from the results
                    // themselves rather than by asking the Repeater for the
                    // delegate at that index.
                    //
                    // Every row's height is decided by its kind and nothing
                    // else, so the layout is arithmetic and can be done here
                    // exactly as the ColumnLayout will do it. Reading it back
                    // off a live item would mean holding a reference to
                    // something the Repeater destroys and rebuilds on every
                    // keystroke — null for a frame each time, and the selection
                    // collapsing to nothing in the gap.
                    function heightOf(row) {
                        if (!row)
                            return Theme.launcherRowHeight;

                        return (row.kind === "answer" || row.kind === "problem") ? Theme.launcherAnswerHeight : Theme.launcherRowHeight;
                    }

                    readonly property real selectionY: {
                        let top = 0;

                        for (let i = 0; i < launcher.selected && i < Launcher.results.length; i++)
                            top += list.heightOf(Launcher.results[i]) + Theme.launcherRowSpacing;

                        return top;
                    }

                    readonly property real selectionHeight: list.heightOf(Launcher.results[launcher.selected])

                    // One shape, moved. Under the rows rather than over them, so
                    // it never sits between a name and the eye reading it.
                    Rectangle {
                        id: selection

                        x: Theme.launcherRowInset
                        width: Math.max(0, list.width - Theme.launcherRowInset * 2)

                        y: list.selectionY
                        height: list.selectionHeight

                        radius: Theme.launcherRowRadius
                        antialiasing: true

                        color: Theme.launcherSelection
                        border.width: 1
                        border.color: Theme.launcherSelectionEdge

                        // Nothing to select, nothing to show — and it fades
                        // rather than vanishing, so emptying the box does not
                        // leave a rectangle blinking out on its own.
                        opacity: launcher.count > 0 ? 1 : 0

                        Behavior on y {
                            NumberAnimation {
                                duration: Theme.launcherGlide
                                easing.type: Easing.OutCubic
                            }
                        }

                        // Travels with the same ease as the move itself, so
                        // stepping between an answer and an application — the
                        // one place two rows differ in height — reads as one
                        // shape changing shape, not as a slide with a resize
                        // arriving after it.
                        Behavior on height {
                            NumberAnimation {
                                duration: Theme.launcherGlide
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.launcherGlide
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    ColumnLayout {
                        id: rows

                        width: parent.width
                        spacing: Theme.launcherRowSpacing

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

    component ResultRow: Item {
        id: line

        required property var result
        required property int ordinal

        readonly property bool isAnswer: line.result.kind === "answer" || line.result.kind === "problem"
        readonly property bool current: line.ordinal === launcher.selected

        Layout.fillWidth: true
        Layout.leftMargin: Theme.launcherRowInset
        Layout.rightMargin: Theme.launcherRowInset
        Layout.preferredHeight: line.isAnswer ? Theme.launcherAnswerHeight : Theme.launcherRowHeight

        // No fill and no border: the selection is one shape sliding underneath
        // all of these, not something each row switches on and off.

        // 0 the instant the row exists, 1 once it has finished arriving. One
        // number driving both the fade and the drop, so the two can never come
        // apart.
        property real arrival: 0

        opacity: line.arrival

        // A transform rather than a margin, because the row's position belongs
        // to the ColumnLayout — nudging it through a Layout property would ask
        // the whole column to re-lay-out on every frame of the animation, and
        // drag the selection's arithmetic along with it.
        transform: Translate {
            y: (1 - line.arrival) * Theme.launcherRowDrop
        }

        SequentialAnimation {
            id: entrance

            // Each row a beat behind the one above it, up to the point where the
            // wait would be the thing you noticed rather than the cascade.
            PauseAnimation {
                duration: Math.min(line.ordinal, Theme.launcherStaggerCap) * Theme.launcherStagger
            }

            NumberAnimation {
                target: line
                property: "arrival"
                to: 1
                duration: Theme.launcherRowRise
                easing.type: Easing.OutCubic
            }
        }

        // Two ways in. A new query rebuilds the Repeater's delegates, so this
        // row is newly born and runs its arrival on completion; reopening the
        // card on an unchanged list builds nothing, and the wave is what tells
        // these already-standing rows to come in again.
        Component.onCompleted: entrance.start()

        readonly property int wave: launcher.wave

        onWaveChanged: {
            line.arrival = 0;
            entrance.restart();
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

                // The selected row's icon comes forward a little. The one place
                // in the shell where scale is used on something being read, and
                // it is allowed here for the same reason it is refused on the
                // bar pills: an icon has no stems to hint onto the pixel grid, so
                // resampling it softens the edges rather than smearing letters.
                scale: line.current ? 1.08 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.launcherGlide
                        easing.type: Easing.OutCubic
                    }
                }

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
                    color: line.result.kind === "problem" ? Theme.urgent : (line.isAnswer ? Theme.menuAccent : Theme.muted)
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

                // Lifts out of the grey on the selected row. What an application
                // *is* only matters for the one you are about to open — on the
                // rest it is there to be scanned past, and keeping it dim is
                // what makes the run of names readable.
                PanelText {
                    Layout.fillWidth: true
                    visible: line.result.subtitle.length > 0
                    text: line.result.subtitle
                    elide: Text.ElideRight
                    font.pixelSize: 11
                    color: line.current ? Qt.rgba(1, 1, 1, 0.78) : Theme.muted

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.launcherGlide
                            easing.type: Easing.OutCubic
                        }
                    }
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
