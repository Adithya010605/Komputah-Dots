import QtQuick
import "root:/"

// Bar typography: waybar's mono face at its exact size and weight, so both
// bars can run side by side without the swap being obvious.
Text {
    font.family: Theme.barFamily
    font.pixelSize: Theme.barFontSize
    font.weight: Font.Medium
    color: Theme.text
    renderType: Text.NativeRendering
}
