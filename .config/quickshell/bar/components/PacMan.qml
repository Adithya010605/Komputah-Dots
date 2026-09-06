pragma ComponentBehavior: Bound

import QtQuick
import "root:/"
import "root:/components"

// Him.
//
// A sprite with a jaw and one thing it can be doing at a time: chomping,
// holding still, or dying. Which frame is on screen is the only state in here —
// where he *is* belongs to whatever put him there, because he is used both in
// the lane, where he moves, and in the row of lives, where he never does.
//
// The jaw runs on a timer rather than on a NumberAnimation, because it is not
// an animation: it is a frame counter, and the whole reason it looks like 1980
// is that it steps between six drawings instead of easing between two states.
PixelSprite {
    id: pac

    // Which way the mouth faces. Right while you type, left while you take it
    // back — the sprite is mirrored rather than redrawn, so both directions are
    // the same six frames.
    property int facing: 1

    property bool chomping: true

    // Set by die(), cleared by revive(). Kept as state rather than as a
    // parameter so the death frame survives the animation that is stepping
    // through it being restarted.
    property bool dying: false

    signal died

    property int chompFrame: 0
    property real deathStep: 0

    readonly property var frames: {
        if (pac.dying)
            return Arcade.pacDeath;

        return pac.facing >= 0 ? Arcade.pacRight : Arcade.pacLeft;
    }

    // The sprite sheet is built in Arcade's Component.onCompleted, so for the
    // first evaluation of this binding — which is what causes the singleton to
    // be created in the first place — there is nothing to index into yet.
    bitmap: {
        if (pac.frames.length === 0)
            return [];

        const step = pac.dying ? Math.round(pac.deathStep) : pac.chompFrame;
        return pac.frames[Math.max(0, Math.min(pac.frames.length - 1, step))];
    }

    pixel: Theme.lockPacPixel
    color: Theme.pacSelf

    function die() {
        pac.dying = true;
        death.restart();
    }

    function revive() {
        death.stop();
        pac.dying = false;
        pac.deathStep = 0;
        pac.chompFrame = 0;
    }

    Timer {
        running: pac.chomping && !pac.dying && pac.frames.length > 0
        interval: Theme.lockChompInterval
        repeat: true

        onTriggered: pac.chompFrame = (pac.chompFrame + 1) % pac.frames.length
    }

    // Eased into rather than run at a constant rate: the mouth opens slowly at
    // first and then goes all at once, which is the difference between him
    // being eaten by the ghost and him fading out.
    SequentialAnimation {
        id: death

        NumberAnimation {
            target: pac
            property: "deathStep"
            from: 0
            to: Arcade.deathAngles.length - 1
            duration: Theme.lockDeathDuration
            easing.type: Easing.InQuad
        }

        ScriptAction {
            script: pac.died()
        }
    }
}
