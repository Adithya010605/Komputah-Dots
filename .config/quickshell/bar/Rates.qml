pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Exchange rates, and the cache they live in between fetches.
//
// The rates are the one thing in this shell that cannot be worked out from the
// machine, so this is the only part of the launcher that touches the network —
// and it does so as rarely as it can get away with. The source is the European
// Central Bank's daily reference set, which is published once a working day, so
// fetching more often than that would return the same numbers.
//
// Nothing is fetched at login. The cache on disk is read at startup and the
// launcher asks for a refresh when it opens, so a machine that never converts a
// currency never makes a request. A stale cache still answers — a rate from
// yesterday is worth far more than an error message — and says how old it is.
//
// api.frankfurter.dev needs no key and no account, which is why it is the one
// used here: a dotfiles repo that has to be handed a secret before it works is
// not a dotfiles repo.
Singleton {
    id: root

    readonly property string cacheDirectory: Quickshell.env("HOME") + "/.cache/quickshell"
    readonly property string cachePath: root.cacheDirectory + "/rates.json"

    // Everything is held against the euro because that is what the ECB
    // publishes against. Any other pair is the two euro rates divided, which is
    // exact rather than a second lookup.
    readonly property string base: "EUR"

    // Code -> euros per unit. EUR itself is seeded so the base needs no special
    // case anywhere else.
    property var rates: ({
            "EUR": 1
        })

    // The day the ECB published what is in the table, as it reports it.
    property string day: ""

    property bool fetching: false
    property string error: ""

    readonly property bool known: Object.keys(root.rates).length > 1

    // ─── names ───────────────────────────────────────────────────────
    //
    // So a conversion can say "US Dollar to Indian Rupee" rather than repeating
    // the two codes the query already contains.

    readonly property var names: ({
            "AUD": "Australian Dollar",
            "BGN": "Bulgarian Lev",
            "BRL": "Brazilian Real",
            "CAD": "Canadian Dollar",
            "CHF": "Swiss Franc",
            "CNY": "Chinese Yuan",
            "CZK": "Czech Koruna",
            "DKK": "Danish Krone",
            "EUR": "Euro",
            "GBP": "Pound Sterling",
            "HKD": "Hong Kong Dollar",
            "HUF": "Hungarian Forint",
            "IDR": "Indonesian Rupiah",
            "ILS": "Israeli Shekel",
            "INR": "Indian Rupee",
            "ISK": "Icelandic Króna",
            "JPY": "Japanese Yen",
            "KRW": "South Korean Won",
            "MXN": "Mexican Peso",
            "MYR": "Malaysian Ringgit",
            "NOK": "Norwegian Krone",
            "NZD": "New Zealand Dollar",
            "PHP": "Philippine Peso",
            "PLN": "Polish Złoty",
            "RON": "Romanian Leu",
            "SEK": "Swedish Krona",
            "SGD": "Singapore Dollar",
            "THB": "Thai Baht",
            "TRY": "Turkish Lira",
            "USD": "US Dollar",
            "ZAR": "South African Rand"
        })

    // What people type instead of the code. Symbols first, then the handful of
    // spelt-out names common enough to be worth catching.
    readonly property var aliases: ({
            "$": "USD",
            "us$": "USD",
            "usd$": "USD",
            "dollar": "USD",
            "dollars": "USD",
            "buck": "USD",
            "bucks": "USD",
            "€": "EUR",
            "euro": "EUR",
            "euros": "EUR",
            "£": "GBP",
            "pound": "GBP",
            "pounds": "GBP",
            "quid": "GBP",
            "sterling": "GBP",
            "¥": "JPY",
            "yen": "JPY",
            "₹": "INR",
            "rs": "INR",
            "rs.": "INR",
            "rupee": "INR",
            "rupees": "INR",
            "inr₹": "INR",
            "₩": "KRW",
            "won": "KRW",
            "franc": "CHF",
            "francs": "CHF",
            "yuan": "CNY",
            "rmb": "CNY",
            "real": "BRL",
            "peso": "MXN",
            "pesos": "MXN",
            "zloty": "PLN",
            "złoty": "PLN",
            "rand": "ZAR",
            "shekel": "ILS",
            "lira": "TRY",
            "baht": "THB",
            "ringgit": "MYR",
            "rupiah": "IDR",
            "krona": "SEK",
            "krone": "NOK"
        })

    // The symbol to print in front of an amount, where there is one worth
    // printing. Codes are used for the rest, which reads better than inventing
    // an ambiguous glyph for a currency nobody writes with one.
    readonly property var symbols: ({
            "USD": "$",
            "EUR": "€",
            "GBP": "£",
            "JPY": "¥",
            "INR": "₹",
            "KRW": "₩",
            "CNY": "¥",
            "BRL": "R$",
            "PHP": "₱",
            "THB": "฿",
            "TRY": "₺",
            "ILS": "₪"
        })

    // ─── reading a currency out of a word ────────────────────────────

    // Returns the ISO code, or "" if the word is not money.
    //
    // Answers from the name table rather than from the rates, which is the
    // difference between "usd is not a currency" and "I do not have a rate for
    // usd yet". The rates arrive from a file read and possibly a request, and
    // for the moment before they do, the first answer would be wrong — a query
    // typed in that window would fall through to the applications and come back
    // empty rather than saying it was fetching.
    function resolve(word: string): string {
        const key = word.trim().toLowerCase();
        if (key.length === 0)
            return "";

        const code = root.aliases[key] ? root.aliases[key] : key.toUpperCase();
        return root.names[code] !== undefined ? code : "";
    }

    function nameOf(code: string): string {
        return root.names[code] ? root.names[code] : code;
    }

    function symbolOf(code: string): string {
        return root.symbols[code] ? root.symbols[code] : "";
    }

    // ─── converting ──────────────────────────────────────────────────

    function convert(amount: real, from: string, to: string): real {
        const a = root.rates[from];
        const b = root.rates[to];

        if (a === undefined || b === undefined || a === 0)
            return NaN;

        // Both sides are euros-per-unit, so the euro cancels and no second
        // lookup or rounding step is needed.
        return amount * (b / a);
    }

    // How old what is on screen is, in plain words. Weekends and holidays mean
    // "today" is often two or three days back even when everything is working,
    // so this counts days rather than passing judgement on them.
    readonly property string age: {
        if (root.day.length === 0)
            return "";

        const published = new Date(root.day + "T00:00:00");
        if (isNaN(published.getTime()))
            return root.day;

        const midnight = new Date();
        midnight.setHours(0, 0, 0, 0);

        const days = Math.round((midnight.getTime() - published.getTime()) / 86400000);

        if (days <= 0)
            return "today";
        if (days === 1)
            return "yesterday";
        return days + " days ago";
    }

    // ─── the cache ───────────────────────────────────────────────────

    FileView {
        id: cache

        path: root.cachePath

        preload: true
        watchChanges: true

        onFileChanged: reload()
        onLoadFailed: {
            // No cache yet is the ordinary state of a fresh machine, not a
            // failure worth putting on screen. The first open fetches one.
            root.stale = true;
        }

        onTextChanged: {
            const raw = text().trim();
            if (raw.length === 0)
                return;

            try {
                const parsed = JSON.parse(raw);
                if (!parsed || !parsed.rates)
                    return;

                const table = {
                    "EUR": 1
                };
                for (const code in parsed.rates)
                    table[code] = parsed.rates[code];

                root.rates = table;
                root.day = parsed.date ? parsed.date : "";
                root.error = "";
                root.stale = root.dayIsOld(root.day);
            } catch (problem) {
                root.error = "Could not read the cached rates";
            }
        }
    }

    // Whether the table on disk is old enough to be worth a request. Not a
    // binding on the clock: it is set when the cache is read and cleared when a
    // fetch lands, and the launcher only asks about it when it opens.
    property bool stale: true

    // The ECB publishes once per working day, so anything from today or
    // yesterday is current, and over a weekend Friday's numbers are what
    // everyone else is quoting too.
    function dayIsOld(published) {
        if (published.length === 0)
            return true;

        const when = new Date(published + "T00:00:00");
        if (isNaN(when.getTime()))
            return true;

        const midnight = new Date();
        midnight.setHours(0, 0, 0, 0);

        return (midnight.getTime() - when.getTime()) / 86400000 >= 1;
    }

    // ─── fetching ────────────────────────────────────────────────────

    // Called by the launcher when it opens. Does nothing at all in the common
    // case, which is the point of it being called from there rather than run on
    // a timer.
    function refresh() {
        if (root.fetching || !root.stale)
            return;

        root.fetching = true;
        fetch.running = true;
    }

    Process {
        id: fetch

        // Written to a temporary file and moved into place rather than
        // downloaded over the cache, so a request that dies halfway through
        // leaves yesterday's perfectly usable rates alone instead of
        // truncating them to nothing.
        //
        // -f so an HTTP error is a non-zero exit rather than a cache full of
        // error page.
        command: ["sh", "-c", "mkdir -p " + JSON.stringify(root.cacheDirectory) + " && curl -fsS -m 12 'https://api.frankfurter.dev/v1/latest?base=" + root.base + "' -o " + JSON.stringify(root.cachePath + ".part") + " && mv " + JSON.stringify(root.cachePath + ".part") + " " + JSON.stringify(root.cachePath)]

        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                const message = text.trim();
                if (message.length > 0)
                    root.error = message.split("\n").pop();
            }
        }

        onExited: code => {
            root.fetching = false;

            if (code === 0) {
                root.stale = false;
                root.error = "";
                return;
            }

            // The table is whatever the cache had, which may well be enough to
            // answer with. The message is only shown under an answer, as a note
            // on its age, rather than replacing it.
            if (root.error.length === 0)
                root.error = "Could not reach the rates service";
        }
    }
}
