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

    Bezel {
        anchors.centerIn: parent
        width: Math.min(Theme.px(1360), parent.width - Theme.pad * 4)
        height: Math.min(Theme.px(780), parent.height - Theme.pad)
        designation: "SIG-04"
        title: "Signal Rack"
        status: Audio.ready ? Audio.sinks.length + " OUT · " + Audio.sources.length + " IN · " + Audio.playbackStreams.length + " STREAMS · " + Media.players.length + " PLAYERS" : "PIPEWIRE NOT CONNECTED"
        statusColor: Audio.ready ? Theme.textDim : Theme.caution

        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.pad
            z: -1
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.pad

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.pad * 2

                // Devices
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 36
                    Layout.fillHeight: true
                    spacing: Theme.px(2)
                    Label {
                        text: "Output devices"
                    }
                    Repeater {
                        model: Audio.sinks
                        delegate: DeviceRow {
                            required property var modelData
                            Layout.fillWidth: true
                            node: modelData
                            isDefault: modelData === Audio.sink
                            preferred: modelData === Audio.preferredSink
                            selected: rack.current && rack.current.node === modelData
                            onPicked: rack.selected = rack.rowIndex("sink", modelData)
                            onMakeDefault: rack.primary({
                                kind: "sink",
                                node: modelData
                            })
                            onMuteToggled: rack.toggleMute({
                                kind: "sink",
                                node: modelData
                            })
                        }
                    }
                    Label {
                        visible: Audio.sinks.length === 0
                        text: Audio.ready ? "No output devices" : "Waiting for PipeWire…"
                    }
                    Item {
                        Layout.preferredHeight: Theme.pad
                    }
                    Label {
                        text: "Input devices"
                    }
                    Repeater {
                        model: Audio.sources
                        delegate: DeviceRow {
                            required property var modelData
                            Layout.fillWidth: true
                            node: modelData
                            isDefault: modelData === Audio.source
                            preferred: modelData === Audio.preferredSource
                            selected: rack.current && rack.current.node === modelData
                            onPicked: rack.selected = rack.rowIndex("source", modelData)
                            onMakeDefault: rack.primary({
                                kind: "source",
                                node: modelData
                            })
                            onMuteToggled: rack.toggleMute({
                                kind: "source",
                                node: modelData
                            })
                        }
                    }
                    Label {
                        visible: Audio.sources.length === 0
                        text: "No input devices"
                    }
                    Item {
                        Layout.fillHeight: true
                    }
                }

                // Streams
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 32
                    Layout.fillHeight: true
                    visible: Config.audio.showStreams
                    spacing: Theme.px(2)
                    Label {
                        text: "Application streams"
                    }
                    Repeater {
                        model: Audio.playbackStreams
                        delegate: StreamRow {
                            required property var modelData
                            Layout.fillWidth: true
                            node: modelData
                            selected: rack.current && rack.current.node === modelData
                            onPicked: rack.selected = rack.rowIndex("stream", modelData)
                            onReroute: rack.primary({
                                kind: "stream",
                                node: modelData
                            })
                        }
                    }
                    Label {
                        visible: Audio.playbackStreams.length === 0
                        text: "No application is playing audio"
                    }
                    Item {
                        Layout.fillHeight: true
                    }
                }

                // Media
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 32
                    Layout.fillHeight: true
                    spacing: Theme.pad
                    Label {
                        text: "Media players (MPRIS)"
                    }
                    Repeater {
                        model: Media.players
                        delegate: PlayerCard {
                            required property var modelData
                            Layout.fillWidth: true
                            player: modelData
                            active: modelData === Media.active
                            selected: rack.current && rack.current.player === modelData
                            onPicked: {
                                rack.selected = rack.rowIndex("player", modelData);
                                Media.selectedName = modelData.dbusName;
                            }
                            onCommand: id => rack.report(Registry.execute(id, {}, {
                                    record: false
                                }))
                        }
                    }
                    Label {
                        visible: Media.players.length === 0
                        text: "No MPRIS player is running"
                    }
                    Item {
                        Layout.fillHeight: true
                    }
                }
            }

            StatusLine {
                Layout.fillWidth: true
                hints: [
                    {
                        key: "↑↓",
                        action: "select"
                    },
                    {
                        key: "←→",
                        action: "volume"
                    },
                    {
                        key: "⏎",
                        action: "default / play / route"
                    },
                    {
                        key: "M",
                        action: "mute"
                    },
                    {
                        key: ", .",
                        action: "track"
                    }
                ]
                message: rack.statusText
                messageState: rack.statusState
            }
        }
    }
}
