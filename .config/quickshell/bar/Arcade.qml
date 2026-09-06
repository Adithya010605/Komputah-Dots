pragma Singleton

import QtQuick
import Quickshell

// The sprite sheet.
//
// Everything 8-bit on the lock screen is drawn from here, and all of it is
// drawn the way an arcade board drew it: a fixed grid of square cells that are
// either lit or they are not. No font is loaded, no image is opened, no path is
// stroked — a glyph is seven strings of five characters, and a sprite is a
// slightly larger version of the same idea.
//
// Bitmaps rather than a pixel font because there is no pixel font on this
// machine and installing one would put the look of the lock screen in a package
// that has to keep being installed. Bitmaps rather than vector shapes because
// the point of the look is the grid: a circle drawn as a circle and then scaled
// down is a smudge, and a circle drawn as thirteen rows of lit cells is Pac-Man.
//
// A row is a string. "#" is lit, "." is not, and the two-character alphabet is
// what makes a glyph legible as its own shape in the source — you can read the
// letters below without running them. Sprites that need more than one colour
// name their extra cells (see the ghost's "o" and "*") and hand the caller a
// palette to look them up in.
Singleton {
    id: root

    // ─── the type ────────────────────────────────────────────────────
    //
    // 5×7, which is the smallest grid that fits a legible capital alphabet with
    // room for a descender-free baseline, and the size nearly every arcade
    // board of the era actually used. Rows are written joined by "/" so one
    // glyph is one line here and the table can be scanned down its left edge;
    // they are split once at startup and never again.

    readonly property int glyphWidth: 5
    readonly property int glyphHeight: 7

    readonly property var table: ({
            "0": ".###./#...#/#..##/#.#.#/##..#/#...#/.###.",
            "1": "..#../.##../..#../..#../..#../..#../.###.",
            "2": ".###./#...#/....#/...#./..#../.#.../#####",
            "3": "#####/...#./..#../...#./....#/#...#/.###.",
            "4": "...#./..##./.#.#./#..#./#####/...#./...#.",
            "5": "#####/#..../####./....#/....#/#...#/.###.",
            "6": "..##./.#.../#..../####./#...#/#...#/.###.",
            "7": "#####/....#/...#./..#../.#.../.#.../.#...",
            "8": ".###./#...#/#...#/.###./#...#/#...#/.###.",
            "9": ".###./#...#/#...#/.####/....#/...#./.##..",
            "A": ".###./#...#/#...#/#####/#...#/#...#/#...#",
            "B": "####./#...#/#...#/####./#...#/#...#/####.",
            "C": ".###./#...#/#..../#..../#..../#...#/.###.",
            "D": "###../#..#./#...#/#...#/#...#/#..#./###..",
            "E": "#####/#..../#..../####./#..../#..../#####",
            "F": "#####/#..../#..../####./#..../#..../#....",
            "G": ".###./#...#/#..../#.###/#...#/#...#/.###.",
            "H": "#...#/#...#/#...#/#####/#...#/#...#/#...#",
            "I": ".###./..#../..#../..#../..#../..#../.###.",
            "J": "..###/...#./...#./...#./...#./#..#./.##..",
            "K": "#...#/#..#./#.#../##.../#.#../#..#./#...#",
            "L": "#..../#..../#..../#..../#..../#..../#####",
            "M": "#...#/##.##/#.#.#/#.#.#/#...#/#...#/#...#",
            "N": "#...#/##..#/##..#/#.#.#/#..##/#..##/#...#",
            "O": ".###./#...#/#...#/#...#/#...#/#...#/.###.",
            "P": "####./#...#/#...#/####./#..../#..../#....",
            "Q": ".###./#...#/#...#/#...#/#.#.#/#..#./.##.#",
            "R": "####./#...#/#...#/####./#.#../#..#./#...#",
            "S": ".####/#..../#..../.###./....#/....#/####.",
            "T": "#####/..#../..#../..#../..#../..#../..#..",
            "U": "#...#/#...#/#...#/#...#/#...#/#...#/.###.",
            "V": "#...#/#...#/#...#/#...#/#...#/.#.#./..#..",
            "W": "#...#/#...#/#...#/#.#.#/#.#.#/##.##/#...#",
            "X": "#...#/#...#/.#.#./..#../.#.#./#...#/#...#",
            "Y": "#...#/#...#/.#.#./..#../..#../..#../..#..",
            "Z": "#####/....#/...#./..#../.#.../#..../#####",
            ":": "...../..#../..#../...../..#../..#../.....",
            ".": "...../...../...../...../...../.##../.##..",
            ",": "...../...../...../...../.##../.##../.#...",
            "-": "...../...../...../#####/...../...../.....",
            "'": "..#../..#../...../...../...../...../.....",
            "!": "..#../..#../..#../..#../..#../...../..#..",
            "?": ".###./#...#/....#/...#./..#../...../..#..",
            "/": "....#/....#/...#./..#../.#.../#..../#....",
            "%": "#...#/#..#./...#./..#../.#.../#..#./#...#",
            "+": "...../..#../..#../#####/..#../..#../.....",
            "(": "..#../.#.../#..../#..../#..../.#.../..#..",
            ")": "..#../...#./....#/....#/....#/...#./..#..",
            " ": "...../...../...../...../...../...../....."
        })

    // The table above, split into rows once. Every glyph on screen is a lookup
    // in here — split-on-demand would be re-splitting the same eight strings
    // sixty times a second for the clock alone.
    property var glyphs: ({})

    // What an unknown character comes out as. A blank rather than a tofu box:
    // the only text this draws is text this file wrote, so a miss is a typo in
    // the shell and not a message from outside, and a hole is easier to spot in
    // a mock-up than a box is.
    readonly property var blank: [".....", ".....", ".....", ".....", ".....", ".....", "....."]

    function glyph(character: string): var {
        const found = root.glyphs[character.toUpperCase()];
        return found !== undefined ? found : root.blank;
    }

    // How wide a string comes out, in cells, tracking included. Callers that
    // centre or right-align pixel text need this before the text exists.
    function measure(text: string, tracking: int): int {
        if (text.length === 0)
            return 0;

        return text.length * root.glyphWidth + (text.length - 1) * tracking;
    }

    // ─── Pac-Man ─────────────────────────────────────────────────────
    //
    // Generated rather than written out, because he is the one sprite here that
    // is genuinely a formula: a disc with a wedge taken out of it, and the only
    // thing that changes between frames is how wide the wedge is. Twelve hand
    // drawn variants of the same circle would be twelve chances to get one row
    // of it wrong.
    //
    // Generated *once*, at startup, into the same array-of-strings every other
    // sprite is. So the cost of the trigonometry is paid one time and the
    // renderer never learns that this sprite came from anywhere different.

    readonly property int pacSize: 13

    // Half the mouth's opening angle, in degrees, over one chomp. It runs open
    // and back shut rather than looping around, which is what makes it read as
    // a jaw rather than as a wheel.
    readonly property var chompAngles: [0, 12, 26, 40, 26, 12]

    // Dying. The arcade's death is a spin; this is the other readable version
    // of the same idea — the mouth keeps opening until there is nothing left of
    // him — and it is the one that survives being drawn on a 13×13 grid.
    readonly property var deathAngles: [40, 58, 76, 94, 112, 130, 150, 170, 180]

    property var pacRight: []
    property var pacLeft: []
    property var pacDeath: []

    // One frame. `half` is half the mouth angle: 0 is a closed circle, 180 is
    // nothing at all.
    function pacFrame(half: real): var {
        const size = root.pacSize;
        const centre = (size - 1) / 2;
        const radius = size / 2;
        const mouth = half * Math.PI / 180;
        const rows = [];

        for (let y = 0; y < size; y++) {
            let row = "";

            for (let x = 0; x < size; x++) {
                const dx = x - centre;
                const dy = y - centre;

                // The wedge is measured from the centre of the grid, so the
                // point of the mouth lands on the middle cell and the jaw opens
                // symmetrically around the axis he is facing.
                const inside = dx * dx + dy * dy <= radius * radius;
                const open = Math.abs(Math.atan2(dy, dx)) < mouth;

                row += (inside && !open) ? "#" : ".";
            }

            rows.push(row);
        }

        return rows;
    }

    function mirror(frame: var): var {
        return frame.map(row => row.split("").reverse().join(""));
    }

    // ─── the ghost ───────────────────────────────────────────────────
    //
    // Hand drawn, because a ghost is not a formula — it is a dome, two eyes and
    // a hem, and the proportions between those three are the whole character of
    // it.
    //
    // "o" is the white of the eye and "*" the pupil, both looked up in a palette
    // the caller passes in. The pupils sit left of centre: the only time a ghost
    // is on screen is when it is coming for Pac-Man, and Pac-Man is to its left.
    //
    // Two frames, differing only in the hem. That is exactly what the arcade
    // animated too — the ghost does not walk, its skirt does.
    readonly property var ghostFrames: [
        [
            ".....####.....",
            "...########...",
            "..##########..",
            ".############.",
            "##ooo####ooo##",
            "##**o####**o##",
            "##**o####**o##",
            "##############",
            "##############",
            "##############",
            "##############",
            "##############",
            "###..####..###",
            "##....##....##"
        ],
        [
            ".....####.....",
            "...########...",
            "..##########..",
            ".############.",
            "##ooo####ooo##",
            "##**o####**o##",
            "##**o####**o##",
            "##############",
            "##############",
            "##############",
            "##############",
            "##############",
            "####..##..####",
            "###....##...##"
        ]
    ]

    // ─── the battery ─────────────────────────────────────────────────
    //
    // Generated rather than written out, for the reason Pac-Man is: the only
    // thing that changes between one of these and the next is how many cells of
    // the can are lit, and twelve hand-drawn variants of the same rectangle
    // would be twelve chances to get one wall of it wrong.
    //
    // Seven rows, which is the height of the type. The can and the number
    // beside it are the same grid at the same cell size, so the two sit on one
    // baseline without either being nudged onto it.
    //
    //   "#"  the can
    //   "="  what is left in it
    //   "*"  the bolt, when it is filling
    //
    // Three inks rather than one because the sprite has two things to say at
    // once — how full, and whether that is going up — and a single-coloured
    // one can only say the first.

    readonly property int batteryWidth: 15
    readonly property int batteryHeight: 7

    // Drawn at the size of the inside of the can, so it needs no scaling and no
    // clipping — it is simply laid over the middle of the charge.
    readonly property var batteryBolt: [
        "...##",
        "..##.",
        "#####",
        ".##..",
        "##..."
    ]

    function batteryFrame(level: real, charging: bool): var {
        // The wall at the right-hand end. The terminal stands past it, which is
        // the one thing that makes this rectangle a battery and not a box.
        const wall = 12;

        const left = 1;
        const right = wall - 1;
        const top = 1;
        const bottom = root.batteryHeight - 2;

        const cells = right - left + 1;
        const clamped = Math.max(0, Math.min(1, level));

        // Rounded, then floored at one cell: three per cent of eleven rounds to
        // nothing, and an empty can standing next to the number 3 reads as a
        // sprite that has failed rather than as a battery that is nearly flat.
        const lit = Math.round(clamped * cells);
        const filled = clamped > 0 ? Math.max(1, lit) : 0;

        // Centred in the can rather than carried on top of the charge, so it
        // holds still while what is behind it fills up.
        const boltLeft = left + Math.floor((cells - root.batteryBolt[0].length) / 2);
        const boltWidth = root.batteryBolt[0].length;

        const rows = [];

        for (let y = 0; y < root.batteryHeight; y++) {
            let row = "";

            for (let x = 0; x < root.batteryWidth; x++) {
                if (x >= left && x <= right && y >= top && y <= bottom) {
                    const bx = x - boltLeft;

                    if (charging && bx >= 0 && bx < boltWidth && root.batteryBolt[y - top].charAt(bx) === "#") {
                        row += "*";
                        continue;
                    }

                    row += (x - left) < filled ? "=" : ".";
                    continue;
                }

                // Two long walls, two short ones, and the terminal halfway up
                // the right-hand end.
                const ends = x <= wall && (y === 0 || y === root.batteryHeight - 1);
                const sides = y > 0 && y < root.batteryHeight - 1 && (x === 0 || x === wall);
                const terminal = x > wall && y >= 2 && y <= root.batteryHeight - 3;

                row += (ends || sides || terminal) ? "#" : ".";
            }

            rows.push(row);
        }

        return rows;
    }

    // ─── building it ─────────────────────────────────────────────────

    Component.onCompleted: {
        const split = {};
        for (const character in root.table)
            split[character] = root.table[character].split("/");

        root.glyphs = split;

        root.pacRight = root.chompAngles.map(angle => root.pacFrame(angle));
        root.pacLeft = root.pacRight.map(frame => root.mirror(frame));
        root.pacDeath = root.deathAngles.map(angle => root.pacFrame(angle));
    }
}
