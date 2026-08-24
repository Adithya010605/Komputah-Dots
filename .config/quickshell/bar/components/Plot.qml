import QtQuick
import "root:/"

// A minute of history, drawn as a level.
//
// The trace is not redrawn as it moves. It is painted one sample wider than the
// window it shows and then slid left by exactly one sample over the gap between
// readings, so the graph crawls continuously instead of stepping forward once a
// second — the numbers tick, the liquid underneath them flows.
Item {
    id: plot

    // Newest last. Values are percentages.
    property var values: []

    // How many samples fit across the visible width. One fewer than the series
    // holds, which is what leaves a sample's worth of trace to slide off.
    property int window: 60

    // How long a sample is on screen before the next one arrives, and so how
    // long the slide has to cover one step.
    property int cadence: 1000

    property color lineColor: Theme.plotLine
    property color fillColor: Theme.plotFill
    property color fadeColor: Theme.plotFillFade

    // Drawn at half height as something for the eye to measure against.
    property bool midline: true

    implicitHeight: Theme.plotHeight

    readonly property real step: width / plot.window

    // 0 straight after a sample lands, 1 by the time the next one is due.
    property real slide: 1

    onValuesChanged: {
        plot.slide = 0;
        crawl.restart();
    }

    NumberAnimation {
        id: crawl

        target: plot
        property: "slide"
        from: 0
        to: 1

        // The only linear easing in the shell, and deliberately so: time passes
        // at a constant rate, and any curve here would read as the machine
        // speeding up and slowing down.
        duration: plot.cadence
        easing.type: Easing.Linear
    }

    // The floor the trace sits on, kept behind the clip so the trace can be
    // slid without dragging the furniture with it.
    Rectangle {
        anchors.fill: parent
        radius: 12
        antialiasing: true
        color: Theme.plotFloor
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: plot.midline
        height: 1
        color: Theme.plotGrid
    }

    Item {
        anchors.fill: parent
        clip: true

        Canvas {
            id: trace

            // One step of overhang, which is the room the slide moves through.
            width: parent.width + plot.step
            height: parent.height
            x: -plot.step * plot.slide

            renderStrategy: Canvas.Cooperative

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();

                const series = plot.values;
                if (!series || series.length < 2)
                    return;

                const step = plot.step;
                const floor = height;

                // Right-aligned: the newest sample owns the right edge, so a
                // series that has not filled up yet grows in from that side
                // rather than stretching to fit.
                function pointX(i) {
                    return width - (series.length - 1 - i) * step;
                }

                function pointY(i) {
                    const value = Math.max(0, Math.min(100, series[i]));

                    // A pixel of headroom, so a pegged reading still shows a
                    // line rather than merging with the top edge.
                    return floor - (value / 100) * (floor - 1) - 0.5;
                }

                // The wash is anchored to the top of the trace rather than to
                // the top of the box: hung from the box, a reading that sits
                // low spends its whole height in the transparent end of the
                // gradient and the level under the line disappears.
                let crest = floor;
                for (let i = 0; i < series.length; i++)
                    crest = Math.min(crest, pointY(i));

                ctx.beginPath();
                ctx.moveTo(pointX(0), pointY(0));

                // Through the midpoint of each pair with the sample itself as
                // the control point: a curve that never overshoots its own
                // data, which a spline through the points would.
                for (let i = 1; i < series.length; i++) {
                    const midX = (pointX(i - 1) + pointX(i)) / 2;
                    const midY = (pointY(i - 1) + pointY(i)) / 2;
                    ctx.quadraticCurveTo(pointX(i - 1), pointY(i - 1), midX, midY);
                }

                ctx.lineTo(pointX(series.length - 1), pointY(series.length - 1));

                // The wash underneath, closed down to the baseline.
                ctx.save();
                ctx.lineTo(pointX(series.length - 1), floor);
                ctx.lineTo(pointX(0), floor);
                ctx.closePath();

                const wash = ctx.createLinearGradient(0, Math.min(crest, floor - 2), 0, floor);
                wash.addColorStop(0, plot.fillColor);
                wash.addColorStop(1, plot.fadeColor);
                ctx.fillStyle = wash;
                ctx.fill();
                ctx.restore();

                ctx.strokeStyle = plot.lineColor;
                ctx.lineWidth = 1.5;
                ctx.lineJoin = "round";
                ctx.lineCap = "round";
                ctx.stroke();
            }

            // Repainting is tied to the data, not to the motion: the slide is a
            // translation of an already-painted canvas, so a minute of crawl
            // costs nothing.
            Connections {
                target: plot

                function onValuesChanged() {
                    trace.requestPaint();
                }

                function onWidthChanged() {
                    trace.requestPaint();
                }

                function onLineColorChanged() {
                    trace.requestPaint();
                }

                function onFillColorChanged() {
                    trace.requestPaint();
                }
            }
        }
    }
}
