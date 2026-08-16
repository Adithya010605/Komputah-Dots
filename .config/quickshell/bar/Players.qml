pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Which media player the shell is talking about.
//
// D-Bus order says nothing about what you are actually listening to, so the
// shell tracks when each player last started playing and treats the most
// recent one as the subject. Bar module and media panel share this, so the
// title in the bar is always the track the panel opens on.
Singleton {
    id: root

    readonly property var players: Mpris.players.values

    // Held by identity rather than index so it survives players appearing and
    // disappearing underneath it.
    property string activeId: ""

    readonly property var active: {
        const list = players;
        if (list.length === 0)
            return null;

        for (const player of list) {
            if (playerId(player) === root.activeId)
                return player;
        }

        return list[0];
    }

    property var startedAt: ({})

    function playerId(player) {
        return player ? (player.dbusName || player.identity || "") : "";
    }

    function playerIcon(player) {
        const name = (playerId(player) + " " + (player && player.identity ? player.identity : "")).toLowerCase();

        if (name.includes("spotify"))
            return "\uf1bc";
        if (name.includes("firefox") || name.includes("zen"))
            return "\uf269";
        if (name.includes("chrom"))
            return "\uf268";
        if (name.includes("vlc") || name.includes("mpv"))
            return "󰕼";
        return "\uf001";
    }

    function trackTitle(player) {
        if (!player)
            return "";
        return player.trackTitle && player.trackTitle.length > 0 ? player.trackTitle : (player.identity || "Unknown track");
    }

    function trackSubtitle(player) {
        if (!player)
            return "";

        const parts = [];
        if (player.trackArtist && player.trackArtist.length > 0)
            parts.push(player.trackArtist);
        if (player.trackAlbum && player.trackAlbum.length > 0 && player.trackAlbum !== player.trackArtist)
            parts.push(player.trackAlbum);

        return parts.join(" · ");
    }

    function markStarted(id) {
        if (id.length === 0)
            return;

        const stamps = root.startedAt;
        stamps[id] = Date.now();
        root.startedAt = stamps;
    }

    // Index of whatever is actually making noise — and when several are, of the
    // one started most recently.
    function soundingIndex() {
        const list = players;
        if (list.length === 0)
            return -1;

        let target = -1;
        let best = -1;

        for (let i = 0; i < list.length; i++) {
            if (!list[i].isPlaying)
                continue;

            const stamp = root.startedAt[playerId(list[i])] ?? 0;
            if (stamp >= best) {
                best = stamp;
                target = i;
            }
        }

        // Nothing playing at all: fall back to the most recent thing that was.
        if (target < 0) {
            for (let i = 0; i < list.length; i++) {
                const stamp = root.startedAt[playerId(list[i])] ?? 0;
                if (stamp >= best) {
                    best = stamp;
                    target = i;
                }
            }
        }

        return target < 0 ? 0 : target;
    }

    function selectSounding() {
        const index = soundingIndex();
        if (index >= 0 && index < players.length)
            root.activeId = playerId(players[index]);
    }

    // ─── bar text ────────────────────────────────────────────────────
    //
    // Mirrors the old mpris.sh: pause marker, player glyph, title, and a count
    // when more than one player is alive.

    readonly property string barText: {
        const list = players;
        if (list.length === 0)
            return "Nothing playing";

        const player = active;
        if (!player)
            return "Nothing playing";

        let out = playerIcon(player) + " " + trackTitle(player);
        if (!player.isPlaying)
            out = "⏸ " + out;
        if (list.length > 1)
            out = out + " [" + list.length + "]";

        return out;
    }

    // The shell follows whatever starts playing, without waiting for a panel
    // to be opened.
    Instantiator {
        model: Mpris.players

        delegate: QtObject {
            required property var modelData

            readonly property bool sounding: modelData.isPlaying

            onSoundingChanged: {
                if (sounding) {
                    root.markStarted(root.playerId(modelData));
                    root.activeId = root.playerId(modelData);
                }
            }

            Component.onCompleted: {
                if (sounding)
                    root.markStarted(root.playerId(modelData));
            }
        }
    }
}
