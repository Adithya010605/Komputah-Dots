import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/components"

// What is playing, at a fixed width. Click drops the media panel; right-click
// toggles playback and the wheel steps tracks, as before.
BarPill {
    id: pill

    hPad: 13
    scrollable: true
    panelName: "media"
    implicitWidth: Theme.mprisModuleWidth
    active: PanelState.isOpen("media")

    onTriggered: PanelState.toggle("media", pill.screenCenter())

    onSecondary: {
        const player = Players.active;
        if (player && player.canTogglePlaying)
            player.togglePlaying();
    }

    onScrolled: up => {
        const player = Players.active;
        if (!player)
            return;

        // Wheel up is "back a track", matching the old bindings.
        if (up && player.canGoPrevious)
            player.previous();
        else if (!up && player.canGoNext)
            player.next();
    }

    BarText {
        Layout.preferredWidth: Theme.mprisModuleWidth - pill.hPad * 2

        // Centred, playing or not. The pill is a fixed width and a title
        // rarely fills it, so a left-pinned one sat against the edge with a
        // pool of empty glass after it — the same way the window name does.
        horizontalAlignment: Text.AlignHCenter

        elide: Text.ElideRight
        text: Players.barText
        color: Players.players.length === 0 ? Theme.muted : Theme.text

        Behavior on color {
            ColorAnimation {
                duration: Theme.hoverDuration
                easing.type: Easing.OutCubic
            }
        }
    }
}
