pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import "root:/"
import "root:/components"
import "root:/modules"
import "root:/panels"

// The bar, and everything that hangs off it.
//
// Bar and panels live in one process so a panel can be told exactly where its
// module sits — the old screenshot calibration that guessed at waybar module
// positions is gone entirely.
ShellRoot {
    id: root

    // Volume and mute do not populate on these nodes unless something is
    // holding them, and the bar reads both.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    // Panels by keybind as well as by click. They still hang off their own
    // module, because every module keeps its position on file.
    //
    //   quickshell -c bar ipc call panel toggle audio
    IpcHandler {
        target: "panel"

        function toggle(name: string): void {
            PanelState.toggleByName(name);
        }

        // Named open/close rather than show/hide: `show` is also an `ipc`
        // subcommand and the CLI swallows it before the call.
        function open(name: string): void {
            PanelState.openByName(name);
        }

        function close(): void {
            PanelState.close();
        }
    }

    // The wallpaper picker is not one of the bar's panels, so it gets its own
    // target rather than a name in the one above:
    //
    //   quickshell -c bar ipc call wallpaper toggle
    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            wallpaperMenu.toggle();
        }

        function open(): void {
            wallpaperMenu.show();
        }

        function close(): void {
            wallpaperMenu.hide();
        }
    }

    // Same reasoning as the wallpaper target above: the launcher is not one of
    // the bar's panels, so it is addressed on its own.
    //
    //   quickshell -c bar ipc call launcher toggle
    IpcHandler {
        target: "launcher"

        function toggle(): void {
            appLauncher.toggle();
        }

        function open(): void {
            appLauncher.show();
        }

        function close(): void {
            appLauncher.hide();
        }
    }

    // And the power wheel, on the same reasoning again:
    //
    //   quickshell -c bar ipc call power toggle
    IpcHandler {
        target: "power"

        function toggle(): void {
            powerMenu.toggle();
        }

        function open(): void {
            powerMenu.show();
        }

        function close(): void {
            powerMenu.hide();
        }
    }

    PanelWindow {
        id: bar

        color: "transparent"

        WlrLayershell.namespace: "quickshell-bar"
        WlrLayershell.layer: WlrLayer.Top

        anchors {
            top: true
            left: true
            right: true
        }

        // The window spans the full width even though the bar does not, which
        // is what lets a module report its position in plain screen pixels.
        implicitHeight: Theme.barExclusive
        exclusiveZone: Theme.barExclusive

        Rectangle {
            id: surface

            anchors.horizontalCenter: parent.horizontalCenter
            y: Theme.barMarginTop

            // The bar is exactly as wide as what is on it, capped by the
            // configured ceiling and by the screen. It used to be pinned at the
            // ceiling, which left a long run of empty glass past the window
            // name on one side and past the gear on the other.
            width: Math.min(Theme.barWidth, parent.width - Theme.edgeMargin * 2, modules.implicitWidth + Theme.barPadEnds * 2)
            height: Theme.barHeight

            // Modules come and go — the battery when it is unplugged, the count
            // beside the bell — and the glass should stretch to them rather
            // than snapping to a new width.
            Behavior on width {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }

            // The bar no longer spans the display, so panels have to be told
            // where it starts and ends or they hang off the end of it. The
            // window is full width and centred, so these are screen pixels.
            Binding {
                target: PanelState
                property: "barLeft"
                value: (bar.width - surface.width) / 2
            }

            Binding {
                target: PanelState
                property: "barRight"
                value: (bar.width + surface.width) / 2
            }

            Binding {
                target: PanelState
                property: "barInset"
                value: surface.height / 2
            }

            radius: 999
            antialiasing: true

            color: Theme.glass
            border.width: 1
            border.color: Theme.glassBorder

            // The same wash and lit edge the panels carry, so the bar and
            // anything dripping out of it are made of one material.
            GlassSheen {}

            RowLayout {
                id: modules

                anchors.centerIn: parent
                spacing: Theme.moduleSpacing

                WindowModule {}

                Separator {}

                WorkspacesModule {}

                Separator {}

                MprisModule {}

                Separator {}

                ClockModule {}

                PomoModule {}

                VolumeModule {}

                BacklightModule {}

                MemoryModule {}

                BatteryModule {}

                NotificationModule {}

                // The tray pill is gone: it held nm-applet and blueman-applet,
                // and both of those now live inside the settings panel.
                SettingsModule {}
            }
        }
    }

    // ─── what hangs from it ──────────────────────────────────────────

    AudioPanel {}

    MediaPanel {}

    PomoPanel {}

    SystemPanel {}

    SettingsPanel {}

    NotificationPanel {}

    // Not a panel you open: the same drip, hanging off the bell on its own
    // whenever something comes in.
    NotificationToasts {}

    // ─── and what does not hang from it ──────────────────────────────

    // No module, no anchor, no drip: summoned by keybind and taking over the
    // screen. It lives in this process anyway so it shares the palette and is
    // already loaded when the key is pressed.
    WallpaperMenu {
        id: wallpaperMenu
    }

    // The same: no module, no anchor, summoned by Super+R. In this process so
    // the application index and the usage ranking are already built and warm
    // when the key is pressed — a launcher that has to start before it can
    // search is a launcher you wait for.
    LauncherMenu {
        id: appLauncher
    }

    // The same again, and the wallpaper picker's wheel at a fraction of its
    // size. In this process because the alternative — spawning rofi to ask a
    // five-way question — is what this replaces.
    PowerMenu {
        id: powerMenu
    }

}
