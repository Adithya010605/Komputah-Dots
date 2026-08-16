import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Pipewire
import "root:/"
import "root:/components"

// Output volume. Click drops the audio panel, right-click still reaches for
// pavucontrol, and the wheel moves the level.
BarPill {
    id: pill

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property int percent: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0

    scrollable: true
    panelName: "audio"
    active: PanelState.isOpen("audio")

    onTriggered: PanelState.toggle("audio", pill.screenCenter())
    onSecondary: pavucontrol.running = true

    onScrolled: up => {
        if (!pill.sink || !pill.sink.audio)
            return;

        pill.sink.audio.volume = Math.max(0, Math.min(1, pill.sink.audio.volume + (up ? 0.02 : -0.02)));
    }

    Process {
        id: pavucontrol

        command: ["pavucontrol"]
    }

    BarText {
        text: {
            if (pill.muted)
                return "󰝟";

            // Waybar's three-step ramp: quiet, middling, loud.
            const icons = ["\uf026", "\uf027", "\uf028"];
            const step = pill.percent < 34 ? 0 : (pill.percent < 67 ? 1 : 2);
            return icons[step] + "  " + pill.percent + "%";
        }

        color: pill.muted ? Theme.muted : Theme.text

        Behavior on color {
            ColorAnimation {
                duration: Theme.hoverDuration
                easing.type: Easing.OutCubic
            }
        }
    }
}
