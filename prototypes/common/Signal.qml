import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs.core
import qs.components
import qs.services

// SIG-04 · Signal Rack: audio devices, application streams and media.
//
// Keys: ↑↓ select row · ←→ volume · M mute · ⏎ make default / play-pause /
// re-route stream · , . previous/next track.
FocusScope {
    id: rack
    required property var s

    property int selected: 0
    property string statusText: ""
    property string statusState: ""

    Component.onCompleted: Audio.detailed = true
    Component.onDestruction: Audio.detailed = false

    // Flat list of selectable rows across sections.
    readonly property var rows: {
        const out = [];
        Audio.sinks.forEach(n => out.push({
                kind: "sink",
                node: n
            }));
        Audio.sources.forEach(n => out.push({
                kind: "source",
                node: n
            }));
        if (Config.audio.showStreams)
            Audio.playbackStreams.forEach(n => out.push({
                    kind: "stream",
                    node: n
                }));
        Media.players.forEach(p => out.push({
                kind: "player",
                player: p
            }));
        return out;
    }
    readonly property var current: rows.length > 0 ? rows[Math.min(selected, rows.length - 1)] : null

    function report(promise) {
        statusText = "…";
        statusState = "busy";
        Promise.resolve(promise).then(r => {
            rack.statusText = r.message;
            rack.statusState = r.ok ? "ok" : "error";
        });
    }

    function nudge(row, delta) {
        if (!row)
            return;
        if (row.kind === "player") {
            report(Registry.execute(delta > 0 ? "media.next" : "media.previous", {}, {
                record: false
            }));
            return;
        }
        const n = row.node;
        if (!n.audio)
            return;
        const pct = Math.round(n.audio.volume * 100) + delta * Config.audio.volumeStep;
        const clamped = Math.max(0, Math.min(Config.audio.maxVolume, pct));
        if (row.kind === "stream")
            report(Audio.setStreamVolume(n.id, clamped));
        else {
            n.audio.volume = clamped / 100;
            statusText = Audio.label(n) + " " + clamped + "%";
            statusState = "ok";
        }
    }

    function primary(row) {
        if (!row)
            return;
        if (row.kind === "sink")
            report(Registry.execute("audio.output.set", {
                device: row.node.name
            }));
        else if (row.kind === "source")
            report(Registry.execute("audio.input.set", {
                device: row.node.name
            }));
        else if (row.kind === "player") {
            Media.selectedName = row.player.dbusName;
            report(Registry.execute("media.play-pause", {}, {
                record: false
            }));
        } else if (row.kind === "stream") {
            const sinks = Audio.sinks;
            if (sinks.length < 2) {
                statusText = "Only one output device";
                statusState = "caution";
                return;
            }
            const targets = Audio.streamTargets(row.node);
            const idx = targets.length ? sinks.indexOf(targets[0]) : -1;
            const next = sinks[(idx + 1) % sinks.length];
            report(Registry.execute("audio.stream.route", {
                stream: row.node.id,
                device: next.name
            }));
        }
    }

    function toggleMute(row) {
        if (!row || row.kind === "player" || !row.node.audio)
            return;
        report(Audio.setMuted(row.node, !row.node.audio.muted));
    }

    Keys.onPressed: event => {
        const k = event.key;
        if (k === Qt.Key_Down || k === Qt.Key_J)
            selected = Math.min(rows.length - 1, selected + 1);
        else if (k === Qt.Key_Up || k === Qt.Key_K)
            selected = Math.max(0, selected - 1);
        else if (k === Qt.Key_Right || k === Qt.Key_L)
            nudge(current, 1);
        else if (k === Qt.Key_Left || k === Qt.Key_H)
            nudge(current, -1);
        else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space)
            primary(current);
        else if (k === Qt.Key_M)
            toggleMute(current);
        else if (k === Qt.Key_Period)
            report(Registry.execute("media.next", {}, {
                record: false
            }));
        else if (k === Qt.Key_Comma)
            report(Registry.execute("media.previous", {}, {
                record: false
            }));
        else
            return;
        event.accepted = true;
    }

    // MPRIS position is not reactive; refresh once a second while visible.
    Timer {
        interval: 1000
        running: Media.playing
        repeat: true
        onTriggered: {
            const ps = Media.players;
            for (let i = 0; i < ps.length; i++)
                if (ps[i].positionSupported)
                    ps[i].positionChanged();
        }
    }

    function rowIndex(kind, obj) {
        for (let i = 0; i < rows.length; i++)
            if (rows[i].kind === kind && (rows[i].node === obj || rows[i].player === obj))
                return i;
        return -1;
    }

    readonly property real deviceWidth: s.architecture ? width * 0.55 : width * 0.58
    ListView {
        id: devices; width: rack.deviceWidth; height: parent.height - s.px(100)
        model: rack.rows.filter(r => r.kind !== "player"); spacing: s.px(18); clip: true
        boundsBehavior: Flickable.StopAtBounds
        delegate: Item {
            id: device
            required property var modelData
            readonly property var node: modelData.node
            readonly property bool bound: node && node.audio && node.ready
            readonly property real pct: bound ? node.audio.volume * 100 : NaN
            readonly property bool selected: rack.current && rack.current.node === node
            readonly property bool isDefault: node === Audio.sink || node === Audio.source
            width: devices.width; height: s.px(116)
            Rectangle { anchors.fill: parent; color: device.selected ? s.inset : s.surface }
            Rectangle { width: device.selected ? s.px(4) : 1; height: parent.height; color: device.selected ? s.accent : s.line }
            Ink { s: rack.s; x: s.px(18); y: s.px(12); text: modelData.kind === "sink" ? "OUTPUT" : modelData.kind === "source" ? "INPUT" : "APPLICATION STREAM"; font.pixelSize: s.small; color: s.dim }
            Ink { s: rack.s; x: s.px(18); y: s.px(34); width: parent.width - s.px(100); text: modelData.kind === "stream" ? Audio.streamLabel(node) : Audio.label(node); font.pixelSize: s.px(20) }
            Ink { s: rack.s; anchors.right: parent.right; anchors.rightMargin: s.px(16); y: s.px(38); text: !device.bound ? "N/A" : node.audio.muted ? "MUTED" : Math.round(device.pct) + "%"; mono: true; font.pixelSize: s.small; color: device.bound && node.audio.muted ? s.warning : s.ink }
            MouseArea {
                anchors.fill: parent
                onClicked: rack.selected = rack.rowIndex(modelData.kind, node)
                onDoubleClicked: rack.primary(modelData)
                onWheel: w => rack.nudge(modelData, w.angleDelta.y > 0 ? 1 : -1)
            }
            Rectangle {
                x: s.px(18); y: s.px(72); width: parent.width - s.px(36); height: s.px(6); color: s.line
                Rectangle { width: device.bound ? parent.width * Math.max(0, Math.min(Config.audio.maxVolume, device.pct)) / Config.audio.maxVolume : 0; height: parent.height; color: device.bound && node.audio.muted ? s.dim : s.accent }
                MouseArea {
                    anchors.fill: parent; anchors.topMargin: -s.px(8); anchors.bottomMargin: -s.px(8)
                    cursorShape: Qt.PointingHandCursor
                    function adjust(mouse) {
                        if (!device.bound) return;
                        rack.selected = rack.rowIndex(modelData.kind, node);
                        var value = Math.max(0, Math.min(Config.audio.maxVolume, Math.round(mouse.x / width * Config.audio.maxVolume)));
                        if (modelData.kind === "stream") rack.report(Audio.setStreamVolume(node.id, value));
                        else node.audio.volume = value / 100;
                    }
                    onPressed: mouse => adjust(mouse)
                    onPositionChanged: mouse => { if (pressed) adjust(mouse); }
                }
            }
            Ink { s: rack.s; x: s.px(18); y: s.px(88); width: parent.width-s.px(36); text: modelData.kind === "stream" ? (Audio.streamTargets(node).length ? "To " + Audio.streamTargets(node).map(n => Audio.label(n)).join(", ") : "Unlinked · Enter to route") : device.isDefault ? "Default device · Enter to select" : "Enter to make default"; font.pixelSize: s.small; color: s.dim }
        }
    }
    Column {
        x: rack.deviceWidth + s.px(40); width: parent.width - x; spacing: s.px(20)
        Ink { s: rack.s; text: "NOW PLAYING"; font.pixelSize: s.small; color: s.dim; font.letterSpacing: 1.4 }
        Repeater {
            model: Media.players
            delegate: Rectangle {
                required property var modelData
                readonly property var player: modelData
                readonly property bool lengthKnown: player.lengthSupported && player.length > 0 && player.position <= player.length + 2
                width: parent.width; height: s.px(272); color: s.surface
                border.width: 1; border.color: rack.current && rack.current.player === player ? s.accent : s.line
                Ink { s: rack.s; x: s.px(24); y: s.px(24); text: (player.isPlaying ? "Playing" : "Paused") + " / " + player.identity; font.pixelSize: s.small; color: s.dim }
                Ink { s: rack.s; x: s.px(24); y: s.px(60); width: parent.width-s.px(48); height: s.px(110); text: player.trackTitle || player.identity; font.pixelSize: s.px(s.architecture ? 28 : 36); font.weight: Font.Light; wrapMode: Text.WordWrap }
                Ink { s: rack.s; x: s.px(24); y: s.px(180); text: lengthKnown ? Math.floor(player.length / 60) + ":" + (Math.floor(player.length % 60) < 10 ? "0" : "") + Math.floor(player.length % 60) : "Live / length unknown"; font.pixelSize: s.small; color: s.dim }
                Row {
                    x: s.px(24); y: s.px(224); spacing: s.px(24)
                    Repeater {
                        model: [{label:"Previous",cmd:"media.previous",ok:player.canGoPrevious},{label:player.isPlaying?"Pause":"Play",cmd:"media.play-pause",ok:player.canTogglePlaying},{label:"Next",cmd:"media.next",ok:player.canGoNext}]
                        delegate: Ink {
                            required property var modelData
                            s: rack.s; text: modelData.label; color: modelData.ok ? s.accent : s.dim; font.pixelSize: s.small
                            opacity: modelData.ok ? 1 : 0.55
                            MouseArea { anchors.fill: parent; enabled: modelData.ok; onClicked: { rack.selected = rack.rowIndex("player", player); Media.selectedName = player.dbusName; rack.report(Registry.execute(modelData.cmd, {}, {record:false})); } }
                        }
                    }
                }
            }
        }
        Ink { s: rack.s; visible: Media.players.length === 0; text: "No media player"; color: s.dim }
    }
    Ink { s: rack.s; y: parent.height-s.px(60); width: parent.width; text: "↑↓  select     ←→  volume     Enter  default / play / route     M  mute     , .  track"; font.pixelSize: s.small; color: s.dim }
    Ink { s: rack.s; y: parent.height-s.px(30); width: parent.width; text: rack.statusText; color: rack.statusState === "error" ? s.error : s.dim; font.pixelSize: s.small }
}
