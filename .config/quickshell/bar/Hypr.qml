pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Compositor state the bar reads.
//
// Quickshell only learns which workspace and window are focused by watching
// the event stream, so on a cold start it knows nothing at all. Both values
// are therefore seeded from hyprctl once and tracked from events after that.
Singleton {
    id: root

    property int focusedWorkspace: -1

    // Waybar showed the window class rather than the title, and the class is
    // only carried on the `activewindow` event.
    property string focusedClass: ""

    readonly property string windowLabel: focusedClass.length > 0 ? focusedClass : "Desktop"

    // Five workspaces are always on the strip, the way waybar's
    // persistent-workspaces held them. Anything beyond that appears as soon as
    // it exists and drops off again when it empties — a fixed count meant
    // workspace 6 had no dot at all, so switching to it left the strip with
    // nothing highlighted.
    readonly property int persistentWorkspaces: 5

    property var workspaceIds: [1, 2, 3, 4, 5]

    // Ids Hyprland is currently holding open. A workspace only exists while it
    // has windows on it (or is the focused one), which is exactly the
    // occupied/empty distinction the dots draw.
    property var liveIds: []

    function isOccupied(id) {
        return root.liveIds.indexOf(id) !== -1;
    }

    function rebuildWorkspaces() {
        const live = [];
        for (const workspace of Hyprland.workspaces.values) {
            // Special workspaces (scratchpads) carry negative ids and are not
            // somewhere you switch to by number.
            if (workspace.id > 0)
                live.push(workspace.id);
        }

        const ids = [];
        for (let id = 1; id <= root.persistentWorkspaces; id++)
            ids.push(id);

        for (const id of live) {
            if (ids.indexOf(id) === -1)
                ids.push(id);
        }

        // The focused workspace always gets a dot, even in the moment before
        // Hyprland reports it as existing.
        if (root.focusedWorkspace > 0 && ids.indexOf(root.focusedWorkspace) === -1)
            ids.push(root.focusedWorkspace);

        ids.sort((a, b) => a - b);

        root.liveIds = live;
        root.workspaceIds = ids;
    }

    onFocusedWorkspaceChanged: root.rebuildWorkspaces()

    Connections {
        target: Hyprland.workspaces

        function onValuesChanged() {
            root.rebuildWorkspaces();
        }
    }

    // This config is written in Hyprland's lua dialect, where the old
    // "dispatch workspace 3" string is a syntax error rather than a command —
    // clicking a dot silently did nothing until this went through hl.dsp. The
    // plain form is kept for a hyprland.conf setup.
    function goToWorkspace(target) {
        if (Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.focus({workspace=\"" + target + "\"})");
        else
            Hyprland.dispatch("workspace " + target);
    }

    function focusWorkspace(id) {
        root.goToWorkspace(id);
    }

    function cycleWorkspace(forward) {
        // e+1/e-1 walks existing workspaces and wraps, which is what the bar
        // did before.
        root.goToWorkspace(forward ? "e+1" : "e-1");
    }

    Component.onCompleted: {
        workspaceQuery.running = true;
        windowQuery.running = true;
        Hyprland.refreshWorkspaces();
        root.rebuildWorkspaces();
    }

    Process {
        id: workspaceQuery

        command: ["hyprctl", "-j", "activeworkspace"]

        stdout: StdioCollector {
            waitForEnd: true

            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    if (typeof data.id === "number")
                        root.focusedWorkspace = data.id;
                } catch (error) {
                    console.warn("hypr: could not read the active workspace");
                }
            }
        }
    }

    Process {
        id: windowQuery

        command: ["hyprctl", "-j", "activewindow"]

        stdout: StdioCollector {
            waitForEnd: true

            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.focusedClass = data.class ?? "";
                } catch (error) {
                    // An empty desktop returns nothing parseable, which simply
                    // means there is no focused window to name.
                    root.focusedClass = "";
                }
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            switch (event.name) {
            case "activewindow":
                // "class,title" — and "," when focus lands on the desktop.
                root.focusedClass = event.data.split(",")[0];
                break;

            case "workspacev2":
                // "id,name"
                root.focusedWorkspace = parseInt(event.data.split(",")[0], 10);
                break;

            case "focusedmonv2":
                // "monitor,workspaceid"
                root.focusedWorkspace = parseInt(event.data.split(",")[1], 10);
                break;

            case "createworkspacev2":
            case "destroyworkspacev2":
                // The model refreshes itself off these too; asking again costs
                // one socket round trip and closes the window where a dot
                // lingers for a workspace that has just emptied.
                Hyprland.refreshWorkspaces();
                break;
            }
        }
    }
}
