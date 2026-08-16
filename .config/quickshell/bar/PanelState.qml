pragma Singleton

import Quickshell

// Which panel is hanging from the bar, and where it hangs from.
//
// Bar modules push their own on-screen centre in here when clicked, so a panel
// never has to guess where its trigger is — the whole screenshot-calibration
// dance the standalone panels needed is gone.
Singleton {
    id: root

    // "" when nothing is open, otherwise the panel's name.
    property string openPanel: ""

    // Centre of the module the open panel is hanging from, in screen pixels.
    property real anchorX: 960

    // Where the bar itself starts and ends on screen. The bar hugs its modules
    // now, so it no longer spans most of the display — a panel hanging off a
    // module near either end has to be told where the glass above it actually
    // runs out.
    property real barLeft: 0
    property real barRight: 1920

    // The bar's ends are round, so the last half-height of it has no flat
    // underside for a panel to hang from.
    property real barInset: 25

    // Where a panel of this width should sit so its top edge stays under the
    // bar. Centred on its module wherever that is possible, and slid along the
    // bar rather than off it when it is not — the attachment is what is never
    // given up.
    // The anchor is passed in rather than read off this singleton: a panel
    // captures where it was opened from, so a later panel opening somewhere
    // else cannot drag this one sideways mid-retract.
    // Typed so the rounded result lands in the window's integer margin without
    // a conversion warning on every frame of the drip.
    function anchoredLeft(anchorX: real, width: real, screenWidth: real): int {
        const ideal = anchorX - width / 2;

        const flatLeft = root.barLeft + root.barInset;
        const flatRight = root.barRight - root.barInset;

        // A panel wider than the flat run of bar cannot be fully attached from
        // any position, so it centres on the bar and keeps the join central.
        let left = flatRight - flatLeft < width ? (root.barLeft + root.barRight) / 2 - width / 2 : Math.max(flatLeft, Math.min(flatRight - width, ideal));

        // The screen still wins: a panel off the edge of the display is worse
        // than one hanging slightly past the end of the bar.
        const limit = screenWidth - width - Theme.edgeMargin;
        return Math.round(Math.max(Theme.edgeMargin, Math.min(limit, left)));
    }

    // Kept rendered slightly past the close so the retract can play out.
    property string renderedPanel: ""

    signal opened(string name)

    // The module each panel belongs to. Modules register themselves rather
    // than reporting a number, so the position is measured at the moment the
    // panel opens — a cached coordinate goes stale the first time a neighbour
    // on the bar changes width.
    property var anchorSources: ({})

    function setAnchorSource(name, item) {
        if (name.length === 0)
            return;

        const known = root.anchorSources;
        known[name] = item;
        root.anchorSources = known;
    }

    function anchorFor(name) {
        const source = root.anchorSources[name];
        return source ? source.screenCenter() : 960;
    }

    // Open or close by name, hanging the panel off its own module. Used by the
    // IPC handler, which has no click to derive a position from.
    function toggleByName(name) {
        root.toggle(name, root.anchorFor(name));
    }

    function openByName(name) {
        root.open(name, root.anchorFor(name));
    }

    function open(name, x) {
        root.anchorX = x;
        root.renderedPanel = name;
        root.openPanel = name;
        root.opened(name);
    }

    function close() {
        root.openPanel = "";
    }

    function toggle(name, x) {
        // Clicking a different module while one is open should move the drip
        // to that module rather than just closing what is there.
        if (root.openPanel === name)
            root.close();
        else
            root.open(name, x);
    }

    function isOpen(name) {
        return root.openPanel === name;
    }
}
