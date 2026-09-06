import QtQuick
import "root:/"

// The material every surface in the shell is made of, painted over the flat
// Theme.glass fill of whatever contains it.
//
// Two things at once, in one pass. Underneath, the faint wash of the wallpaper
// accent that keeps a surface sitting in the same light as the desktop instead
// of reading as neutral grey. Over the top of that, along the upper edge only, a
// highlight — glass is lit from above, and the edge that faces the light is the
// one cue that says this is a pane with thickness rather than a translucent
// rectangle.
//
// Both live in a single gradient rather than in two stacked rectangles. Stacking
// them would mean two rounded shapes to keep in step with the parent's radius,
// and the highlight would have to be clipped or given its own corner treatment
// at the top. One gradient on one shape has neither problem, and the highlight
// simply is the top of the wash.
Rectangle {
    id: sheen

    // How far down the highlight reaches, in pixels rather than as a fraction
    // of the surface. A fraction would give a tall panel an enormous wash and
    // the bar a hairline, when what makes them look like the same glass is that
    // the lit edge is the same depth on both.
    property real depth: Theme.glassSheenDepth

    // How much of the wallpaper is in the glass. The default is the barely-there
    // wash every surface carries; a surface with a lot of blurred desktop behind
    // it can ask for more, and the launcher does — it is the one card in the
    // shell big enough that whatever happens to be underneath would otherwise
    // decide its colour.
    property color tint: Theme.glassTint

    anchors.fill: parent
    radius: parent.radius
    antialiasing: true

    // Held just short of 1 so the two stops below it can never collide with the
    // one at the bottom, which happens on any surface shallower than the depth —
    // the bar being the obvious one.
    readonly property real reach: sheen.height > 0 ? Math.min(0.98, sheen.depth / sheen.height) : 0.98

    gradient: Gradient {
        GradientStop {
            position: 0
            color: Theme.glassLit
        }
        GradientStop {
            position: sheen.reach
            color: sheen.tint
        }
        GradientStop {
            position: 1
            color: sheen.tint
        }
    }
}
