pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What is on the desktop, what else could be, and how to swap between them.
//
// The swap itself lives in set-wallpaper.sh, because it is three things that
// have to happen together — hyprpaper, pywal, and the persisted config — and
// because a shell script stays runnable from a keybind. This singleton is only
// the state around it: the list, which one is live, and whether a swap is
// currently in flight.
//
// Nothing here re-themes anything. Theme.qml is already watching the palette
// pywal writes, so the colours follow the wallpaper on their own.
Singleton {
    id: root

    readonly property string directory: Quickshell.env("HOME") + "/walls"
    readonly property string script: Quickshell.env("HOME") + "/.config/quickshell/bar/set-wallpaper.sh"

    // Absolute paths, name-sorted, as found by the scan below.
    property var files: []

    // The live wallpaper. Read from pywal's own record of what it last themed
    // from rather than from hyprpaper, because that file is what survives a
    // restart and it is a plain path rather than a per-monitor listing.
    property string current: ""

    // True from the click until the script exits. The panel dims and stops
    // accepting clicks while it is set, so a double-click cannot race two
    // swaps against each other.
    property bool applying: false

    property string error: ""

    // ─── naming ──────────────────────────────────────────────────────

    // "mountains-4.jpg" reads as "Mountains 4" in the panel. The files are
    // named for the machine; the panel is read by a person.
    function displayName(path) {
        const cut = path.lastIndexOf("/");
        const file = cut < 0 ? path : path.slice(cut + 1);

        const dot = file.lastIndexOf(".");
        const stem = dot <= 0 ? file : file.slice(0, dot);

        const words = stem.replace(/[_-]+/g, " ").replace(/\s+/g, " ").trim();
        return words.length === 0 ? file : words.charAt(0).toUpperCase() + words.slice(1);
    }

    function isCurrent(path) {
        return path.length > 0 && path === root.current;
    }

    // ─── the list ────────────────────────────────────────────────────

    function refresh() {
        if (!scan.running)
            scan.running = true;
    }

    Process {
        id: scan

        running: true

        // -maxdepth 1: a wallpaper folder, not a photo library. Sorted here
        // rather than in QML so the order is stable across rescans.
        command: ["sh", "-c", "find " + JSON.stringify(root.directory) + " -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) | sort"]

        stdout: StdioCollector {
            waitForEnd: true

            onStreamFinished: {
                const found = text.split("\n").filter(line => line.trim().length > 0);
                root.files = found;

                if (found.length === 0)
                    root.error = "No images in " + root.directory;
                else if (root.error.startsWith("No images"))
                    root.error = "";
            }
        }
    }

    // ─── which one is live ───────────────────────────────────────────

    FileView {
        path: Quickshell.env("HOME") + "/.cache/wal/wal"

        preload: true
        blockLoading: true
        watchChanges: true

        onFileChanged: reload()
        onTextChanged: root.current = text().trim()
    }

    // ─── the swap ────────────────────────────────────────────────────

    function apply(path) {
        if (root.applying || path.length === 0 || path === root.current)
            return;

        root.error = "";
        root.applying = true;

        swap.command = [root.script, path];
        swap.running = true;
    }

    Process {
        id: swap

        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const message = text.trim();
                if (message.length > 0)
                    root.error = message.split("\n").pop();
            }
        }

        onExited: code => {
            root.applying = false;

            if (code !== 0 && root.error.length === 0)
                root.error = "Could not set that wallpaper";
        }
    }
}
