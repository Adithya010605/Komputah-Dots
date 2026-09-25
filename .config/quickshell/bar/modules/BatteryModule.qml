import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import "root:/"
import "root:/components"

// Charge level, with the ten-step glyph ramp waybar used and a bolt while it
// is filling.
BarPill {
    id: pill

    readonly property var battery: UPower.displayDevice

    readonly property int percent: {
        if (!pill.battery || !pill.battery.isPresent)
            return 0;

        // UPower reports a fraction here, but be forgiving in case a backend
        // hands over whole percent instead.
        const raw = pill.battery.percentage;
        return Math.round(raw <= 1 ? raw * 100 : raw);
    }

    // On mains rather than strictly filling. A finished battery reports
    // FullyCharged and one held at a charge limit reports PendingCharge, and
    // testing only for Charging puts the ramp glyph back on a laptop that has
    // been plugged in all afternoon — which then disagrees with the wall socket
    // and with the lock screen, where the same question is asked the same way.
    readonly property bool charging: {
        if (!pill.battery)
            return false;

        const state = pill.battery.state;

        return state === UPowerDeviceState.Charging || state === UPowerDeviceState.FullyCharged || state === UPowerDeviceState.PendingCharge;
    }

    interactive: false
    visible: pill.battery && pill.battery.isPresent

    BarText {
        text: {
            if (pill.charging)
                return "󰂄 " + pill.percent + "%";

            const icons = ["󰂃", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂"];
            const step = Math.max(0, Math.min(icons.length - 1, Math.floor(pill.percent / 10)));
            return icons[step] + " " + pill.percent + "%";
        }
    }
}
