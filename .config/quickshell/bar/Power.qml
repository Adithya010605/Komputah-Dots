pragma Singleton

import QtQuick
import Quickshell

// The five ways out of a session, and how each of them is actually done.
//
// Separated from the wheel that shows them for the same reason Launcher is
// separated from LauncherMenu: what a power menu offers and how it is drawn are
// different questions, and only one of them is about circles.
//
// The commands are the ones hyprland.lua already settled on rather than the ones
// the rofi script used, which were subtly worse in two places and are worth not
// inheriting. See lock and suspend below.
Singleton {
    id: root

    // Order is the order they sit on the rim, and it runs from the one you will
    // press most to the one you had better mean: lock, suspend, log out, reboot,
    // shut down. The wheel opens on the first of them.
    //
    // `heavy` marks the two that end other people's unsaved work as well as your
    // own. It only changes how they are drawn — nothing here asks twice, because
    // the menu it replaces never did either, and adding a confirmation step to a
    // menu somebody has been dismissing with Escape for a year is how you teach
    // them to press Enter through it.
    //
    // The glyphs are written as escapes rather than as the characters
    // themselves, which is the one place this file departs from the rest of the
    // shell. They are Nerd Font private-use codepoints: invisible in most
    // editors, indistinguishable from each other in the ones that do show them,
    // and — as this file found out the hard way — silently droppable by anything
    // in the chain that is not careful with the plane they live in. An escape
    // survives a careless copy and can be read without the font installed.
    // In order: a padlock, a crescent moon, a door with an arrow leaving it, a
    // circling arrow, a power symbol.
    readonly property var actions: [
        {
            "glyph": "\uf023",
            "title": "Lock",
            "detail": "Lock the session",
            "heavy": false,
            "command": [Quickshell.env("HOME") + "/.config/hypr/scripts/lock.sh"]
        },
        {
            "glyph": "\uf186",
            "title": "Suspend",
            "detail": "Lock, then sleep",
            "heavy": false,
            "command": ["sh", "-c", "loginctl lock-session && sleep 1 && systemctl suspend"]
        },
        {
            "glyph": "\udb80\udf43",
            "title": "Logout",
            "detail": "End the Hyprland session",
            "heavy": true,
            "command": ["hyprctl", "dispatch", "exit"]
        },
        {
            "glyph": "\uead2",
            "title": "Reboot",
            "detail": "Restart the machine",
            "heavy": true,
            "command": ["systemctl", "reboot"]
        },
        {
            "glyph": "\uf011",
            "title": "Shutdown",
            "detail": "Power the machine off",
            "heavy": true,
            "command": ["systemctl", "poweroff"]
        }
    ]

    readonly property int count: root.actions.length

    // ─── doing it ────────────────────────────────────────────────────

    // Two things worth saying about the commands above, because both differ from
    // ~/.config/rofi/scripts/power-menu.sh and both differences are deliberate:
    //
    //   lock      goes through hypr/scripts/lock.sh rather than running hyprlock
    //             directly. hyprlock refuses to stack a second lock client, and
    //             the bare call would happily try — the script is the one path
    //             that checks first.
    //
    //   suspend   waits for the lock surface to actually map before going down,
    //             rather than backgrounding hyprlock and sleeping half a second
    //             in the hope that it did. The old form raced, and losing that
    //             race means the machine wakes up unlocked.
    //
    // execDetached rather than a Process, and this is the important line in the
    // file. A Process is a child of the shell, and every action here either
    // replaces the session the shell is running in or takes the machine down
    // with it — so the shell is going to die partway through its own child's
    // work. Lock is where that bites first and worst: hyprlock would come up
    // owned by a quickshell that is about to be reloaded or restarted, and
    // losing the lock screen because the bar reloaded leaves the session sitting
    // unlocked. Detached, the action is the session manager's problem and not
    // this process's.
    function run(index: int): bool {
        if (index < 0 || index >= root.count)
            return false;

        Quickshell.execDetached(root.actions[index].command);
        return true;
    }
}
