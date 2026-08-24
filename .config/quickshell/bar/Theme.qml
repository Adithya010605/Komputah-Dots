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

    // Every accent in the shell is derived from this one colour, so easing it
    // eases all of them at once. Without this the whole shell — bar, borders,
    // active states, the tint in the glass — snaps to the new palette the
    // instant pywal rewrites colors.json, which is the jolt you see at the end
    // of a wallpaper change rather than anything the picker itself is doing.
    // Not readonly, only because a Behavior cannot attach to a readonly
    // property. It is still a binding and nothing assigns to it.
    property color accentBase: pick("color12", "#8fb3a1")

    Behavior on accentBase {
        ColorAnimation {
            duration: 520
            easing.type: Easing.InOutCubic
        }
    }

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

    // ─── the wallpaper wheel ─────────────────────────────────────────
    //
    // The picker is summoned rather than dripped, so it gets its own timings:
    // a surface that takes over the screen has to arrive more gently than one
    // hanging off the module you just clicked.

    // Sits over a fully blurred desktop (see the layer rule in hyprland.lua),
    // so this only has to take the brightness down far enough for white text
    // and the cards to sit clear of it.
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.38)

    readonly property int menuFadeIn: 220
    readonly property int menuFadeOut: 150
    readonly property int menuRiseDuration: 420
    readonly property int menuUnrenderDelay: 240

    // The disk the wallpapers are mounted on, drawn as the faintest possible
    // glass so the wheel reads as one object rather than as loose cards.
    readonly property color diskFill: Qt.rgba(1, 1, 1, 0.04)
    readonly property color diskEdge: Qt.rgba(1, 1, 1, 0.09)

    // One notch of the wheel. Long enough to read as mass turning rather than
    // as a jump, short enough to hold an arrow key down through.
    readonly property int wheelTurnDuration: 420

    // Choosing one. The new wallpaper floods in behind the glass as a circle
    // spreading from the card you chose. It has most of the width of the
    // display to cross, and it is the whole of the feedback that the choice
    // landed, so it is slower than anything else in the shell and eased at
    // both ends — heavy to start moving, and slowing into the far corners
    // rather than stopping dead in them.
    readonly property int revealDuration: 1000

    // How soft the wave front is, as a fraction of how far it has travelled.
    // Proportional rather than fixed: a spreading front thins as it goes, and
    // a hard edge on a blurred image is a cut rather than a flood.
    readonly property real revealFeather: 0.16

    // The beat between the circle closing over the last corner and the picker
    // handing the wallpaper back to the compositor, on top of however long the
    // swap behind it still needs.
    readonly property int revealSettle: 260

    // Closed again when the swap fails. Quicker than the open: an undo should
    // not take as long as the thing it is undoing.
    readonly property int revealAbortDuration: 320

    // ─── the launcher ────────────────────────────────────────────────
    //
    // Summoned like the wallpaper picker and sharing its scrim and fades, but
    // it is a card rather than a stage: one object, centred, that you type
    // into. The numbers here are about the card.

    // Wide enough for an application name and what it is side by side, and no
    // wider — a search box that runs the width of the display makes you look
    // across the screen to read a result you are already looking at.
    readonly property int launcherWidth: 620

    // Down from the top, not centred vertically. The box lands under where the
    // eye already is and the results grow downward into empty screen, so
    // nothing moves upward as you type.
    readonly property real launcherTopFraction: 0.22

    readonly property int launcherRadius: 22
    readonly property int launcherFieldHeight: 62
    readonly property int launcherRowHeight: 50

    // The answer row is the one thing in the card that is read rather than
    // scanned, so it gets the height to be set at a size you can read at a
    // glance.
    readonly property int launcherAnswerHeight: 78

    // A hair faster than the wallpaper picker's arrival. That one is a place
    // you go and look around; this one is in the way of what you were doing.
    readonly property int launcherFadeIn: 160
    readonly property int launcherFadeOut: 110
    readonly property int launcherRise: 260
    readonly property int launcherUnrenderDelay: 200

    // How far the card starts below where it settles, and how far down it is
    // scaled. Both small: this is a card arriving, not a card flying in.
    readonly property int launcherRiseDistance: 14
    readonly property real launcherRestScale: 0.985

    // The selected row. Filled rather than outlined, because the selection
    // moves on every keystroke and an outline redrawing that often flickers.
    readonly property color launcherSelection: withAlpha(accentBase, 0.20)
    readonly property color launcherSelectionEdge: withAlpha(accentBase, 0.34)

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
