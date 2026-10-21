pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.core

// PipeWire audio through Quickshell's native PipeWire module (no wpctl or
// pactl subprocesses). Volumes are PipeWire's linear channel volumes shown as
// percent (1.0 = 100%).
//
// Volume and mute are only valid for nodes bound with PwObjectTracker. The
// default sink and source are always bound (the Flight Strip shows them);
// every other device and stream is bound only while the Signal Rack asks
// for it through `detailed`, which keeps idle work minimal.
Singleton {
    id: root

    property bool detailed: false

    readonly property bool ready: Pipewire.ready
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var preferredSink: Pipewire.preferredDefaultAudioSink
    readonly property var preferredSource: Pipewire.preferredDefaultAudioSource
    readonly property var nodes: Pipewire.nodes.values

    readonly property var sinks: nodes.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var sources: nodes.filter(n => n.audio && !n.isSink && !n.isStream)
    // Playback streams output audio (isSink false); capture streams take it.
    readonly property var playbackStreams: nodes.filter(n => n.audio && n.isStream && !n.isSink)
    readonly property var captureStreams: nodes.filter(n => n.audio && n.isStream && n.isSink)

    readonly property bool sinkReady: sink !== null && sink.audio !== null && sink.ready
    readonly property real volume: sinkReady ? sink.audio.volume : 0
    readonly property bool muted: sinkReady ? sink.audio.muted : false
    readonly property int volumePercent: Math.round(volume * 100)
    readonly property bool sourceMuted: source && source.audio ? source.audio.muted : false

    PwObjectTracker {
        objects: [root.sink, root.source]
    }
    PwObjectTracker {
        objects: root.detailed ? root.sinks.concat(root.sources, root.playbackStreams, root.captureStreams) : []
    }

    function label(node) {
        if (!node)
            return "none";
        return node.nickname || node.description || node.name;
    }

    function streamLabel(node) {
        if (!node)
            return "";
        const p = node.properties || {};
        return p["application.name"] || node.description || node.name;
    }

    function findDevice(name, wantSink) {
        const list = wantSink ? sinks : sources;
        for (let i = 0; i < list.length; i++)
            if (list[i].name === name)
                return list[i];
        return null;
    }

    function maxLevel() {
        return Config.audio.maxVolume;
    }

    // Set the default sink volume (percent) and confirm PipeWire applied it.
    function setVolume(percent) {
        if (!sinkReady)
            return Promise.resolve(Registry.fail("No default audio output"));
        const target = Math.max(0, Math.min(maxLevel(), percent)) / 100;
        const node = sink;
        const before = Math.round(node.audio.volume * 100);
        node.audio.volume = target;
        return Wait.until(() => Math.abs(node.audio.volume - target) < 0.006, 1500).then(okay => okay ? Registry.ok("Volume " + Math.round(target * 100) + "%", {
                undo: {
                    commandId: "audio.volume.set",
                    args: {
                        level: before
                    }
                }
            }) : Registry.fail("PipeWire did not confirm the volume change"));
    }

    function setMuted(node, muted) {
        if (!node || !node.audio)
            return Promise.resolve(Registry.fail("Device not available"));
        const before = node.audio.muted;
        node.audio.muted = muted;
        return Wait.until(() => node.audio.muted === muted, 1500).then(okay => okay ? Registry.ok((muted ? "Muted " : "Unmuted ") + label(node), {
                undo: before !== muted ? {
                    commandId: node.isSink ? "audio.mute.set" : "audio.input.mute.set",
                    args: {
                        muted: before
                    }
                } : undefined
            }) : Registry.fail("PipeWire did not confirm the mute change"));
    }

    // Default device changes are a preference; PipeWire may refuse. Only
    // report success once the effective default actually changed.
    function setDefault(name, wantSink) {
        const node = findDevice(name, wantSink);
        if (!node)
            return Promise.resolve(Registry.fail("No " + (wantSink ? "output" : "input") + " device named " + name));
        const prev = wantSink ? sink : source;
        if (wantSink)
            Pipewire.preferredDefaultAudioSink = node;
        else
            Pipewire.preferredDefaultAudioSource = node;
        return Wait.until(() => (wantSink ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource) === node, 2500).then(okay => okay ? Registry.ok((wantSink ? "Output: " : "Input: ") + label(node), {
                undo: prev && prev !== node ? {
                    commandId: wantSink ? "audio.output.set" : "audio.input.set",
                    args: {
                        device: prev.name
                    }
                } : undefined
            }) : Registry.fail("PipeWire kept " + label(wantSink ? Pipewire.defaultAudioSink : Pipewire.defaultAudioSource) + " as default"));
    }

    function setStreamVolume(id, percent) {
        const list = playbackStreams.concat(captureStreams);
        for (let i = 0; i < list.length; i++)
            if (list[i].id === id) {
                const n = list[i];
                if (!n.audio || !n.ready)
                    return Promise.resolve(Registry.fail("Stream is not bound yet; open the Signal Rack"));
                const target = Math.max(0, Math.min(maxLevel(), percent)) / 100;
                n.audio.volume = target;
                return Wait.until(() => Math.abs(n.audio.volume - target) < 0.006, 1500).then(okay => okay ? Registry.ok(streamLabel(n) + " " + Math.round(target * 100) + "%") : Registry.fail("PipeWire did not confirm the stream volume"));
            }
        return Promise.resolve(Registry.fail("No stream with id " + id));
    }

    // Sinks a playback stream is currently linked to (from PipeWire's link
    // graph, deduplicated per source/target pair).
    function streamTargets(node) {
        const groups = Pipewire.linkGroups.values;
        const out = [];
        for (let i = 0; i < groups.length; i++)
            if (groups[i].source === node && groups[i].target && out.indexOf(groups[i].target) === -1)
                out.push(groups[i].target);
        return out;
    }

    // Move a playback stream to another sink. WirePlumber honours the
    // `target.object` key in the "default" metadata (verified against
    // WirePlumber 0.5.18); success is reported only once PipeWire's link
    // graph shows the stream connected to the requested sink.
    function routeStream(id, deviceName) {
        const stream = playbackStreams.filter(n => n.id === id)[0];
        if (!stream)
            return Promise.resolve(Registry.fail("No playback stream with id " + id));
        const target = findDevice(deviceName, true);
        if (!target)
            return Promise.resolve(Registry.fail("No output device named " + deviceName));
        const before = streamTargets(stream);
        return Exec.run(["pw-metadata", "-n", "default", String(id), "target.object", target.name, "Spa:String"], {
            timeoutMs: 4000
        }).then(r => {
            if (r.code !== 0)
                return Registry.fail("pw-metadata failed (" + (r.timedOut ? "timed out" : "status " + r.code) + ")", {
                    detail: r.stderr.trim().slice(0, 200)
                });
            return Wait.until(() => root.streamTargets(stream).indexOf(target) !== -1, 3000).then(okay => okay ? Registry.ok(streamLabel(stream) + " → " + label(target), {
                    undo: before.length === 1 && before[0] !== target ? {
                        commandId: "audio.stream.route",
                        args: {
                            stream: id,
                            device: before[0].name
                        }
                    } : undefined
                }) : Registry.fail("WirePlumber did not move " + streamLabel(stream) + " to " + label(target)));
        });
    }

    readonly property var audioAvailable: () => root.ready ? (root.sink ? true : "No default audio output") : "PipeWire is not connected"

    Component.onCompleted: {
        Registry.register({
            id: "audio.volume.set",
            title: "Set volume",
            category: "audio",
            alias: "vol",
            keywords: ["volume", "loudness", "sound"],
            description: "Set output volume in percent",
            params: [
                {
                    name: "level",
                    type: "int",
                    min: 0,
                    max: 150,
                    required: true,
                    description: "Percent"
                }
            ],
            routine: true,
            available: audioAvailable,
            run: args => args.level > root.maxLevel() ? Registry.fail("Volume is limited to " + root.maxLevel() + "% (audio.maxVolume)") : root.setVolume(args.level)
        });
        Registry.register({
            id: "audio.volume.up",
            title: "Volume up",
            category: "audio",
            keywords: ["louder", "raise"],
            routine: true,
            available: audioAvailable,
            run: () => root.setVolume(root.volumePercent + Config.audio.volumeStep)
        });
        Registry.register({
            id: "audio.volume.down",
            title: "Volume down",
            category: "audio",
            keywords: ["quieter", "lower"],
            routine: true,
            available: audioAvailable,
            run: () => root.setVolume(root.volumePercent - Config.audio.volumeStep)
        });
        Registry.register({
            id: "audio.mute.toggle",
            title: "Toggle mute",
            category: "audio",
            alias: "mute",
            keywords: ["silence", "sound"],
            available: audioAvailable,
            run: () => root.setMuted(root.sink, !root.muted)
        });
        Registry.register({
            id: "audio.mute.set",
            title: "Set output mute",
            category: "audio",
            hidden: true,
            params: [
                {
                    name: "muted",
                    type: "bool",
                    required: true
                }
            ],
            routine: true,
            available: audioAvailable,
            run: args => root.setMuted(root.sink, args.muted)
        });
        Registry.register({
            id: "audio.input.mute.toggle",
            title: "Toggle microphone mute",
            category: "audio",
            alias: "mic",
            keywords: ["microphone", "input", "capture"],
            available: () => root.source ? true : "No default audio input",
            run: () => root.setMuted(root.source, !root.sourceMuted)
        });
        Registry.register({
            id: "audio.input.mute.set",
            title: "Set microphone mute",
            category: "audio",
            hidden: true,
            params: [
                {
                    name: "muted",
                    type: "bool",
                    required: true
                }
            ],
            routine: true,
            available: () => root.source ? true : "No default audio input",
            run: args => root.setMuted(root.source, args.muted)
        });
        Registry.register({
            id: "audio.output.set",
            title: "Set audio output",
            category: "audio",
            alias: "out",
            keywords: ["speaker", "headphones", "sink", "device"],
            params: [
                {
                    name: "device",
                    type: "enum",
                    required: true,
                    choices: () => root.sinks.map(n => ({
                                value: n.name,
                                label: root.label(n)
                            }))
                }
            ],
            routine: true,
            available: () => root.ready ? true : "PipeWire is not connected",
            describe: args => {
                const n = root.findDevice(args.device, true);
                return n ? root.label(n) : args.device + " (not connected)";
            },
            run: args => root.setDefault(args.device, true)
        });
        Registry.register({
            id: "audio.input.set",
            title: "Set audio input",
            category: "audio",
            alias: "in",
            keywords: ["microphone", "source", "device"],
            params: [
                {
                    name: "device",
                    type: "enum",
                    required: true,
                    choices: () => root.sources.map(n => ({
                                value: n.name,
                                label: root.label(n)
                            }))
                }
            ],
            routine: true,
            available: () => root.ready ? true : "PipeWire is not connected",
            run: args => root.setDefault(args.device, false)
        });
        Registry.register({
            id: "audio.stream.volume.set",
            title: "Set application volume",
            category: "audio",
            hidden: true,
            params: [
                {
                    name: "stream",
                    type: "int",
                    min: 0,
                    required: true
                },
                {
                    name: "level",
                    type: "int",
                    min: 0,
                    max: 150,
                    required: true
                }
            ],
            available: () => root.ready ? true : "PipeWire is not connected",
            run: args => root.setStreamVolume(args.stream, args.level)
        });

        Registry.register({
            id: "audio.stream.route",
            title: "Route application audio",
            category: "audio",
            hidden: true,
            params: [
                {
                    name: "stream",
                    type: "int",
                    min: 0,
                    required: true
                },
                {
                    name: "device",
                    type: "enum",
                    required: true,
                    choices: () => root.sinks.map(n => n.name)
                }
            ],
            available: () => root.ready ? true : "PipeWire is not connected",
            run: args => root.routeStream(args.stream, args.device)
        });
        Registry.registerProvider({
            id: "audio-devices",
            kind: "device",
            items: () => {
                const out = [];
                for (let i = 0; i < root.sinks.length; i++) {
                    const n = root.sinks[i];
                    out.push({
                        id: "out:" + n.name,
                        title: root.label(n),
                        subtitle: n === root.sink ? "Output · current default" : "Output device",
                        keywords: ["output", "speaker", "headphones"],
                        category: "audio",
                        commandId: "audio.output.set",
                        args: {
                            device: n.name
                        },
                        badge: n === root.sink ? "DEFAULT" : ""
                    });
                }
                for (let i = 0; i < root.sources.length; i++) {
                    const n = root.sources[i];
                    out.push({
                        id: "in:" + n.name,
                        title: root.label(n),
                        subtitle: n === root.source ? "Input · current default" : "Input device",
                        keywords: ["input", "microphone"],
                        category: "audio",
                        commandId: "audio.input.set",
                        args: {
                            device: n.name
                        },
                        badge: n === root.source ? "DEFAULT" : ""
                    });
                }
                return out;
            }
        });
    }
}
