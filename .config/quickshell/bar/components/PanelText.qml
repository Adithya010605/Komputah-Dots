import QtQuick
import "root:/"

// Panel typography: a proportional face for anything you actually read, with
// the Nerd Font kept for glyphs only.
Text {
    font.family: Theme.fontFamily
    font.weight: Font.Medium
    color: Theme.text
    renderType: Text.NativeRendering
}
