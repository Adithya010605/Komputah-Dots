pragma Singleton

import QtQuick
import Quickshell

// Arithmetic for the launcher.
//
// A real tokeniser and a recursive-descent parser rather than handing the
// string to JavaScript's eval. eval would be shorter and would also happily run
// whatever else it found in the box — the launcher's input is one keystroke
// away from everything on the machine, and "2+2" and "a whole program" should
// not be the same code path. Parsing it also means the failures are legible:
// an unclosed bracket says so instead of coming back as NaN.
//
// Percent is the one thing here that is not plain arithmetic. Raycast's reading
// of it is the useful one and it is what this follows:
//
//   50%          → 0.5        a bare percentage is a fraction
//   20% of 250   → 50         "of" is multiplication
//   250 + 10%    → 275        percent of the thing being added to
//   250 - 10%    → 225
//
// The last two are why parse results carry a flag saying "this node was
// literally a percentage" — 10% means a different number depending on what is
// to the left of it, and only the additive layer knows what that is.
Singleton {
    id: root

    // ─── what counts as a sum ────────────────────────────────────────

    // A bare number is not a question. Neither is a word. Something has to be
    // done to something for the launcher to answer with a total, and this is
    // the cheap check it makes before running the parser at all.
    function looksLikeMath(text: string): bool {
        const trimmed = text.trim();
        if (trimmed.length === 0)
            return false;

        // A leading = is the explicit ask, for the rare case the heuristic
        // below would rather not answer.
        if (trimmed.startsWith("="))
            return trimmed.length > 1;

        if (!/\d/.test(trimmed))
            return false;

        return /[+\-*/^%×÷]|\b(of|mod)\b|\b[a-z]{1,6}\s*\(/i.test(trimmed);
    }

    // ─── evaluating ──────────────────────────────────────────────────

    // Always returns an object rather than throwing: every caller here is a
    // binding re-running on each keystroke, and most keystrokes are the middle
    // of something that is not finished being typed yet.
    function evaluate(text: string): var {
        const source = text.trim().replace(/^=\s*/, "");

        try {
            const tokens = root.tokenise(source);
            if (tokens.length === 0)
                return root.failure("Nothing to work out");

            const state = {
                "tokens": tokens,
                "at": 0
            };

            const node = root.parseExpression(state);

            if (state.at < tokens.length)
                return root.failure("Unexpected " + tokens[state.at].text);

            if (!isFinite(node.value))
                return root.failure(isNaN(node.value) ? "Not a number" : "Too big to hold");

            return {
                "ok": true,
                "value": node.value,
                "error": ""
            };
        } catch (problem) {
            return root.failure(problem.message ? problem.message : String(problem));
        }
    }

    function failure(message) {
        return {
            "ok": false,
            "value": 0,
            "error": message
        };
    }

    function fail(message) {
        throw new Error(message);
    }

    // ─── tokens ──────────────────────────────────────────────────────

    readonly property var constants: ({
            "pi": Math.PI,
            "π": Math.PI,
            "tau": Math.PI * 2,
            "τ": Math.PI * 2,
            "e": Math.E,
            "phi": (1 + Math.sqrt(5)) / 2,
            "inf": Infinity
        })

    // Arity is checked rather than assumed, so min(1) and sqrt(4, 9) are told
    // what they got wrong instead of quietly returning something.
    readonly property var functions: ({
            "sqrt": {
                "arity": 1,
                "fn": a => Math.sqrt(a)
            },
            "cbrt": {
                "arity": 1,
                "fn": a => Math.cbrt(a)
            },
            "abs": {
                "arity": 1,
                "fn": a => Math.abs(a)
            },
            "round": {
                "arity": 1,
                "fn": a => Math.round(a)
            },
            "floor": {
                "arity": 1,
                "fn": a => Math.floor(a)
            },
            "ceil": {
                "arity": 1,
                "fn": a => Math.ceil(a)
            },
            "sign": {
                "arity": 1,
                "fn": a => Math.sign(a)
            },
            "ln": {
                "arity": 1,
                "fn": a => Math.log(a)
            },
            "log": {
                "arity": 1,
                "fn": a => Math.log10(a)
            },
            "log2": {
                "arity": 1,
                "fn": a => Math.log2(a)
            },
            "exp": {
                "arity": 1,
                "fn": a => Math.exp(a)
            },
            // Radians, as the maths library has them. deg() is there for the
            // times you are thinking in degrees, as in sin(deg(30)).
            "sin": {
                "arity": 1,
                "fn": a => Math.sin(a)
            },
            "cos": {
                "arity": 1,
                "fn": a => Math.cos(a)
            },
            "tan": {
                "arity": 1,
                "fn": a => Math.tan(a)
            },
            "asin": {
                "arity": 1,
                "fn": a => Math.asin(a)
            },
            "acos": {
                "arity": 1,
                "fn": a => Math.acos(a)
            },
            "atan": {
                "arity": 1,
                "fn": a => Math.atan(a)
            },
            "deg": {
                "arity": 1,
                "fn": a => a * Math.PI / 180
            },
            "rad": {
                "arity": 1,
                "fn": a => a * 180 / Math.PI
            },
            "min": {
                "arity": -1,
                "fn": (...a) => Math.min(...a)
            },
            "max": {
                "arity": -1,
                "fn": (...a) => Math.max(...a)
            },
            "hypot": {
                "arity": -1,
                "fn": (...a) => Math.hypot(...a)
            },
            "pow": {
                "arity": 2,
                "fn": (a, b) => Math.pow(a, b)
            },
            "root": {
                "arity": 2,
                "fn": (a, b) => Math.pow(a, 1 / b)
            }
        })

    function tokenise(source) {
        const tokens = [];
        let i = 0;

        while (i < source.length) {
            const ch = source[i];

            if (/\s/.test(ch)) {
                i++;
                continue;
            }

            // Hex and binary first: 0x1f has to be one number rather than a
            // zero next to a name.
            const radix = /^0[xb][0-9a-f]+/i.exec(source.slice(i));
            if (radix) {
                const literal = radix[0];
                const base = literal[1].toLowerCase() === "x" ? 16 : 2;
                tokens.push({
                    "type": "number",
                    "value": parseInt(literal.slice(2), base),
                    "text": literal
                });
                i += literal.length;
                continue;
            }

            // A decimal number, with separators allowed inside it and the
            // magnitude suffixes people actually type. 1,234.5 and 2.5k are
            // both one token.
            //
            // The comma is only a separator in a properly grouped run of
            // three, which is what stops it swallowing the ones between
            // arguments: a looser rule reads min(4,9,2) as the single number
            // 492 and answers with it.
            const decimal = /^(?:\d{1,3}(?:,\d{3})+|[\d_]+)?(?:\.\d+)?(?:e[+-]?\d+)?/i.exec(source.slice(i));
            if (decimal && /\d/.test(decimal[0])) {
                const literal = decimal[0];
                let value = parseFloat(literal.replace(/[,_]/g, ""));

                const suffix = /^[kmbt]\b/i.exec(source.slice(i + literal.length));
                let consumed = literal.length;

                if (suffix) {
                    const scale = {
                        "k": 1e3,
                        "m": 1e6,
                        "b": 1e9,
                        "t": 1e12
                    };
                    value *= scale[suffix[0].toLowerCase()];
                    consumed += suffix[0].length;
                }

                tokens.push({
                    "type": "number",
                    "value": value,
                    "text": source.slice(i, i + consumed)
                });
                i += consumed;
                continue;
            }

            const word = /^[a-zπτ][a-z0-9]*/i.exec(source.slice(i));
            if (word) {
                tokens.push({
                    "type": "word",
                    "text": word[0],
                    "key": word[0].toLowerCase()
                });
                i += word[0].length;
                continue;
            }

            if ("+-*/^%(),".includes(ch) || "×÷−".includes(ch)) {
                // The typographic forms are the same operators; normalising
                // here means the parser only ever sees one spelling.
                const normal = {
                    "×": "*",
                    "÷": "/",
                    "−": "-"
                };
                tokens.push({
                    "type": "op",
                    "text": normal[ch] ? normal[ch] : ch
                });
                i++;
                continue;
            }

            root.fail("Cannot read " + ch);
        }

        return tokens;
    }

    // ─── the grammar ─────────────────────────────────────────────────
    //
    // Every parse function returns { value, percent }. `percent` is true only
    // when the node is a bare percentage literal and nothing has been done to
    // it since, which is the one case the additive layer treats specially.

    function peek(state) {
        return state.at < state.tokens.length ? state.tokens[state.at] : null;
    }

    function takeOp(state, options) {
        const token = root.peek(state);
        if (token && token.type === "op" && options.includes(token.text)) {
            state.at++;
            return token.text;
        }
        return "";
    }

    function takeWord(state, options) {
        const token = root.peek(state);
        if (token && token.type === "word" && options.includes(token.key)) {
            state.at++;
            return token.key;
        }
        return "";
    }

    function plain(value) {
        return {
            "value": value,
            "percent": false
        };
    }

    function parseExpression(state) {
        let left = root.parseTerm(state);

        for (;;) {
            const op = root.takeOp(state, ["+", "-"]);
            if (op.length === 0)
                return left;

            const right = root.parseTerm(state);

            // "250 + 10%" is 10% *of 250*, not 250.1. Anywhere else a
            // percentage is just the fraction it already evaluated to.
            const addend = right.percent ? left.value * right.value : right.value;
            left = root.plain(op === "+" ? left.value + addend : left.value - addend);
        }
    }

    function parseTerm(state) {
        let left = root.parseUnary(state);

        for (;;) {
            let op = root.takeOp(state, ["*", "/", "%"]);

            if (op.length === 0) {
                // "mod" spelt out, and "of" as the multiplication it is in
                // "20% of 250".
                const word = root.takeWord(state, ["mod", "of"]);
                if (word.length === 0)
                    return left;
                op = word === "mod" ? "%" : "*";
            }

            const right = root.parseUnary(state);

            if (op === "*") {
                left = root.plain(left.value * right.value);
            } else if (op === "/") {
                if (right.value === 0)
                    root.fail("Cannot divide by zero");
                left = root.plain(left.value / right.value);
            } else {
                if (right.value === 0)
                    root.fail("Cannot divide by zero");
                left = root.plain(left.value % right.value);
            }
        }
    }

    function parseUnary(state) {
        const op = root.takeOp(state, ["+", "-"]);
        if (op.length > 0) {
            const operand = root.parseUnary(state);
            // Negation keeps the percent flag: "250 - -10%" should still know
            // it is holding a percentage.
            return {
                "value": op === "-" ? -operand.value : operand.value,
                "percent": operand.percent
            };
        }

        return root.parsePower(state);
    }

    function parsePower(state) {
        const base = root.parsePostfix(state);

        if (root.takeOp(state, ["^"]).length === 0)
            return base;

        // Right associative, so 2^3^2 is 2^(3^2). The exponent goes through
        // unary so 2^-1 works.
        const exponent = root.parseUnary(state);
        return root.plain(Math.pow(base.value, exponent.value));
    }

    function parsePostfix(state) {
        let node = root.parsePrimary(state);

        // Trailing % is the percentage literal. It only reads as one when
        // there is nothing for it to be the remainder operator between, which
        // is exactly the case where the next token cannot start an operand.
        //
        // "of" and "mod" are words and are not operands, which is the whole of
        // why they are excluded here: without that, the % in "20% of 250" is
        // read as a remainder sign looking for its right-hand side and finds
        // the preposition instead.
        while (root.peek(state) && root.peek(state).type === "op" && root.peek(state).text === "%") {
            const next = state.tokens[state.at + 1];
            const operand = next && (next.type === "number" || (next.type === "op" && next.text === "(") || (next.type === "word" && !["of", "mod"].includes(next.key)));
            if (operand)
                break;

            state.at++;
            node = {
                "value": node.value / 100,
                "percent": true
            };
        }

        return node;
    }

    function parsePrimary(state) {
        const token = root.peek(state);
        if (!token)
            root.fail("Unfinished");

        if (token.type === "number") {
            state.at++;
            return root.plain(token.value);
        }

        if (token.type === "op" && token.text === "(") {
            state.at++;
            const inner = root.parseExpression(state);
            if (root.takeOp(state, [")"]).length === 0)
                root.fail("Missing )");
            return root.plain(inner.value);
        }

        if (token.type === "word") {
            state.at++;

            if (root.constants[token.key] !== undefined)
                return root.plain(root.constants[token.key]);

            const fn = root.functions[token.key];
            if (!fn)
                root.fail("Do not know " + token.text);

            if (root.takeOp(state, ["("]).length === 0)
                root.fail(token.text + " needs brackets");

            const args = [];
            if (!(root.peek(state) && root.peek(state).type === "op" && root.peek(state).text === ")")) {
                for (;;) {
                    args.push(root.parseExpression(state).value);
                    if (root.takeOp(state, [","]).length === 0)
                        break;
                }
            }

            if (root.takeOp(state, [")"]).length === 0)
                root.fail("Missing ) after " + token.text);

            if (fn.arity >= 0 && args.length !== fn.arity)
                root.fail(token.text + " takes " + fn.arity + (fn.arity === 1 ? " number" : " numbers"));
            if (fn.arity < 0 && args.length === 0)
                root.fail(token.text + " needs a number");

            return root.plain(fn.fn(...args));
        }

        root.fail("Unexpected " + token.text);
    }

    // ─── writing the answer down ─────────────────────────────────────

    // Floating point arithmetic on decimal input produces things like
    // 0.30000000000000004, which is the correct answer to a question nobody
    // asked. Rounding to twelve significant figures puts the noise below what
    // is shown without touching any total a person is likely to have typed.
    function format(value: real): string {
        if (!isFinite(value))
            return value > 0 ? "∞" : "-∞";

        if (value === 0)
            return "0";

        const magnitude = Math.abs(value);

        // Past what a thousands-separated run of digits can usefully show,
        // and below what it can show at all, hand over to exponent form.
        if (magnitude >= 1e15 || magnitude < 1e-9)
            return value.toExponential(6).replace(/e([+-])(\d)$/, "e$10$2");

        const rounded = parseFloat(value.toPrecision(12));
        const parts = String(rounded).split(".");

        // Grouped from the right, which is the only part of this that has to
        // be done by hand — toLocaleString would follow the system locale and
        // the rest of the shell does not.
        parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",");

        return parts.join(".");
    }
}
