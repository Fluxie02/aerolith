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

    // The Deck sets `active` false as soon as this bay stops being requested
    // (its pixels may stay briefly for an exit transition); detail demand
    // follows `active`, so closing releases it at once.
    property bool active: true
    property bool holding: false
    function hold(on) {
        if (on === holding)
            return;
        holding = on;
        if (on)
            Audio.acquireDetail();
        else
            Audio.releaseDetail();
    }
    onActiveChanged: hold(active)
    Component.onCompleted: hold(active)
    Component.onDestruction: hold(false)

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
        else if (k === Qt.Key_PageDown || k === Qt.Key_PageUp) {
            const direction = k === Qt.Key_PageDown ? 1 : -1;
            contentView.contentY = Math.max(0, Math.min(contentView.contentHeight - contentView.height, contentView.contentY + direction * contentView.height * .8));
        } else
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
        anchors.fill: parent
        designation: "SIG / 04"
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

            Flickable {
                id: contentView
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 0
                contentWidth: width
                contentHeight: contentRow.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                function reveal(item) {
                    if (!item) return;
                    const top = item.mapToItem(contentRow, 0, 0).y;
                    contentY = Math.max(0, Math.min(contentHeight - height, top < contentY ? top : top + item.height > contentY + height ? top + item.height - height : contentY));
                }
                RowLayout {
                    id: contentRow
                    width: contentView.width
                    height: Math.max(implicitHeight, contentView.height)
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
                                id: deviceRow
                                onSelectedChanged: if (selected) contentView.reveal(deviceRow)
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
                        Text {
                            visible: Audio.sinks.length === 0
                            Layout.fillWidth: true
                            text: Audio.ready ? "No output devices" : "Waiting for PipeWire…"
                            textFormat: Text.PlainText
                            wrapMode: Text.WordWrap
                            color: Theme.textDim
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontSm
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
                                id: deviceRow
                                onSelectedChanged: if (selected) contentView.reveal(deviceRow)
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
                        Text {
                            visible: Audio.sources.length === 0
                            Layout.fillWidth: true
                            text: "No input devices"
                            textFormat: Text.PlainText
                            wrapMode: Text.WordWrap
                            color: Theme.textDim
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontSm
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
                                id: streamRow
                                onSelectedChanged: if (selected) contentView.reveal(streamRow)
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
                        Text {
                            visible: Audio.playbackStreams.length === 0
                            Layout.fillWidth: true
                            text: "No application is playing audio"
                            textFormat: Text.PlainText
                            wrapMode: Text.WordWrap
                            color: Theme.textDim
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontSm
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
                                id: playerRow
                                onSelectedChanged: if (selected) contentView.reveal(playerRow)
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
                        Text {
                            visible: Media.players.length === 0
                            Layout.fillWidth: true
                            text: "No MPRIS player is running"
                            textFormat: Text.PlainText
                            wrapMode: Text.WordWrap
                            color: Theme.textDim
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontSm
                        }
                        Item {
                            Layout.fillHeight: true
                        }
                    }
                }
            }
            Rectangle {
                Layout.alignment: Qt.AlignRight
                Layout.preferredWidth: Math.max(Theme.du(24), contentView.width * Math.min(1, contentView.height / Math.max(1, contentView.contentHeight)))
                implicitHeight: Theme.px(2)
                visible: contentView.contentHeight > contentView.height
                color: Theme.signal
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
