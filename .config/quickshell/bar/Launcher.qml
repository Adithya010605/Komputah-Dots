pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What the launcher is showing, and what happens when you pick it.
//
// One list, not several. A query is offered to each thing that might be able to
// answer it and whatever comes back goes into the same run of rows, so there
// are no modes to be in and no prefix to remember: "2+2" is a sum because it
// looks like one, "100 usd in inr" is a conversion for the same reason, and
// everything else is the applications. An answer sits above the applications
// because if the query parsed as a sum it almost certainly was one — but the
// applications are still under it, so a query that was meant to be a name and
// happened to parse is one keypress from being corrected.
//
// The rows are plain objects rather than a QML model. Everything about a row is
// decided the moment the query changes, which means the view is a Repeater over
// an array and nothing in it has to know where its contents came from.
Singleton {
    id: root

    property string query: ""

    // Enough to fill the card without it becoming a directory listing. Past
    // about eight rows nobody is reading them — they are retyping.
    readonly property int limit: 8

    // ─── the rows ────────────────────────────────────────────────────

    readonly property var results: {
        const rows = [];

        // An empty box is a box, and nothing else. The card opens as the search
        // field alone and grows the moment there is something to show — so what
        // arrives on Super+R is the one thing you came to use, rather than a
        // list of applications chosen for you that you were going to type past
        // anyway. It also means the rows only ever appear in answer to a
        // keystroke, which is what makes them worth animating in.
        if (root.query.trim().length === 0)
            return rows;

        const answer = root.answerFor(root.query);
        if (answer)
            rows.push(answer);

        for (const entry of Apps.search(root.query, root.limit))
            rows.push({
                "kind": "app",
                "title": entry.name,
                "subtitle": root.describe(entry),
                "note": "",
                "glyph": "",
                "icon": entry.icon ? entry.icon : "",
                "entry": entry,
                "copy": ""
            });

        return rows;
    }

    readonly property int count: root.results.length

    // What an application is, in the words its own author used. The generic
    // name is the good one — "Web Browser" — and the comment is the fallback
    // for the many entries that do not set it.
    function describe(entry) {
        if (entry.genericName && entry.genericName.length > 0)
            return entry.genericName;
        if (entry.comment && entry.comment.length > 0)
            return entry.comment;
        return "Application";
    }

    // ─── the answer ──────────────────────────────────────────────────

    // Conversions are asked first because they are the narrower question: they
    // need a separator word and two units either side, and something that
    // specific is not an accident. A sum is anything with an operator in it,
    // which is a much easier thing to type by mistake.
    function answerFor(text) {
        const trimmed = text.trim();
        if (trimmed.length === 0)
            return null;

        if (Convert.looksLikeConversion(trimmed)) {
            const converted = Convert.evaluate(trimmed);

            if (converted && converted.ok)
                return {
                    "kind": "answer",
                    "title": converted.text,
                    "subtitle": converted.detail,
                    "note": converted.note ? converted.note : "",
                    "glyph": converted.kind === "currency" ? "󰄔" : "󰓡",
                    "icon": "",
                    "entry": null,
                    "copy": root.bare(converted.text)
                };

            // Understood and could not be finished — no rates yet, absolute
            // zero, two units that do not belong together. Worth saying,
            // because the alternative is a query that looks ignored.
            if (converted && !converted.ok)
                return {
                    "kind": "problem",
                    "title": converted.error,
                    "subtitle": "Conversion",
                    "note": "",
                    "glyph": "󰀦",
                    "icon": "",
                    "entry": null,
                    "copy": ""
                };
        }

        if (Maths.looksLikeMath(trimmed)) {
            const sum = Maths.evaluate(trimmed);

            if (sum.ok)
                return {
                    "kind": "answer",
                    "title": Maths.format(sum.value),
                    "subtitle": trimmed.replace(/^=\s*/, ""),
                    "note": "",
                    "glyph": "󰇼",
                    "icon": "",
                    "entry": null,
                    "copy": Maths.format(sum.value).replace(/,/g, "")
                };

            // Half-typed sums are the normal state of the box, so only an
            // explicit = asks for the complaint. Without it a query that is on
            // its way to being something else just falls through to the
            // applications.
            if (trimmed.startsWith("="))
                return {
                    "kind": "problem",
                    "title": sum.error,
                    "subtitle": trimmed,
                    "note": "",
                    "glyph": "󰀦",
                    "icon": "",
                    "entry": null,
                    "copy": ""
                };
        }

        return null;
    }

    // What goes on the clipboard: the number, without the separators or the
    // unit that were put there to make it readable. Pasting "1,234.56 grams"
    // into a spreadsheet is not pasting a number.
    function bare(text) {
        const number = /-?[\d,]+(?:\.\d+)?/.exec(text);
        return number ? number[0].replace(/,/g, "") : text;
    }

    // ─── picking one ─────────────────────────────────────────────────

    // Returns whether the launcher should close. A problem row does neither: it
    // is a message, and dismissing the launcher because you clicked on an
    // explanation would be the wrong way round.
    function activate(index: int): bool {
        if (index < 0 || index >= root.count)
            return false;

        const row = root.results[index];

        if (row.kind === "app") {
            Apps.launch(row.entry);
            return true;
        }

        if (row.kind === "answer" && row.copy.length > 0) {
            root.copyToClipboard(row.copy);
            return true;
        }

        return false;
    }

    // wl-copy rather than Qt's clipboard: the launcher's window is gone a
    // frame later, and a Wayland clipboard offer belongs to the surface that
    // made it — it would be withdrawn on the way out. wl-copy forks a tiny
    // process that outlives the launcher and keeps holding the offer.
    function copyToClipboard(text) {
        copy.command = ["wl-copy", "--", text];
        copy.running = true;
    }

    Process {
        id: copy
    }
}
