import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/"

// A panel that hangs off the underside of the bar.
//
// The whole signature interaction lives here so every panel in the shell drips
// identically: the card grows downward out of the bar, narrows at the join as
// though surface tension were pulling on it, overshoots, settles, and is
// reabsorbed on the way back up.
//
// The card is drawn one radius taller than it shows and pinned above a clip
// line at the bar's edge, so its rounded top is cut off — only the free-hanging
// bottom stays round, and the join with the bar reads as one surface.
Scope {
    id: drip

    // Panel identity. Doubles as the layershell namespace, so the Hyprland blur
    // rule for this panel keeps working: quickshell-<name>.
    property string name: ""

    property int panelWidth: 336
    property Component body: null

    // Bound to the shared panel state by default. Toasts hang off the same
    // machinery without being a panel you opened, so they replace this with a
    // condition of their own — and turn off the two things that only make
    // sense for a panel you clicked for.
    property bool open: PanelState.openPanel === drip.name

    // A surface that appears on its own must not swallow the next click
    // anywhere on screen, nor take the keyboard away from what you are typing
    // into.
    property bool catchesClicks: true
    property bool takesFocus: true

    // Where to hang from when this surface is not opened through PanelState.
    property string anchorModule: ""

    // Kept alive slightly past the close so the retract can finish playing.
    property bool rendered: false

    // Captured when this panel opens rather than read live, so a later panel
    // opening somewhere else cannot drag this one sideways mid-retract.
    property real anchorX: 960

    onOpenChanged: {
        if (drip.open) {
            unrender.stop();
            drip.rendered = true;

            // A panel gets its position from the click that opened it; a toast
            // has no click, so it reads the module's position itself.
            if (drip.anchorModule.length > 0)
                drip.anchorX = PanelState.anchorFor(drip.anchorModule);
        } else {
            unrender.restart();
        }
    }

    Connections {
        target: PanelState

        function onOpened(name) {
            if (name === drip.name)
                drip.anchorX = PanelState.anchorX;
        }
    }

    Timer {
        id: unrender

        interval: Theme.unrenderDelay
        repeat: false
        onTriggered: {
            if (!drip.open)
                drip.rendered = false;
        }
    }

    // ─── click-outside catcher ───────────────────────────────────────
    //
    // Its own namespace so no blur rule applies to the transparent sheet.
    // Anchored to the top, which layershell places below the bar's exclusive
    // zone — so the bar itself stays clickable and clicking another module
    // moves the drip straight there instead of merely dismissing this one.

    PanelWindow {
        visible: drip.rendered && drip.catchesClicks
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.namespace: "quickshell-" + drip.name + "-catcher"
        WlrLayershell.layer: WlrLayer.Top

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        MouseArea {
            anchors.fill: parent
            onClicked: PanelState.close()
        }
    }

    // ─── the panel ───────────────────────────────────────────────────

    PanelWindow {
        id: popup

        visible: drip.rendered
        color: "transparent"
        exclusiveZone: 0

        WlrLayershell.namespace: "quickshell-" + drip.name
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: drip.open && drip.takesFocus ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        implicitWidth: drip.panelWidth
        implicitHeight: panelBody.cardHeight + Theme.overshootRoom

        anchors {
            top: true
            left: true
        }

        margins {
            // Centred under the module that opened it, nudged just far enough
            // to keep its top edge under the bar. The attachment to the bar is
            // never given up — only the perfect centring is.
            left: PanelState.anchoredLeft(drip.anchorX, popup.implicitWidth, popup.screen ? popup.screen.width : 1920)
        }

        Item {
            id: panelBody

            anchors.fill: parent
            focus: true

            Keys.onEscapePressed: PanelState.close()

            readonly property int cardHeight: bodyLoader.implicitHeight + Theme.padding * 2

            Item {
                id: clipper

                x: 0
                y: 0
                width: parent.width
                height: reveal
                clip: true

                // How much of the card is exposed, growing downward from the
                // bar's underside.
                property real reveal: drip.open ? panelBody.cardHeight : 0

                // Surface tension: the column narrows at the pinch and springs
                // back out to full width as the droplet settles.
                property real neck: drip.open ? 1 : Theme.neckPinch

                transform: Scale {
                    origin.x: clipper.width / 2
                    origin.y: 0
                    xScale: clipper.neck
                }

                Behavior on reveal {
                    NumberAnimation {
                        duration: drip.open ? Theme.dripOpenDuration : Theme.dripCloseDuration
                        easing.type: drip.open ? Easing.OutBack : Easing.InCubic
                        easing.overshoot: Theme.dripOvershoot
                    }
                }

                Behavior on neck {
                    NumberAnimation {
                        duration: drip.open ? Theme.neckOpenDuration : Theme.neckCloseDuration
                        easing.type: drip.open ? Easing.OutBack : Easing.InCubic
                        easing.overshoot: Theme.neckOvershoot
                    }
                }

                Rectangle {
                    id: card

                    // Lifted by one radius so its rounded top sits above the
                    // clip line — only the free-hanging bottom edge stays
                    // rounded.
                    y: -Theme.cardRadius
                    width: parent.width

                    // Tracks the reveal exactly, so the overshoot elongates the
                    // card instead of exposing a gap beneath it.
                    height: clipper.reveal + Theme.cardRadius

                    color: Theme.glass
                    border.color: Theme.glassBorder
                    border.width: 1
                    radius: Theme.cardRadius
                    antialiasing: true

                    // The wallpaper's own colour, sitting in the glass just
                    // strongly enough to belong to the desktop behind it.
                    //
                    // The flat wash rather than the lit glass the bar and the
                    // launcher card are painted with, and deliberately: a
                    // highlight marks the edge where a pane faces the light, and
                    // this card's top is not an edge — it is the join with the
                    // bar. Lighting it would draw a bright seam across the one
                    // place in the shell that has to read as a single surface.
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        antialiasing: true
                        color: Theme.glassTint
                    }

                    Loader {
                        id: bodyLoader

                        x: Theme.padding
                        // Offsets the card's lift, keeping the content padded
                        // from the visible top edge rather than the hidden one.
                        y: Theme.padding + Theme.cardRadius
                        width: card.width - Theme.padding * 2

                        sourceComponent: drip.body
                        active: drip.rendered

                        opacity: drip.open ? 1 : 0

                        Behavior on opacity {
                            NumberAnimation {
                                duration: drip.open ? Theme.fadeInDuration : Theme.fadeOutDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }
}
