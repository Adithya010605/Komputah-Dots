pragma ComponentBehavior: Bound

import QtQuick
import "root:/"
import "root:/components"

// A line of text set in the 5×7 bitmap face.
//
// Uppercased on the way in, because the face has no lowercase and an arcade
// board did not either. Everything is drawn from Arcade.glyph, so an unknown
// character is a blank rather than a missing-glyph box.
//
// One delegate per character *position* rather than per character, which is the
// difference between the clock ticking over and the clock being rebuilt. The
// model is a count, so going from 21:47 to 21:48 changes one delegate's
// `character` and leaves the other four holding still — and the one that
// changed is the only one that plays the little flash below.
Row {
    id: label

    property string text: ""
    property int pixel: 3

    // The gap between glyphs, in cells rather than pixels, so tracking survives
    // a change of pixel size — which is the whole reason the clock and the
    // caption under it look like the same face at different sizes.
    property int tracking: 1

    property color color: Theme.text

    // Whether a glyph flashes when it changes. On for anything that ticks — the
    // clock — and off for text that is simply replaced, where every glyph would
    // flash at once and the line would read as blinking rather than as counting.
    property bool animated: false

    readonly property string characters: label.text.toUpperCase()

    spacing: label.pixel * label.tracking

    Repeater {
        model: label.characters.length

        PixelSprite {
            id: glyph

            required property int index

            readonly property string character: label.characters.charAt(glyph.index)

            bitmap: Arcade.glyph(glyph.character)
            pixel: label.pixel
            color: label.color

            // Dimmed and brought back up rather than scaled or slid. A pixel
            // glyph cannot move by half a cell without going soft, and it
            // cannot grow at all without leaving the grid — so the one property
            // left that can carry a change is how brightly it is lit, which is
            // also exactly what a phosphor did.
            onCharacterChanged: {
                if (label.animated)
                    flash.restart();
            }

            NumberAnimation {
                id: flash

                target: glyph
                property: "opacity"
                from: 0.25
                to: 1
                duration: 260
                easing.type: Easing.OutCubic
            }
        }
    }
}
