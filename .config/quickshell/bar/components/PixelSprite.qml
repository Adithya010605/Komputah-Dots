pragma ComponentBehavior: Bound

import QtQuick
import "root:/"

// One sprite, drawn as a grid of lit cells.
//
// The bitmap is an array of equal-length strings — see Arcade.qml, which is
// where all of them come from. "." is an unlit cell and every other character
// is lit, in the sprite's own colour unless the palette names one for it.
//
// The cells are made once and then only ever switched on and off. That is the
// whole reason this is a fixed grid rather than a list of the lit cells: a
// sprite that changes every hundred milliseconds — which is what Pac-Man's jaw
// is — would otherwise be tearing down and rebuilding a hundred and sixty-nine
// items six times a second, and the frame it spends doing that is a frame it is
// not chomping in. Toggling `visible` on items that already exist costs
// nothing, and every sprite here keeps its dimensions across all of its frames.
//
// Nothing is antialiased, on purpose. A lit cell is a square of exactly one
// colour with a hard edge, and softening those edges is how pixel art stops
// looking like pixel art and starts looking like a low-resolution photograph.
Item {
    id: sprite

    // Rows of the bitmap, top to bottom.
    property var bitmap: []

    // The side of one cell, in real pixels. This is the only size control the
    // sprite has — there is no scaling anywhere in here, because scaling a grid
    // of squares by anything other than a whole number is what puts a seam down
    // the middle of it.
    property int pixel: 3

    property color color: Theme.text

    // Characters that are not drawn in the sprite's own colour, as
    // { "o": "white" }. Anything not named falls back to `color`.
    property var palette: ({})

    readonly property int rows: sprite.bitmap.length
    readonly property int columns: sprite.rows > 0 ? sprite.bitmap[0].length : 0

    implicitWidth: sprite.columns * sprite.pixel
    implicitHeight: sprite.rows * sprite.pixel

    Repeater {
        model: sprite.rows * sprite.columns

        Rectangle {
            id: cell

            required property int index

            readonly property int row: Math.floor(cell.index / sprite.columns)
            readonly property int column: cell.index % sprite.columns

            // Guarded on both axes: a bitmap can be swapped for one of a
            // different size mid-flight, and for the frame between the model
            // resizing and the rows arriving these would be reading off the end
            // of the array.
            readonly property string ink: {
                const line = sprite.bitmap[cell.row];
                if (line === undefined || cell.column >= line.length)
                    return ".";

                return line.charAt(cell.column);
            }

            x: cell.column * sprite.pixel
            y: cell.row * sprite.pixel
            width: sprite.pixel
            height: sprite.pixel

            visible: cell.ink !== "."
            color: sprite.palette[cell.ink] !== undefined ? sprite.palette[cell.ink] : sprite.color
            antialiasing: false
        }
    }
}
