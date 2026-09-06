pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The applications on the machine, ranked against what has been typed.
//
// The list itself is Quickshell's — it already reads the XDG desktop entries
// and watches the directories they live in, so there is nothing here that
// scans. What is here is the ordering, which is the part that decides whether a
// launcher feels like it knows you or like a filing cabinet.
//
// Two things make the order:
//
//   how well the query matches   the letters you typed, where they landed, and
//                                whether they landed on the start of a word
//   how often you launch it      counted per application and decayed, so what
//                                you opened this morning outranks what you
//                                opened constantly last year
//
// The second is the one that matters in practice. Almost every launch is of
// something launched before, so an empty box lists what you actually use and
// two letters is usually enough to put the right thing first.
Singleton {
    id: root

    // For entries that ask to be run in a terminal. The same one hyprland.lua
    // binds to Alt+Return.
    readonly property string terminal: "kitty"

    readonly property string statePath: Quickshell.env("HOME") + "/.local/state/quickshell/launcher.json"

    // ─── the list ────────────────────────────────────────────────────

    // NoDisplay entries are the ones the spec says not to show in menus:
    // MIME handlers, the halves of a split package, settings panes that only
    // exist to be opened by something else.
    readonly property var entries: {
        const all = DesktopEntries.applications.values;
        const shown = [];

        for (const entry of all) {
            if (!entry.noDisplay)
                shown.push(entry);
        }

        return shown;
    }

    // ─── how often things get used ───────────────────────────────────

    // id -> { count, last }. Kept in ~/.local/state because it is neither
    // configuration nor a cache: losing it costs the ordering it has learnt,
    // and no amount of re-running anything brings it back.
    property var usage: ({})

    // Half a launch every three weeks. Long enough that a tool used through a
    // project stays near the top for the length of it, short enough that the
    // project ending eventually moves it back down.
    readonly property real halfLife: 21 * 86400000

    function frecency(id) {
        const record = root.usage[id];
        if (!record)
            return 0;

        const age = Date.now() - (record.last ? record.last : 0);
        const decay = Math.pow(0.5, Math.max(0, age) / root.halfLife);

        // Diminishing returns on the count: the difference between one launch
        // and ten should be large, and between fifty and sixty almost nothing.
        return Math.log2(1 + (record.count ? record.count : 0)) * decay;
    }

    function remember(id) {
        if (id.length === 0)
            return;

        const next = {};
        for (const key in root.usage)
            next[key] = root.usage[key];

        const previous = next[id];
        next[id] = {
            "count": (previous && previous.count ? previous.count : 0) + 1,
            "last": Date.now()
        };

        root.usage = next;
        store.setText(JSON.stringify(next));
    }

    FileView {
        id: store

        path: root.statePath

        preload: true
        atomicWrites: true

        // Nothing has been launched yet on a fresh machine, and an empty
        // ranking is the correct starting state rather than an error — so the
        // missing file is handled here and kept out of the log.
        printErrors: false
        onLoadFailed: root.usage = ({})

        onTextChanged: {
            const raw = text().trim();
            if (raw.length === 0)
                return;

            try {
                root.usage = JSON.parse(raw);
            } catch (problem) {
                root.usage = ({});
            }
        }
    }

    // atomicWrites renames a temporary file over the target, which needs the
    // directory to be there. Run once, costs nothing when it already is.
    Process {
        running: true
        command: ["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/quickshell"]
    }

    // ─── matching ────────────────────────────────────────────────────

    // Every letter of the query has to appear, in order, somewhere in the
    // candidate — that is the whole rule. The score is about *where*: letters
    // that start a word are worth much more than letters in the middle of one,
    // and letters that follow the previous match are worth more than letters
    // that had to be hunted for. "fox" scores highly against "Firefox" but
    // "gimp" beats it outright against "GIMP".
    //
    // Returns 0 for no match, so any positive number is a hit.
    function score(candidate, query) {
        const haystack = candidate.toLowerCase();
        const needle = query.toLowerCase();

        if (needle.length === 0)
            return 1;
        if (needle.length > haystack.length)
            return 0;

        // The two cases worth short-circuiting, because they are what most
        // queries are and no per-letter walk can rank them as clearly.
        if (haystack === needle)
            return 1000;
        if (haystack.startsWith(needle))
            return 700 + (needle.length / haystack.length) * 100;

        let total = 0;
        let at = 0;
        let run = 0;

        for (let i = 0; i < needle.length; i++) {
            const found = haystack.indexOf(needle[i], at);
            if (found < 0)
                return 0;

            let points = 10;

            const before = found > 0 ? haystack[found - 1] : " ";
            if (found === 0)
                points += 60;
            else if (" -_./".includes(before))
                points += 45;

            // Consecutive letters compound rather than adding flat, so a whole
            // word found intact pulls away from the same letters scattered.
            if (found === at && i > 0) {
                run++;
                points += 15 * run;
            } else {
                run = 0;
            }

            // Something found near the front is more likely to be the thing
            // being named than something found deep in a description.
            points += Math.max(0, 12 - found);

            total += points;
            at = found + 1;
        }

        // Against a short name, a match covers most of it; against a long
        // comment the same letters say much less.
        return total * (0.5 + 0.5 * (needle.length / haystack.length));
    }

    // The fields an application can be found by, and what a hit on each is
    // worth relative to a hit on the name. Searching the comment is why
    // "browser" finds Firefox, and weighting it this far down is why it never
    // outranks something actually called that.
    function match(entry, query) {
        let best = root.score(entry.name, query);

        if (entry.genericName && entry.genericName.length > 0)
            best = Math.max(best, root.score(entry.genericName, query) * 0.85);

        const keywords = entry.keywords ? entry.keywords : [];
        for (const keyword of keywords)
            best = Math.max(best, root.score(keyword, query) * 0.8);

        // The executable name, which is what a lot of things are known by even
        // when their entry is called something else entirely.
        const id = entry.id ? entry.id.replace(/\.desktop$/, "") : "";
        if (id.length > 0)
            best = Math.max(best, root.score(id, query) * 0.7);

        if (entry.comment && entry.comment.length > 0)
            best = Math.max(best, root.score(entry.comment, query) * 0.4);

        return best;
    }

    // ─── the ranking ─────────────────────────────────────────────────

    function search(query: string, limit: int): var {
        const trimmed = query.trim();
        const results = [];

        for (const entry of root.entries) {
            const used = root.frecency(entry.id);

            if (trimmed.length === 0) {
                // Nothing typed: purely what you use, most-used first. The
                // launcher no longer asks for this — an empty box there shows no
                // rows at all — but the ranking is the honest answer to an empty
                // query and this stays the function's contract rather than
                // something the one caller happens not to exercise.
                results.push({
                    "entry": entry,
                    "rank": used
                });
                continue;
            }

            const quality = root.match(entry, trimmed);
            if (quality <= 0)
                continue;

            // Frecency lifts a match rather than deciding it, so typing the
            // full name of something never opened still puts it first. The
            // multiplier is on the match so the lift is proportional: a weak
            // match on a favourite does not overtake a strong match on
            // something else.
            results.push({
                "entry": entry,
                "rank": quality * (1 + used * 0.35)
            });
        }

        results.sort((a, b) => {
            if (b.rank !== a.rank)
                return b.rank - a.rank;
            return a.entry.name.localeCompare(b.entry.name);
        });

        return results.slice(0, limit).map(result => result.entry);
    }

    // ─── launching ───────────────────────────────────────────────────

    function launch(entry) {
        if (!entry)
            return;

        root.remember(entry.id);

        // Terminal entries are the one case the desktop file cannot run on its
        // own — it names a command and asks for a terminal to be found for it,
        // and which terminal that is is a property of this machine.
        if (entry.runInTerminal) {
            terminalLaunch.command = [root.terminal, "-e"].concat(entry.command);
            terminalLaunch.running = true;
            return;
        }

        entry.execute();
    }

    Process {
        id: terminalLaunch
    }
}
