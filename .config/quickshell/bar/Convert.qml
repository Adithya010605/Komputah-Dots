pragma Singleton

import QtQuick
import Quickshell

// "100 usd in inr", "180 c in f", "12 gb in mib", "6ft in cm".
//
// Currencies and units go through one parser because they are the same
// question — a quantity, and what you would rather see it in — and splitting
// them would mean two places that both have to know how to find the number, the
// unit and the word between them. What differs is only the last step: a
// currency rate comes off the table in Rates, a unit factor is written down
// here, and temperature is neither because its scales do not share a zero.
//
// Words are deliberately resolved to *every* reading they have rather than the
// first one found. "pound" is money and it is also mass, and which one is meant
// is not knowable from that word alone — it is knowable from the other side of
// the query. So both sides are read as sets and the pairing that agrees is the
// answer, which is what lets "10 pounds in kg" and "10 pounds in usd" both mean
// what they obviously mean.
Singleton {
    id: root

    // What separates the quantity from what you want it in. "in" is on this
    // list and is also the abbreviation for inches, which is why the split
    // below takes the last separator rather than the first: in "10 in in cm"
    // the second one is the preposition and the first is the unit.
    readonly property var separators: ["in", "to", "as", "into"]

    // ─── the unit table ──────────────────────────────────────────────
    //
    // Everything is a factor to the dimension's base unit, so a conversion is
    // one multiply and one divide with nothing to get the wrong way round.
    // Temperature is the exception and is handled on its own further down,
    // because its scales are offset as well as scaled.

    readonly property var units: ({
            // length, in metres
            "nm": {
                "dim": "length",
                "factor": 1e-9,
                "label": "nanometres"
            },
            "µm": {
                "dim": "length",
                "factor": 1e-6,
                "label": "micrometres"
            },
            "um": {
                "dim": "length",
                "factor": 1e-6,
                "label": "micrometres"
            },
            "mm": {
                "dim": "length",
                "factor": 0.001,
                "label": "millimetres"
            },
            "cm": {
                "dim": "length",
                "factor": 0.01,
                "label": "centimetres"
            },
            "m": {
                "dim": "length",
                "factor": 1,
                "label": "metres"
            },
            "metre": {
                "dim": "length",
                "factor": 1,
                "label": "metres"
            },
            "metres": {
                "dim": "length",
                "factor": 1,
                "label": "metres"
            },
            "meter": {
                "dim": "length",
                "factor": 1,
                "label": "metres"
            },
            "meters": {
                "dim": "length",
                "factor": 1,
                "label": "metres"
            },
            "km": {
                "dim": "length",
                "factor": 1000,
                "label": "kilometres"
            },
            "in": {
                "dim": "length",
                "factor": 0.0254,
                "label": "inches"
            },
            "inch": {
                "dim": "length",
                "factor": 0.0254,
                "label": "inches"
            },
            "inches": {
                "dim": "length",
                "factor": 0.0254,
                "label": "inches"
            },
            "ft": {
                "dim": "length",
                "factor": 0.3048,
                "label": "feet"
            },
            "foot": {
                "dim": "length",
                "factor": 0.3048,
                "label": "feet"
            },
            "feet": {
                "dim": "length",
                "factor": 0.3048,
                "label": "feet"
            },
            "yd": {
                "dim": "length",
                "factor": 0.9144,
                "label": "yards"
            },
            "yard": {
                "dim": "length",
                "factor": 0.9144,
                "label": "yards"
            },
            "yards": {
                "dim": "length",
                "factor": 0.9144,
                "label": "yards"
            },
            "mi": {
                "dim": "length",
                "factor": 1609.344,
                "label": "miles"
            },
            "mile": {
                "dim": "length",
                "factor": 1609.344,
                "label": "miles"
            },
            "miles": {
                "dim": "length",
                "factor": 1609.344,
                "label": "miles"
            },
            "nmi": {
                "dim": "length",
                "factor": 1852,
                "label": "nautical miles"
            },

            // mass, in kilograms
            "mg": {
                "dim": "mass",
                "factor": 1e-6,
                "label": "milligrams"
            },
            "g": {
                "dim": "mass",
                "factor": 0.001,
                "label": "grams"
            },
            "gram": {
                "dim": "mass",
                "factor": 0.001,
                "label": "grams"
            },
            "grams": {
                "dim": "mass",
                "factor": 0.001,
                "label": "grams"
            },
            "kg": {
                "dim": "mass",
                "factor": 1,
                "label": "kilograms"
            },
            "kilo": {
                "dim": "mass",
                "factor": 1,
                "label": "kilograms"
            },
            "kilos": {
                "dim": "mass",
                "factor": 1,
                "label": "kilograms"
            },
            "kilogram": {
                "dim": "mass",
                "factor": 1,
                "label": "kilograms"
            },
            "kilograms": {
                "dim": "mass",
                "factor": 1,
                "label": "kilograms"
            },
            "t": {
                "dim": "mass",
                "factor": 1000,
                "label": "tonnes"
            },
            "tonne": {
                "dim": "mass",
                "factor": 1000,
                "label": "tonnes"
            },
            "tonnes": {
                "dim": "mass",
                "factor": 1000,
                "label": "tonnes"
            },
            "oz": {
                "dim": "mass",
                "factor": 0.028349523125,
                "label": "ounces"
            },
            "ounce": {
                "dim": "mass",
                "factor": 0.028349523125,
                "label": "ounces"
            },
            "ounces": {
                "dim": "mass",
                "factor": 0.028349523125,
                "label": "ounces"
            },
            "lb": {
                "dim": "mass",
                "factor": 0.45359237,
                "label": "pounds"
            },
            "lbs": {
                "dim": "mass",
                "factor": 0.45359237,
                "label": "pounds"
            },
            "pound": {
                "dim": "mass",
                "factor": 0.45359237,
                "label": "pounds"
            },
            "pounds": {
                "dim": "mass",
                "factor": 0.45359237,
                "label": "pounds"
            },
            "st": {
                "dim": "mass",
                "factor": 6.35029318,
                "label": "stone"
            },
            "stone": {
                "dim": "mass",
                "factor": 6.35029318,
                "label": "stone"
            },

            // time, in seconds
            "ms": {
                "dim": "time",
                "factor": 0.001,
                "label": "milliseconds"
            },
            "s": {
                "dim": "time",
                "factor": 1,
                "label": "seconds"
            },
            "sec": {
                "dim": "time",
                "factor": 1,
                "label": "seconds"
            },
            "secs": {
                "dim": "time",
                "factor": 1,
                "label": "seconds"
            },
            "second": {
                "dim": "time",
                "factor": 1,
                "label": "seconds"
            },
            "seconds": {
                "dim": "time",
                "factor": 1,
                "label": "seconds"
            },
            "min": {
                "dim": "time",
                "factor": 60,
                "label": "minutes"
            },
            "mins": {
                "dim": "time",
                "factor": 60,
                "label": "minutes"
            },
            "minute": {
                "dim": "time",
                "factor": 60,
                "label": "minutes"
            },
            "minutes": {
                "dim": "time",
                "factor": 60,
                "label": "minutes"
            },
            "h": {
                "dim": "time",
                "factor": 3600,
                "label": "hours"
            },
            "hr": {
                "dim": "time",
                "factor": 3600,
                "label": "hours"
            },
            "hrs": {
                "dim": "time",
                "factor": 3600,
                "label": "hours"
            },
            "hour": {
                "dim": "time",
                "factor": 3600,
                "label": "hours"
            },
            "hours": {
                "dim": "time",
                "factor": 3600,
                "label": "hours"
            },
            "d": {
                "dim": "time",
                "factor": 86400,
                "label": "days"
            },
            "day": {
                "dim": "time",
                "factor": 86400,
                "label": "days"
            },
            "days": {
                "dim": "time",
                "factor": 86400,
                "label": "days"
            },
            "wk": {
                "dim": "time",
                "factor": 604800,
                "label": "weeks"
            },
            "week": {
                "dim": "time",
                "factor": 604800,
                "label": "weeks"
            },
            "weeks": {
                "dim": "time",
                "factor": 604800,
                "label": "weeks"
            },
            // The average Gregorian month and year, which is the only
            // definition that makes "90 days in months" answer sensibly.
            "mo": {
                "dim": "time",
                "factor": 2629746,
                "label": "months"
            },
            "month": {
                "dim": "time",
                "factor": 2629746,
                "label": "months"
            },
            "months": {
                "dim": "time",
                "factor": 2629746,
                "label": "months"
            },
            "yr": {
                "dim": "time",
                "factor": 31556952,
                "label": "years"
            },
            "year": {
                "dim": "time",
                "factor": 31556952,
                "label": "years"
            },
            "years": {
                "dim": "time",
                "factor": 31556952,
                "label": "years"
            },

            // data, in bytes. kB is a thousand bytes and KiB is 1024, which is
            // what the standard says and what a disk is sold as; the binary
            // ones are spelt out because that is the only way to ask for them
            // without guessing which of the two someone meant.
            "bit": {
                "dim": "data",
                "factor": 0.125,
                "label": "bits"
            },
            "bits": {
                "dim": "data",
                "factor": 0.125,
                "label": "bits"
            },
            "byte": {
                "dim": "data",
                "factor": 1,
                "label": "bytes"
            },
            "bytes": {
                "dim": "data",
                "factor": 1,
                "label": "bytes"
            },
            "kb": {
                "dim": "data",
                "factor": 1e3,
                "label": "kilobytes"
            },
            "mb": {
                "dim": "data",
                "factor": 1e6,
                "label": "megabytes"
            },
            "gb": {
                "dim": "data",
                "factor": 1e9,
                "label": "gigabytes"
            },
            "tb": {
                "dim": "data",
                "factor": 1e12,
                "label": "terabytes"
            },
            "pb": {
                "dim": "data",
                "factor": 1e15,
                "label": "petabytes"
            },
            "kib": {
                "dim": "data",
                "factor": 1024,
                "label": "kibibytes"
            },
            "mib": {
                "dim": "data",
                "factor": 1048576,
                "label": "mebibytes"
            },
            "gib": {
                "dim": "data",
                "factor": 1073741824,
                "label": "gibibytes"
            },
            "tib": {
                "dim": "data",
                "factor": 1099511627776,
                "label": "tebibytes"
            },

            // volume, in litres. The gallon and its parts are the US ones.
            "ml": {
                "dim": "volume",
                "factor": 0.001,
                "label": "millilitres"
            },
            "cl": {
                "dim": "volume",
                "factor": 0.01,
                "label": "centilitres"
            },
            "l": {
                "dim": "volume",
                "factor": 1,
                "label": "litres"
            },
            "litre": {
                "dim": "volume",
                "factor": 1,
                "label": "litres"
            },
            "litres": {
                "dim": "volume",
                "factor": 1,
                "label": "litres"
            },
            "liter": {
                "dim": "volume",
                "factor": 1,
                "label": "litres"
            },
            "liters": {
                "dim": "volume",
                "factor": 1,
                "label": "litres"
            },
            "tsp": {
                "dim": "volume",
                "factor": 0.00492892159375,
                "label": "teaspoons"
            },
            "tbsp": {
                "dim": "volume",
                "factor": 0.01478676478125,
                "label": "tablespoons"
            },
            "floz": {
                "dim": "volume",
                "factor": 0.0295735295625,
                "label": "fluid ounces"
            },
            "cup": {
                "dim": "volume",
                "factor": 0.2365882365,
                "label": "cups"
            },
            "cups": {
                "dim": "volume",
                "factor": 0.2365882365,
                "label": "cups"
            },
            "pint": {
                "dim": "volume",
                "factor": 0.473176473,
                "label": "pints"
            },
            "pints": {
                "dim": "volume",
                "factor": 0.473176473,
                "label": "pints"
            },
            "quart": {
                "dim": "volume",
                "factor": 0.946352946,
                "label": "quarts"
            },
            "quarts": {
                "dim": "volume",
                "factor": 0.946352946,
                "label": "quarts"
            },
            "gal": {
                "dim": "volume",
                "factor": 3.785411784,
                "label": "gallons"
            },
            "gallon": {
                "dim": "volume",
                "factor": 3.785411784,
                "label": "gallons"
            },
            "gallons": {
                "dim": "volume",
                "factor": 3.785411784,
                "label": "gallons"
            }
        })

    // Temperature, kept apart from the table above. Celsius and Fahrenheit do
    // not agree on where zero is, so there is no single factor that converts
    // them and everything goes via kelvin instead.
    readonly property var temperatures: ({
            "c": "C",
            "°c": "C",
            "celsius": "C",
            "centigrade": "C",
            "f": "F",
            "°f": "F",
            "fahrenheit": "F",
            "k": "K",
            "kelvin": "K"
        })

    readonly property var temperatureLabels: ({
            "C": "°C",
            "F": "°F",
            "K": "K"
        })

    function toKelvin(value, scale) {
        if (scale === "C")
            return value + 273.15;
        if (scale === "F")
            return (value - 32) * 5 / 9 + 273.15;
        return value;
    }

    function fromKelvin(kelvin, scale) {
        if (scale === "C")
            return kelvin - 273.15;
        if (scale === "F")
            return (kelvin - 273.15) * 9 / 5 + 32;
        return kelvin;
    }

    // ─── reading a word ──────────────────────────────────────────────

    // Every meaning a word has, in the order they are worth trying. A word with
    // no meanings comes back empty and the query is not a conversion.
    function readings(word) {
        const key = word.trim().toLowerCase();
        if (key.length === 0)
            return [];

        const found = [];

        const currency = Rates.resolve(key);
        if (currency.length > 0)
            found.push({
                "kind": "currency",
                "code": currency
            });

        if (root.temperatures[key])
            found.push({
                "kind": "temperature",
                "scale": root.temperatures[key]
            });

        const unit = root.units[key];
        if (unit)
            found.push({
                "kind": "unit",
                "dim": unit.dim,
                "factor": unit.factor,
                "label": unit.label
            });

        return found;
    }

    // Two sides agree when they are the same kind of thing — both money, both
    // temperature, or both units of the same dimension.
    function agree(from, to) {
        if (from.kind !== to.kind)
            return false;
        if (from.kind === "unit")
            return from.dim === to.dim;
        return true;
    }

    // ─── splitting the query ─────────────────────────────────────────

    // Every place the query could be cut in two, rightmost first.
    //
    // A list rather than one answer because "10 in in cm" has two candidate
    // separators and only one of them is the preposition — the other is the
    // abbreviation for inches. Which is which cannot be decided from the words:
    // it is decided by trying, and the rightmost cut that leaves a unit on both
    // sides is the right one. Reading it left to right instead gives "10" and
    // "in cm", which is not a question.
    //
    // Matches are found by hand rather than by a global regex because the
    // candidates overlap: the space between the two "in"s belongs to both of
    // them, and exec would consume it with the first and never see the second.
    function splits(text) {
        const found = [];

        const arrow = /\s*(?:→|->|>)\s*/.exec(text);
        if (arrow)
            return [
                {
                    "left": text.slice(0, arrow.index),
                    "right": text.slice(arrow.index + arrow[0].length)
                }
            ];

        const pattern = new RegExp("\\s+(?:" + root.separators.join("|") + ")\\s+", "i");

        for (let at = 0; at < text.length; at++) {
            const hit = pattern.exec(text.slice(at));
            if (!hit)
                break;

            const index = at + hit.index;
            found.push({
                "left": text.slice(0, index),
                "right": text.slice(index + hit[0].length)
            });

            at = index;
        }

        return found.reverse();
    }

    // Pulls the unit off the end of "2 * 3 km" or the front of "$100", leaving
    // whatever is left to be worked out as a sum. Everything before the unit
    // goes through the maths parser, so "(3+2)kg in lb" is a fair question.
    function quantity(text) {
        const trimmed = text.trim();
        if (trimmed.length === 0)
            return null;

        // Leading symbol, as money is written: $100, ₹2,500.
        const prefixed = /^([$€£¥₹₩฿₺₪₱]|R\$)\s*(.+)$/.exec(trimmed);
        if (prefixed)
            return {
                "amount": prefixed[2],
                "word": prefixed[1]
            };

        // Otherwise the unit is the run of letters at the end. Degrees and the
        // micro sign are let in because °C and µm are spelt with them.
        const suffixed = /^(.*?)\s*([a-zµ°][a-z°]*)\s*$/i.exec(trimmed);
        if (!suffixed)
            return null;

        return {
            "amount": suffixed[1],
            "word": suffixed[2]
        };
    }

    // ─── the answer ──────────────────────────────────────────────────

    // Returns null when this is not a conversion at all, so the launcher can
    // fall through to the other things a query might be. An object with ok:
    // false is a conversion that was understood and could not be finished —
    // which is worth saying out loud rather than silently offering nothing.
    function evaluate(text: string): var {
        // The first cut that both sides can be read as something. A cut that
        // yields no units at all is not a wrong answer, it is the wrong cut,
        // so it is skipped rather than reported.
        let complaint = null;

        for (const halves of root.splits(text)) {
            const attempt = root.attempt(halves);

            if (!attempt)
                continue;

            if (attempt.ok)
                return attempt;

            // A cut that named two real things that do not go together — "5 km
            // in kg". Held rather than returned, in case a cut further left
            // turns out to be the one that was meant, and reported only if
            // none of them works.
            if (!complaint)
                complaint = attempt;
        }

        return complaint;
    }

    function attempt(halves) {
        const left = root.quantity(halves.left);
        if (!left)
            return null;

        const target = halves.right.trim();
        // One word, and nothing that could be the start of a sentence about
        // something else.
        if (!/^[a-zµ°$€£¥₹₩฿₺₪₱.]+$/i.test(target))
            return null;

        const sources = root.readings(left.word);
        const targets = root.readings(target);

        if (sources.length === 0 || targets.length === 0)
            return null;

        // The pairing that agrees, which is what settles "pound".
        let from = null;
        let to = null;
        for (const candidateFrom of sources) {
            for (const candidateTo of targets) {
                if (root.agree(candidateFrom, candidateTo)) {
                    from = candidateFrom;
                    to = candidateTo;
                    break;
                }
            }
            if (from)
                break;
        }

        if (!from)
            return {
                "ok": false,
                "error": "Cannot convert " + left.word.toLowerCase() + " to " + target.toLowerCase()
            };

        // A missing amount means one of the thing, which is how a rate is
        // asked for: "usd in inr".
        const source = left.amount.trim();
        let amount = 1;

        if (source.length > 0) {
            const sum = Maths.evaluate(source);
            if (!sum.ok)
                return {
                    "ok": false,
                    "error": sum.error
                };
            amount = sum.value;
        }

        if (from.kind === "currency")
            return root.money(amount, from.code, to.code);

        if (from.kind === "temperature")
            return root.temperature(amount, from.scale, to.scale);

        return root.measure(amount, from, to);
    }

    function money(amount, from, to) {
        if (!Rates.known)
            return {
                "ok": false,
                "error": Rates.fetching ? "Fetching today's rates…" : "No exchange rates yet"
            };

        const value = Rates.convert(amount, from, to);
        if (isNaN(value))
            return {
                "ok": false,
                "error": "No rate for " + from + " to " + to
            };

        // One unit of the source, which is the number people actually quote at
        // each other and is not otherwise recoverable from a converted total.
        const unit = Rates.convert(1, from, to);

        return {
            "ok": true,
            "kind": "currency",
            "value": value,
            "text": root.moneyText(value, to),
            "detail": Rates.nameOf(from) + " to " + Rates.nameOf(to),
            "note": "1 " + from + " = " + Maths.format(parseFloat(unit.toPrecision(6))) + " " + to + (Rates.age.length > 0 ? "  ·  " + Rates.age : "")
        };
    }

    // Money is written to the cent, unlike everything else here, because a
    // currency total with nine decimal places on it is not a currency total.
    function moneyText(value, code) {
        const symbol = Rates.symbolOf(code);
        const rounded = Math.abs(value) >= 1 ? parseFloat(value.toFixed(2)) : parseFloat(value.toPrecision(4));

        return symbol + Maths.format(rounded) + " " + code;
    }

    function temperature(amount, from, to) {
        const kelvin = root.toKelvin(amount, from);

        if (kelvin < 0)
            return {
                "ok": false,
                "error": "Below absolute zero"
            };

        const value = root.fromKelvin(kelvin, to);

        return {
            "ok": true,
            "kind": "temperature",
            "value": value,
            "text": Maths.format(parseFloat(value.toPrecision(6))) + " " + root.temperatureLabels[to],
            "detail": root.temperatureLabels[from] + " to " + root.temperatureLabels[to],
            "note": ""
        };
    }

    function measure(amount, from, to) {
        const value = amount * from.factor / to.factor;

        // Six figures, not twelve. The extra ones are real — the factors are
        // exact — but "11,444.0917969 mebibytes" is a worse answer to "12 gb in
        // mib" than "11,444.1" is, and nobody measuring anything in the
        // physical world needs the rest.
        return {
            "ok": true,
            "kind": "unit",
            "value": value,
            "text": Maths.format(parseFloat(value.toPrecision(6))) + " " + to.label,
            "detail": from.label + " to " + to.label,
            "note": ""
        };
    }

    // ─── is this even a conversion ───────────────────────────────────

    // Cheap enough to run on every keystroke, and only has to be right about
    // "definitely not" — anything that gets past it is handed to the parser,
    // which is the thing that actually decides.
    function looksLikeConversion(text: string): bool {
        if (!/\d/.test(text) && !/[a-z]{3}/i.test(text))
            return false;

        return /\s(?:in|to|as|into)\s|→|->|\s>\s/i.test(text);
    }
}
