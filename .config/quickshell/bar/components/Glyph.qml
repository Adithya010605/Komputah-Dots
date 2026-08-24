import QtQuick
import "root:/"

Text {
    font.family: Theme.iconFamily
    color: Theme.text

    // Deliberately NOT NativeRendering, unlike the text components. The native
    // rasteriser hints every stem onto the pixel grid, which is what you want
    // for letterforms and ruinous for icons: at the 9-14px the panels draw
    // these at, the thin gaps inside a wifi fan or a pair of headphones snap
    // shut and the glyph collapses into a smear of bars. Distance-field
    // rendering leaves the outline alone and the icons stay themselves.
    renderType: Text.QtRendering
}
