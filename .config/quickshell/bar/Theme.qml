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
                "color2": "#996675",
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

    // The lit top edge every surface carries — see components/GlassSheen.qml.
    // Neutral white rather than the accent, because a highlight is the light
    // falling on the glass and not the colour of the glass itself; tinting it
    // would turn the sheen into a second wash and lose the distinction.
    readonly property color glassLit: Qt.rgba(1, 1, 1, 0.085)

    // Deep enough to read as a lit edge on a full-height panel, shallow enough
    // that a 50px bar is not simply pale all over.
    readonly property int glassSheenDepth: 64

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
    //
    // The wheel's alone. The launcher deliberately has no scrim at all — it
    // leaves the desktop behind it sharp and undimmed, and an empty sheet is
    // what lets its layer rule tell card from backdrop by alpha.
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

    // ─── the summoned menus' accent ──────────────────────────────────
    //
    // The two surfaces in the shell that do not take the accent everything else
    // takes: the launcher and the power wheel. This is rofi's
    // `selected-normal-background` — the colour its power menu highlighted with
    // — which pywal writes as color2, where the rest of the shell is on color12.
    //
    // Deliberately a second colour rather than a second name for the first.
    // These two have no bar to belong to, no module to hang from, and cover the
    // screen when they are up; they are also the two things here that used to be
    // rofi menus. Giving them rofi's own highlight is what makes them a pair,
    // and what keeps them distinct from the bar they never touch.
    //
    // Not readonly for the same reason accentBase is not: a Behavior cannot
    // attach to a readonly property. It is still a binding and nothing assigns
    // to it.
    property color menuAccentBase: pick("color2", "#996675")

    Behavior on menuAccentBase {
        ColorAnimation {
            duration: 520
            easing.type: Easing.InOutCubic
        }
    }

    readonly property color menuAccent: withAlpha(menuAccentBase, 0.85)
    readonly property color menuAccentSoft: withAlpha(menuAccentBase, 0.30)

    // The card is the largest surface in the shell and it sits on a sharp,
    // undimmed desktop, so far more of what is behind it survives the blur than
    // on any panel. Left on the shell's usual whisper of a wash it would take
    // its colour from whatever happened to be underneath — a red diff, a photo,
    // a bright page — and read as a different object every time it opened. This
    // is heavy enough to hold its colour through all of that, and it is why the
    // launcher looks like the pomo panel rather than like a hole cut in the
    // screen.
    readonly property color launcherWash: withAlpha(menuAccentBase, 0.12)

    // Carried through the card's own furniture, the way the pomo panel carries
    // its accent through the dial and the controls: the search mark that opens
    // the box, the rule under it, and the caption naming what Enter does.
    readonly property color launcherRule: withAlpha(menuAccentBase, 0.24)

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
    readonly property int launcherRise: 320
    readonly property int launcherUnrenderDelay: 200

    // How far the card starts below where it settles, and how far down it is
    // scaled. Both small: this is a card arriving, not a card flying in.
    readonly property int launcherRiseDistance: 14
    readonly property real launcherRestScale: 0.985

    // The card comes to rest the way the drip does, carrying a little past
    // where it stops and easing back — the difference between a surface with
    // some weight to it and one that is simply drawn at its final position on
    // a later frame. Far gentler than the drip's, because the card travels
    // fourteen pixels rather than the height of a panel.
    readonly property real launcherOvershoot: 1.1

    // Growing and shrinking as results come and go. Deliberately quicker than
    // everything else about the card: this one runs on *every keystroke*, and
    // an edge still easing towards its last size when the next letter lands
    // never arrives anywhere. Short enough to keep up with typing, long enough
    // not to snap.
    readonly property int launcherResize: 200

    // ─── the result rows ─────────────────────────────────────────────

    readonly property int launcherRowSpacing: 2
    readonly property int launcherRowInset: 8
    readonly property int launcherRowRadius: 14

    // Rows arrive in a run rather than all together — each one a beat behind
    // the one above it, so the list reads as filling downward out of the box
    // you are typing into rather than as a block appearing under it.
    readonly property int launcherRowRise: 260
    readonly property int launcherRowDrop: 10
    readonly property int launcherStagger: 26

    // Where the stagger stops. Past this many rows the delay is what you would
    // notice rather than the cascade, and the bottom of the list would still be
    // arriving after the top of it was already being read.
    readonly property int launcherStaggerCap: 5

    // The selected row. One shape that slides between rows rather than a fill
    // that lights up and goes out on each of them: the selection is a single
    // thing being moved, and cross-fading two rectangles says the opposite.
    // Filled rather than outlined, because it moves on every keystroke and an
    // outline redrawing that often flickers.
    //
    // This is the one that matters most: it is doing literally the job rofi's
    // selected-normal-background does in the power menu, on the same colour.
    readonly property color launcherSelection: withAlpha(menuAccentBase, 0.20)
    readonly property color launcherSelectionEdge: withAlpha(menuAccentBase, 0.34)

    // One row's worth of travel. Slow enough to be followed by eye — the whole
    // point of sliding it is that you can see where it went — and quick enough
    // that holding an arrow key down does not fall behind.
    readonly property int launcherGlide: 200

    // ─── the power wheel ─────────────────────────────────────────────
    //
    // Built like the wallpaper wheel and deliberately much smaller than it. That
    // one is a gallery: the whole point is judging a photograph, so the cards
    // have to be big enough to judge and the disk has to be big enough to carry
    // them. This one holds five glyphs. A glyph is legible at a fraction of the
    // size, so the disk comes in to match and the wheel sits in the right-hand
    // corner of the screen rather than spanning its height.

    // A disc, not a card — five identical circles on a rim, which is the whole
    // reason this can be so much smaller than the picker.
    readonly property int powerItemSize: 62

    // How far the discs orbit from the centre — not how big the disk is, which
    // is worked out from this in PowerMenu.qml so the disk always contains them.
    //
    // Roughly half the picker's radius. Small enough to keep the whole arc
    // inside the right-hand corner and to hold the discs well within the rim
    // they are mounted on, large enough that five of them at the step below do
    // not touch.
    readonly property int powerRadius: 168
    readonly property int powerCentreInset: 40

    // Clearance between the widest point of the selected disc and the edge of
    // the disk carrying it. Discs sit *on* a rim, so there has to be visible rim
    // outside them at the one moment a disc is at its largest; without this the
    // selected one grows out through the edge and stops reading as mounted on
    // anything.
    readonly property int powerDiskMargin: 16

    // Five actions and five visible positions, which is the pairing that makes
    // the wheel endless without ever showing you the same action twice: any run
    // of five consecutive slots covers all five actions exactly once. Reaching
    // one further would put a second Shutdown on screen below the first.
    readonly property real powerStep: 24
    readonly property int powerReach: 2

    // Out on the rim and at the selection point. A wider spread than the
    // picker's, because a disc has no detail to lose when it shrinks and the
    // size is doing all the work of saying which one is chosen.
    readonly property real powerRimScale: 0.82
    readonly property real powerFrontScale: 1.3

    // The chosen action, and the ring around it. Shutdown and Reboot take the
    // urgent colour instead — see PowerMenu.qml.
    readonly property color powerSelection: withAlpha(menuAccentBase, 0.30)
    readonly property color powerSelectionEdge: withAlpha(menuAccentBase, 0.65)

    readonly property color powerRest: Qt.rgba(1, 1, 1, 0.08)
    readonly property color powerRestEdge: Qt.rgba(1, 1, 1, 0.16)

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
