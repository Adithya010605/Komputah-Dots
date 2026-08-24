pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The single source of truth for every surface in the shell — bar and panels
// alike. Values here mirror ~/.config/waybar/style.css so the two bars read as
// the same object, with the palette itself coming from wal.
Singleton {
    id: root

    // ─── wallpaper palette ───────────────────────────────────────────

    property var wal: ({
            "special": {
                "background": "#0d0d0d",
                "foreground": "#a1bac4"
            },
            "colors": {
                "color4": "#638574",
                "color6": "#497497",
                "color12": "#8fb3a1"
            }
        })

    function pick(key, fallback) {
        return (wal && wal.colors && wal.colors[key]) ? wal.colors[key] : fallback;
    }

    function withAlpha(hex, opacity) {
        const c = Qt.color(hex);
        return Qt.rgba(c.r, c.g, c.b, opacity);
    }

    readonly property color accentBase: pick("color12", "#8fb3a1")

    FileView {
        path: "/home/adi/.cache/wal/colors.json"
        preload: true
        blockLoading: true
        watchChanges: true

        onFileChanged: reload()
        onTextChanged: {
            const raw = text().trim();
            if (raw.length === 0)
                return;

            try {
                root.wal = JSON.parse(raw);
            } catch (error) {
                console.warn("theme: could not parse wal colors");
            }
        }
    }

    // ─── glass ───────────────────────────────────────────────────────

    readonly property color glass: Qt.rgba(20 / 255, 20 / 255, 28 / 255, 0.34)
    readonly property color glassBorder: Qt.rgba(1, 1, 1, 0.12)

    // A whisper of the wallpaper in the glass itself, so surfaces sit in the
    // same light as the desktop instead of reading as neutral grey. Kept far
    // below the point where it tints text.
    readonly property color glassTint: withAlpha(accentBase, 0.05)

    readonly property color pill: Qt.rgba(1, 1, 1, 0.14)
    readonly property color pillBorder: Qt.rgba(1, 1, 1, 0.22)
    readonly property color pillHover: Qt.rgba(1, 1, 1, 0.20)
    readonly property color pillHoverBorder: Qt.rgba(1, 1, 1, 0.30)

    // Modules and buttons answer a press with colour rather than with scale:
    // scaling a pill resamples the text inside it, and at bar sizes that reads
    // as a blurry, choppy wobble.
    readonly property color pillPress: Qt.rgba(1, 1, 1, 0.28)

    readonly property color divider: Qt.rgba(1, 1, 1, 0.10)

    readonly property color text: "white"
    readonly property color muted: Qt.rgba(1, 1, 1, 0.55)

    readonly property color accent: withAlpha(accentBase, 0.85)
    readonly property color accentSoft: withAlpha(accentBase, 0.30)

    // ─── workspace dots ──────────────────────────────────────────────
    //
    // Drawn as plain rounded rectangles rather than as a font glyph, so the
    // strip stays crisp at any size and can stretch instead of scale. The
    // focused dot is the wallpaper accent at full strength — the same accent
    // every other active state in the shell uses.

    readonly property color workspaceActive: accent
    readonly property color workspaceOccupied: withAlpha(accentBase, 0.42)
    readonly property color workspaceEmpty: Qt.rgba(1, 1, 1, 0.20)
    readonly property color workspaceHover: Qt.rgba(1, 1, 1, 0.42)

    readonly property int workspaceDot: 7
    readonly property int workspaceDotActive: 20
    // On top of the few pixels of slack each dot carries for its click target.
    readonly property int workspaceDotSpacing: 4

    // A module whose panel is currently hanging open reads as pressed-in,
    // which is the only cue that ties the drip back to its trigger.
    readonly property color pillActive: withAlpha(accentBase, 0.22)
    readonly property color pillActiveBorder: withAlpha(accentBase, 0.45)

    // ─── bar geometry ────────────────────────────────────────────────

    readonly property int barMarginTop: 9
    // A ceiling rather than a size: the bar hugs its modules and only stops
    // growing here. It used to be pinned at this width, which left a long
    // stretch of empty glass past the window name and past the gear.
    readonly property int barWidth: 1450
    readonly property int barPadding: 9
    // Slack at the two rounded ends, where a pill would otherwise sit right on
    // the curve.
    readonly property int barPadEnds: 12
    // Sized so the bar comes out 50px tall overall, which is exactly what
    // waybar measures — the two can be swapped without the desktop reflowing.
    readonly property int moduleHeight: 32
    readonly property int moduleSpacing: 10
    readonly property int modulePadH: 12

    readonly property int barHeight: moduleHeight + barPadding * 2
    readonly property int barExclusive: barMarginTop + barHeight

    // Waybar pins these two to a character count; a fixed pixel width is the
    // same idea and stops the centre of the bar shifting on every title change.
    // Both are cut back from what they were: now that the bar hugs its
    // contents, slack in a module is slack on the bar.
    readonly property int windowModuleWidth: 116
    readonly property int mprisModuleWidth: 186

    // ─── panel geometry ──────────────────────────────────────────────

    readonly property int cardRadius: 26
    readonly property int padding: 16
    readonly property int edgeMargin: 8

    // Slack below the card so the springy overshoot at the end of the drip is
    // not clipped by the layer surface.
    readonly property int overshootRoom: 18

    // ─── the drip ────────────────────────────────────────────────────
    //
    // Every panel in the shell falls and retracts on these numbers, so the
    // motion is identical everywhere and tunable from one place.

    readonly property int dripOpenDuration: 400
    readonly property int dripCloseDuration: 190
    readonly property real dripOvershoot: 0.55

    readonly property int neckOpenDuration: 440
    readonly property int neckCloseDuration: 170
    readonly property real neckOvershoot: 0.9
    readonly property real neckPinch: 0.84

    readonly property int fadeInDuration: 200
    readonly property int fadeOutDuration: 120

    // How long the surface lingers after a close, so the retract finishes
    // before the window is torn down.
    readonly property int unrenderDelay: 280

    // ─── notifications ───────────────────────────────────────────────

    // Toasts hang under the bell the same way every panel hangs under its
    // module; these only govern how long one stays up when the sender did not
    // say. Critical never expires on its own, as mako did not expire it either.
    readonly property int toastTimeout: 6000
    readonly property int toastWidth: 300
    readonly property int toastMaxVisible: 3

    readonly property color urgent: "#e06c75"
    readonly property color urgentSoft: withAlpha("#e06c75", 0.22)

    // ─── plots ───────────────────────────────────────────────────────
    //
    // A trace is the accent at full strength over a wash of the same colour
    // that falls away to nothing at the baseline, so the graph reads as a level
    // in the glass rather than as a chart drawn on top of it.

    readonly property int plotHeight: 44
    readonly property color plotLine: accent
    readonly property color plotFill: withAlpha(accentBase, 0.42)
    readonly property color plotFillFade: withAlpha(accentBase, 0.0)
    readonly property color plotGrid: Qt.rgba(1, 1, 1, 0.07)
    readonly property color plotFloor: Qt.rgba(1, 1, 1, 0.05)

    // ─── heat ────────────────────────────────────────────────────────
    //
    // Temperature and power get their own ramp rather than the accent, because
    // a hot part should read as hot on every wallpaper.

    readonly property color warn: "#e5c07b"

    // Cool sits on the wallpaper accent and only leaves it as things heat up,
    // so an idle machine still looks like the rest of the shell.
    function heat(fraction: real): color {
        const t = Math.max(0, Math.min(1, fraction));

        if (t < 0.5)
            return Qt.tint(root.accent, root.withAlpha(root.warn, t * 2));

        return Qt.tint(root.warn, root.withAlpha(root.urgent, (t - 0.5) * 2));
    }

    // Where a reading sits between comfortable and worth looking at.
    function heatOf(value: real, cool: real, hot: real): color {
        return root.heat((value - cool) / (hot - cool));
    }

    // ─── motion ──────────────────────────────────────────────────────

    readonly property int hoverDuration: 140
    readonly property int pressDuration: 110

    // ─── type ────────────────────────────────────────────────────────

    // The bar keeps waybar's mono face; panels use a proportional face for
    // prose with the Nerd Font reserved for glyphs.
    readonly property string barFamily: "GeistMono Nerd Font"
    readonly property string fontFamily: "Adwaita Sans"
    readonly property string monoFamily: "GeistMono Nerd Font"
    readonly property string iconFamily: "GeistMono Nerd Font"

    readonly property int barFontSize: 15
}
