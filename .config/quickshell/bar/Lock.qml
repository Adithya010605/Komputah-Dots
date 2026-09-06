pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pam

// Whether the session is locked, and what the screen is doing about it.
//
// Separated from LockScreen.qml the way Launcher is separated from
// LauncherMenu and Power from PowerMenu: what a lock screen *is* — a buffer, an
// authentication attempt and four things that can come of it — has nothing to
// do with pellets, and only one of the two files should have to know about PAM.
//
// The state machine is four words and it is the whole of the screen's
// behaviour:
//
//   waiting    typing is accepted, Enter submits
//   checking   PAM has the buffer, nothing is accepted
//   failed     the ghost has him; typing resumes when the board is back
//   won        the dash is running; the session is released at the end of it
//
// The lock is *not* released the moment PAM says yes. It is released when the
// screen says it has finished showing you that PAM said yes, which is a beat
// later and is the whole reason the animation exists.
Singleton {
    id: root

    // Bound to the actual session lock in LockScreen.qml. Setting this is what
    // locks the session; nothing else in the shell does.
    property bool locked: false

    property string state: "waiting"

    // The password, held for exactly as long as it takes PAM to be asked about
    // it. Cleared the instant an answer comes back, in every branch.
    property string buffer: ""

    // How many characters the lane is drawing. Deliberately not
    // `buffer.length`: on a failure the buffer is emptied at once — the secret
    // has no reason to outlive the attempt — but the pellets have to stay eaten
    // for the second and a bit it takes the ghost to arrive, or he is teleported
    // back to the start of the lane while something is running at where he used
    // to be.
    property int count: 0

    onBufferChanged: {
        if (root.state === "waiting")
            root.count = root.buffer.length;
    }

    // Uppercase, always, because the only face it is ever set in has no
    // lowercase in it.
    property string message: "READY!"

    readonly property int maxLives: 3
    property int lives: root.maxLives

    // ─── locking ─────────────────────────────────────────────────────

    function lock() {
        if (root.locked)
            return;

        root.reset();
        root.locked = true;
    }

    function reset() {
        root.buffer = "";
        root.count = 0;
        root.state = "waiting";
        root.message = "READY!";
        root.lives = root.maxLives;
    }

    // Called by the screen at the end of the winning dash, and by nothing else.
    // The count is deliberately left alone: zeroing it here would run the lane
    // back through the tunnel — a wrap is what a jump of more than one slot
    // means — in the middle of the fade that is already taking the screen away.
    // lock() clears it on the way back in.
    function release() {
        root.buffer = "";
        root.locked = false;
    }

    // ─── trying ──────────────────────────────────────────────────────

    function submit() {
        if (root.state !== "waiting")
            return;

        // A fresh attempt is answerable again, whatever happened to the last
        // one. Cleared here rather than in the handlers below so that an
        // abandoned conversation which never says anything at all cannot leave
        // the flag set over a real answer.
        root.ignoringPam = false;

        // An empty attempt is a keypress, not a login. Sending it to PAM would
        // buy a two-second delay and a wrong answer, which is a strange thing to
        // do to somebody who has just leant on the Enter key.
        if (root.buffer.length === 0)
            return;

        root.state = "checking";
        root.message = "CHECKING";

        if (!pam.start()) {
            root.buffer = "";
            root.fail("PAM WOULD NOT START");
        }
    }

    function fail(text: string) {
        root.lives = Math.max(0, root.lives - 1);
        root.message = root.lives === 0 ? "GAME OVER" : text;
        root.state = "failed";
    }

    // The screen calls this when the ghost has been and gone and the board is
    // back. Only then is the keyboard live again.
    function recover() {
        if (root.state !== "failed")
            return;

        root.count = 0;
        root.state = "waiting";
        root.message = root.lives === 0 ? "INSERT COIN" : "READY!";

        // A fresh three. Nothing is actually gated on running out — a lock
        // screen that stops accepting the correct password is a lock screen
        // that has locked the wrong person out — so the counter is a scoreboard
        // and this is it rolling over.
        if (root.lives === 0)
            root.lives = root.maxLives;
    }

    // ─── not getting stuck ───────────────────────────────────────────
    //
    // Both busy states hand the keyboard to something that has promised to give
    // it back — `checking` to PAM, `failed` to the animation that plays the
    // failure out — and neither promise survives the machine going to sleep in
    // the middle of it. A PAM conversation interrupted by suspend can come back
    // with no answer at all; an animation frozen with the display is an
    // animation whose completion handler has not run, and it is that handler
    // which calls recover(). Either way the state word never leaves the busy
    // value, `readOnly` above it stays true, and the screen quietly stops
    // accepting the password.
    //
    // So each busy state is given a deadline. Nothing here is on the normal
    // path: PAM answers inside a second and the failure runs in about one and a
    // half, and the state changing out from under this is what stops it, long
    // before either number below is reached.
    Timer {
        id: deadline

        running: root.locked && (root.state === "checking" || root.state === "failed")
        interval: root.state === "failed" ? 6000 : 25000
        repeat: false

        onTriggered: {
            // The board came back while nobody was watching it. recover() puts
            // the state and the message right; the ghost still standing on the
            // lane is left to the animation that owns it, which will finish
            // whenever the display does.
            if (root.state === "failed") {
                root.recover();
                return;
            }

            // A check that never came back. Whatever the stack is still doing,
            // it is doing it about a password that is already gone, and its
            // answer — including the error it will raise about being cut off —
            // is no longer about anything the screen is showing.
            root.ignoringPam = true;

            if (pam.active)
                pam.abort();

            root.buffer = "";
            root.count = 0;
            root.state = "waiting";
            root.message = "READY!";
        }
    }

    // Whether the next thing PAM says is about an attempt that has already been
    // given up on. See the deadline above, which is the only thing that sets it.
    property bool ignoringPam: false

    PamContext {
        id: pam

        // The stack hyprlock authenticates against, reached directly rather than
        // through hyprlock's own one-line forward to it. Same rules, minus a
        // dependency on a package this shell no longer starts: /etc/pam.d/login
        // is part of the base system and /etc/pam.d/hyprlock is not.
        //
        // Only pam_authenticate is ever called, so the account and session
        // halves of that stack are never entered.
        config: "login"

        onPamMessage: {
            if (pam.responseRequired)
                pam.respond(root.buffer);
        }

        onCompleted: result => {
            if (root.ignoringPam)
                return;

            // Gone before the animation that reports on it starts. Nothing below
            // this line needs the password and something above it might still be
            // holding a reference to the string if it were cleared any later.
            root.buffer = "";

            if (result === PamResult.Success) {
                root.state = "won";
                root.message = "LEVEL CLEARED";
                return;
            }

            if (result === PamResult.MaxTries) {
                root.fail("NO MORE TRIES");
                return;
            }

            root.fail("TRY AGAIN");
        }

        onError: error => {
            if (root.ignoringPam)
                return;

            root.buffer = "";
            root.fail("PAM " + PamError.toString(error).toUpperCase());
        }
    }
}
