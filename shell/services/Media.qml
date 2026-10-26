pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.core

// MPRIS media players. Player support varies widely, so every control is
// gated on the player's own canXyz property and reported as unavailable
// rather than attempted.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    // The user's explicit pick, by D-Bus name. Falls back automatically.
    property string selectedName: ""

    readonly property var active: {
        const list = players;
        if (list.length === 0)
            return null;
        for (let i = 0; i < list.length; i++)
            if (list[i].dbusName === selectedName)
                return list[i];
        for (let i = 0; i < list.length; i++)
            if (list[i].isPlaying)
                return list[i];
        return list[0];
    }
    readonly property bool playing: active ? active.isPlaying : false
    readonly property string title: active ? (active.trackTitle || active.identity) : ""
    readonly property string artist: active ? active.trackArtist : ""

    function playerLabel(p) {
        return p ? (p.identity || p.dbusName) : "";
    }

    function find(name) {
        for (let i = 0; i < players.length; i++)
            if (players[i].dbusName === name)
                return players[i];
        return null;
    }

    // Track changes cannot be confirmed reliably (players update metadata
    // at different times), so these report that the request was sent.
    function control(capability, action, label) {
        const p = active;
        if (!p)
            return Registry.fail("No media player");
        if (!p[capability])
            return Registry.fail(playerLabel(p) + " does not support " + label.toLowerCase());
        p[action]();
        return Registry.ok(label + " requested · " + playerLabel(p));
    }

    // Play/pause is confirmed by watching the playback state flip.
    function togglePlaying() {
        const p = active;
        if (!p)
            return Promise.resolve(Registry.fail("No media player"));
        if (!p.canTogglePlaying)
            return Promise.resolve(Registry.fail(playerLabel(p) + " cannot be controlled"));
        const want = !p.isPlaying;
        p.togglePlaying();
        return Wait.until(() => p.isPlaying === want, 2000).then(okay => okay ? Registry.ok((want ? "Playing · " : "Paused · ") + playerLabel(p)) : Registry.fail(playerLabel(p) + " did not change playback state"));
    }

    readonly property var hasPlayer: () => root.active ? true : "No media player is running"

    Component.onCompleted: {
        Registry.register({
            id: "media.play-pause",
            title: "Play / pause",
            category: "media",
            alias: "pp",
            keywords: ["play", "pause", "music", "toggle"],
            routine: true,
            available: () => !root.active ? "No media player is running" : root.active.canTogglePlaying ? true : root.playerLabel(root.active) + " cannot be controlled",
            run: () => root.togglePlaying()
        });
        Registry.register({
            id: "media.pause",
            title: "Pause media",
            category: "media",
            keywords: ["stop", "music"],
            routine: true,
            available: hasPlayer,
            run: () => root.control("canPause", "pause", "Pause")
        });
        Registry.register({
            id: "media.next",
            title: "Next track",
            category: "media",
            alias: "next",
            keywords: ["skip", "forward"],
            routine: true,
            available: () => !root.active ? "No media player is running" : root.active.canGoNext ? true : root.playerLabel(root.active) + " has no next track",
            run: () => root.control("canGoNext", "next", "Next track")
        });
        Registry.register({
            id: "media.previous",
            title: "Previous track",
            category: "media",
            alias: "prev",
            keywords: ["back", "rewind"],
            routine: true,
            available: () => !root.active ? "No media player is running" : root.active.canGoPrevious ? true : root.playerLabel(root.active) + " has no previous track",
            run: () => root.control("canGoPrevious", "previous", "Previous track")
        });
        Registry.register({
            id: "media.player.select",
            title: "Select media player",
            category: "media",
            hidden: true,
            params: [
                {
                    name: "player",
                    type: "enum",
                    required: true,
                    choices: () => root.players.map(p => p.dbusName)
                }
            ],
            run: args => {
                const p = root.find(args.player);
                if (!p)
                    return Registry.fail("Player is gone");
                root.selectedName = p.dbusName;
                return Registry.ok("Controlling " + root.playerLabel(p));
            }
        });
        Registry.registerProvider({
            id: "media-players",
            kind: "player",
            items: () => root.players.map(p => ({
                        id: p.dbusName,
                        title: root.playerLabel(p) + (p.trackTitle ? " · " + p.trackTitle : ""),
                        subtitle: (p.isPlaying ? "Playing" : "Paused") + (p.trackArtist ? " · " + p.trackArtist : ""),
                        keywords: ["media", "player", "music"],
                        category: "media",
                        commandId: "media.player.select",
                        args: {
                            player: p.dbusName
                        },
                        badge: p === root.active ? "ACTIVE" : ""
                    }))
        });
    }
}
