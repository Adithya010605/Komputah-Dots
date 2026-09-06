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

    // ─── the lock screen ─────────────────────────────────────────────
    //
    // The one surface in the shell that is not sitting on the desktop, and the
    // only place these numbers are used. Nothing above the compositor is behind
    // a lock screen, so the frost cannot be borrowed from Hyprland the way every
    // panel borrows it — the wallpaper is drawn here and blurred here, and these
    // are the numbers that make what comes out look like the same glass as the
    // rest of the shell rather than like a photograph with a box on it.

    // Deep. Past the point where the wallpaper is a picture of anything and well
    // into where it is a field of colour the glass has something to be glass
    // against — which is the job here. A half-blurred desktop behind a lock
    // screen is the worst of both: still legible enough to read, not clean
    // enough to ignore, and it pulls the eye off the one thing on screen that
    // wants typing into.
    //
    // Getting there is not a matter of turning the radius up. MultiEffect
    // measures its blur in the pixels of the texture it is handed, and it stops
    // rendering entirely somewhere above blurMax 128 — a black screen, not a
    // blurrier one — so on a 1920-wide texture the largest radius Qt will
    // accept is still only a softening, and a mountain comes out the far side
    // as a mountain. Hyprland gets its own result by blurring four times over
    // progressively smaller buffers, and this is the same trick in one step:
    // the picture is drawn into a texture this many pixels wide, blurred there,
    // where the radius below is a large fraction of the whole frame rather than
    // three per cent of it, and scaled back up to the display.
    //
    // 256 against 64 is what matches the compositor's own blur on the same
    // wallpaper. Smaller flattens the last of the colour out of it; larger and
    // the picture starts coming back.
    readonly property int lockBlurBase: 256

    readonly property real lockBlur: 1.0
    readonly property int lockBlurMax: 64

    // Blown up a little past the edges of the screen before being clipped back
    // to them. A blur has nothing outside the texture to sample, so it fades
    // towards transparent at all four borders; without this the lock screen
    // wears a dark frame. The overscan puts that fade off the display.
    readonly property real lockBlurOverscan: 1.12

    // Taken down and cooled, on the same reasoning hyprlock's own background
    // block was: white pixel text over an undimmed photograph is unreadable on
    // roughly half of the wallpapers in the folder.
    //
    // Both eased off from where they started, because the blur above them was
    // deepened and the two jobs overlap: detail the blur has already destroyed
    // does not also need to be darkened, and past a point the pair of them turn
    // every wallpaper into the same black rectangle. What is left is enough to
    // hold white text on the bright ones.
    readonly property real lockDim: -0.18
    readonly property real lockDesaturate: -0.12
    readonly property color lockScrim: Qt.rgba(0, 0, 0, 0.22)

    // How the screen arrives and leaves. Slower in than anything else here: it
    // is the one surface that appears when you are not looking at the machine,
    // and there is nothing behind it that you are waiting to get back to.
    readonly property int lockFadeIn: 420
    readonly property int lockFadeOut: 260
    readonly property int lockRise: 520
    readonly property int lockRiseDistance: 22

    // ─── the arcade ──────────────────────────────────────────────────

    // The side of one cell in the 5×7 face and in the sprites. Everything 8-bit
    // on the screen is a whole multiple of one of these, and nothing is ever
    // scaled — a grid of squares resampled by 1.4 is a grid of smudges.
    readonly property int lockClockPixel: 12
    readonly property int lockDatePixel: 2
    readonly property int lockCaptionPixel: 2
    readonly property int lockPacPixel: 2
    readonly property int lockLivesPixel: 2

    // How many pellets are on the board, and how far apart they sit.
    //
    // Six, which is short. A long lane means a password of ordinary length
    // leaves him stranded in the middle of it with the whole right-hand side
    // untouched — the bar reads as half-finished rather than as crossed, and it
    // is the length of the lane saying that, not the password. Six is inside
    // what almost anything reaches, so he arrives; anything longer goes round
    // through the tunnel and arrives again.
    //
    // He starts *before* the first pellet, so there are seven positions to six
    // pellets and the sixth character puts him on the last one. Without that
    // spare slot at the start, a password of exactly six would wrap and leave
    // the board looking untouched at the moment it was finished.
    readonly property int lockCapacity: 6
    readonly property int lockLaneStep: 16

    readonly property int lockPellet: lockPacPixel * 2
    readonly property int lockPowerPellet: lockPacPixel * 4

    // The bar's own glass, lighter than the shell's.
    //
    // Theme.glass is a dark tint that reads as frosted because Hyprland blurs
    // something bright behind it — the desktop, a page, a terminal. Here what is
    // behind it is a wallpaper this file has just blurred and dimmed, and a dark
    // tint on a dark field is a hole rather than a pane. Lit from the front
    // instead, it is the same material seen in different light.
    readonly property color lockGlass: Qt.rgba(1, 1, 1, 0.10)
    readonly property color lockGlassBorder: Qt.rgba(1, 1, 1, 0.22)

    readonly property int lockLanePadH: 14
    readonly property int lockLanePadV: 9

    // The lane is a sprite's width plus one step per pellet: he has to fit at
    // both ends of it, and half of him hangs off either side of the position he
    // is standing on.
    readonly property int lockLaneWidth: 13 * lockPacPixel + lockCapacity * lockLaneStep

    // Which comes out at roughly 150×44: a small capsule, deliberately, and
    // sized against the password field on a macOS lock screen rather than
    // against the space available. A lock screen has one input on it and the
    // whole display to put it on, and the temptation is to make the one thing
    // that matters big — but a wide bar low on an empty screen reads as a piece
    // of furniture, and what is wanted is a thing you type into and then stop
    // looking at. The clock is the object on this screen. This is the slot.
    //
    // Taken down from 180×48 by closing the pellet spacing and the padding
    // rather than by scaling the sprite: the lane is what makes the capsule
    // wide, and 16 is as tight as the step goes before an uneaten pellet ends
    // up underneath him. Everything inside stays drawn at the same pixel size,
    // so it reads as the same object with less air in it.
    readonly property int lockCardWidth: lockLaneWidth + lockLanePadH * 2
    readonly property int lockCardHeight: 13 * lockPacPixel + lockLanePadV * 2

    // Where it sits, which is at the bottom rather than under the clock. A lock
    // screen is a clock you look at and a box you type into, and stacking the
    // two in the middle makes one object out of two jobs. Apart, the clock owns
    // the screen and the bar owns the edge you are already looking at when you
    // sit down — which is also where hyprlock's input field was.
    //
    // Low, and lower than it was. The whole block — capsule, caption, lives —
    // is anchored by its bottom edge, so this is the only number that decides
    // how far down the screen it all sits, and near the edge is where the eye
    // that has just found the clock goes looking for it.
    readonly property int lockBottomMargin: 40

    // The clock, lifted off centre by about the height of what is now at the
    // bottom, so the two read as balanced rather than as one thing centred and
    // another thing left over. Eased back as the block below it shrank: the
    // lift is meant to be about half of what is down there, and half of a
    // smaller thing is a smaller lift.
    readonly property int lockClockOffset: -54

    // Him. The accent, like every other active thing in the shell, rather than
    // arcade yellow — a fixed yellow would be the one element on screen that did
    // not come from the wallpaper, and it would read as a sticker rather than as
    // part of the surface it is on. Arcade yellow is one line, if it is ever
    // wanted: "#ffd400".
    readonly property color pacSelf: accent

    // Neutral, so the only coloured thing moving along the row is him. The big
    // ones are brighter and larger rather than a second colour, which is the
    // distinction the board itself made.
    readonly property color pacPellet: Qt.rgba(1, 1, 1, 0.55)
    readonly property color pacPower: Qt.rgba(1, 1, 1, 0.90)

    // It. The shell's urgent red — the same colour every other failure in the
    // shell is reported in, which is what stops the ghost being a joke that has
    // to be learnt separately from the thing it means.
    readonly property color ghostBody: urgent
    readonly property color ghostEye: Qt.rgba(1, 1, 1, 0.95)
    readonly property color ghostPupil: Qt.rgba(0.08, 0.09, 0.16, 1)

    // ─── the battery in the corner ───────────────────────────────────
    //
    // Drawn at the cell size of the lives below the capsule, which is also the
    // cell size of the number beside it: the can is seven rows tall and so is
    // the type, so the two line up by being the same grid rather than by being
    // aligned to each other.

    // The can itself, quiet — it is a frame around the reading and not the
    // reading. What is in it is lit brighter so the level can be taken at a
    // glance without counting cells against an outline of the same weight.
    readonly property color lockBatteryShell: muted
    readonly property color lockBatteryFill: Qt.rgba(1, 1, 1, 0.78)

    // Below this, what is left in the can turns. The number beside it stays
    // muted: two things going red at once is an alarm, and this is a lock
    // screen telling you to find a cable, not a warning light.
    readonly property int lockBatteryLow: 15
    readonly property color lockBatteryLowFill: urgent

    // The bolt, in the accent every other active thing in the shell is in.
    readonly property color lockBatteryBolt: accent

    // ─── the arcade's motion ─────────────────────────────────────────
    //
    // Frame counts and beats rather than easing curves, because most of what
    // moves here is a sprite and a sprite does not ease. The two numbers that
    // are eased — the step along the lane and the dash off the end of it — are
    // the two places something is travelling rather than animating in place.

    // One frame of the jaw. Six frames to the chomp, so this is a chomp about
    // every six hundred milliseconds, which is the rate the board ran it at.
    readonly property int lockChompInterval: 100

    // One pellet's worth of travel. Short, because it runs on every keystroke
    // and has to be finished before the next one lands at typing speed.
    readonly property int lockStepDuration: 120
    readonly property int lockPelletFade: 160
    readonly property int lockPowerPulse: 700

    // Being caught, in order: the rush in, the death, and how long the ghost
    // takes to go out as the death starts — it does not walk off, it stops being
    // there, which is what the board did with them for the death too.
    readonly property int lockGhostRush: 460

    // The beat it stands beside him before he goes. Short, and the whole reason
    // the ghost is worth drawing: without it the rush and the death run into
    // each other and the thing that caught him is off screen before it has been
    // seen catching him.
    readonly property int lockGhostHold: 220

    readonly property int lockDeathDuration: 700
    readonly property int lockGhostLeave: 320

    // Getting out. Quicker than being caught, and the last thing that happens
    // before the session is handed back.
    readonly property int lockWinDash: 460
    readonly property int lockReleaseDelay: 260

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
