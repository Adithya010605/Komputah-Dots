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

    // And the lock screen. One call, and deliberately only one: there is no
    // `unlock` here, because a lock screen with an IPC call that opens it is a
    // lock screen anything running as this user can open.
    //
    //   quickshell -c bar ipc call lock lock
    IpcHandler {
        target: "lock"

        function lock(): void {
            Lock.lock();
        }

        // Whether the session is currently locked, so hypr/scripts/lock.sh can
        // tell an already-locked session from a shell that is not answering and
        // fall back to hyprlock only in the second case.
        function status(): string {
            return Lock.locked ? "locked" : "unlocked";
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
        // Taller than the bar itself by the slack the spring at the end of the
        // drop needs, so the stretch is not clipped off by the layer surface.
        implicitHeight: Theme.barHeight + Theme.overshootRoom

        // Only the sliver reserved — see Theme.barExclusive. The bar hangs over
        // what is underneath and gets out of the way, rather than pushing every
        // window on the display down by its own height for the whole session;
        // what it does keep is the few pixels it is still showing, so nothing
        // ends up with its own border tucked underneath the glass.
        exclusiveZone: Theme.barExclusive

        // What the compositor is allowed to send a pointer to: exactly the
        // glass that is currently on screen, and nothing else. Without this the
        // window would swallow every click in a full-width strip across the top
        // of the display — including the long runs of empty desktop either side
        // of the bar, which is most of that strip.
        mask: Region {
            x: Math.round(surface.x)
            y: 0
            width: Math.round(surface.width)
            height: Math.round(surface.height)
        }

        // Whether the bar is down.
        //
        // Hover brings it down. An open panel holds it there, because a panel
        // hangs off the bar's underside and cannot be left attached to an edge
        // that has gone home — and so does a toast, which arrives without
        // anyone asking for it and would otherwise hang from nothing.
        readonly property bool wanted: reach.hovered || PanelState.openPanel.length > 0 || Notices.popups.length > 0

        readonly property bool down: bar.wanted || grace.running

        onWantedChanged: {
            if (bar.wanted)
                grace.stop();
            else
                grace.restart();
        }

        Timer {
            id: grace

            interval: Theme.barRetractDelay
            repeat: false
        }

        Rectangle {
            id: surface

            // Flush with the top of the display: the bar hangs off the screen
            // edge rather than floating in front of the desktop.
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top

            // The bar is exactly as wide as what is on it, capped by the
            // configured ceiling and by the screen. It used to be pinned at the
            // ceiling, which left a long run of empty glass past the window
            // name on one side and past the gear on the other.
            width: Math.min(Theme.barWidth, parent.width - Theme.edgeMargin * 2, modules.implicitWidth + Theme.barPadEnds * 2)

            // How far the bar has come out of the screen edge — which is its
            // height, because the top edge never moves. It is welded to the top
            // of the display, so the drop is the glass growing downward out of
            // that edge rather than the bar sliding down from somewhere above
            // it, and the spring at the end is a stretch rather than a jump
            // away from the thing it is attached to. Exactly what every panel
            // does to the bar, one level up.
            height: bar.down ? Theme.barHeight : Theme.barPeek

            Behavior on height {
                NumberAnimation {
                    duration: bar.down ? Theme.barRevealDuration : Theme.barRetractDuration
                    easing.type: bar.down ? Easing.OutBack : Easing.InCubic
                    easing.overshoot: Theme.dripOvershoot
                }
            }

            // The modules are pinned where they sit on the full-height bar and
            // clipped away until the glass has come down far enough to show
            // them — they are revealed by the bar arriving, not carried down by
            // it. Centring them in a surface whose height is being animated
            // would slide and squash the whole row on every reveal.
            clip: true

            // Modules come and go — the battery when it is unplugged, the count
            // beside the bell — and the glass should stretch to them rather
            // than snapping to a new width.
            Behavior on width {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }

            // The whole bar is its own hover target, so the pointer landing
            // anywhere on the sliver brings it down and it stays down for as
            // long as the pointer is on it. A HoverHandler rather than a
            // MouseArea because it is sitting over every module on the bar and
            // must not take a single click off any of them.
            HoverHandler {
                id: reach
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
                value: Theme.barBottomRadius
            }

            // Square where it meets the top of the screen, round on the two
            // edges that are left hanging.
            radius: Theme.barBottomRadius
            topLeftRadius: 0
            topRightRadius: 0
            antialiasing: true

            color: Theme.glass
            border.width: 1
            border.color: Theme.glassBorder

            // The same wash and lit edge the panels carry, so the bar and
            // anything dripping out of it are made of one material.
            GlassSheen {}

            RowLayout {
                id: modules

                anchors.horizontalCenter: parent.horizontalCenter

                // Against the bar's full height rather than its current one, so
                // the row holds one position on screen while the glass moves
                // past it.
                y: (Theme.barHeight - modules.implicitHeight) / 2

                spacing: Theme.moduleSpacing

                // Faded with the drop as well as clipped by it. The clip alone
                // wipes the row into view a slice at a time, which on a line of
                // text reads as the letters being cut in half rather than as the
                // bar arriving.
                opacity: bar.down ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: bar.down ? Theme.fadeInDuration : Theme.fadeOutDuration
                        easing.type: Easing.OutCubic
                    }
                }

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

    // And the last of them, which is not summoned at all — it is asked for by
    // hypr/scripts/lock.sh, on behalf of the keybind, hypridle's timeout and
    // logind's before-sleep hook alike.
    //
    // In this process for the same reason as the three above, plus one that
    // only applies to this one: a lock screen that has to start before it can
    // cover the screen is a lock screen with a gap in front of it, and the gap
    // is exactly as long as it takes to parse a config and load a wallpaper.
    // Here, everything it draws with is already warm.
    LockScreen {}
}
