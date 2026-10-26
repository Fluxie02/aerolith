import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.services

// Host for the OSD (roadmap D01). Watches real state, not commands, so a
// volume key, `wpctl` or another application all show it the same way:
// output volume and mute, and input (microphone) mute.
//
// - One OSD at a time: a new change updates the one already shown and
//   restarts its expiry.
// - Nothing is shown for the values PipeWire reports while the shell starts
//   or for a change made in the open Deck, which shows the level itself.
// - The surface exists only while the OSD is presented or leaving
//   (OsdView.settled), takes no input and no keyboard focus, so it never
//   moves focus away from a game and costs nothing when idle.
Scope {
    id: host

    property string kind: "volume"
    property real value: NaN
    property bool muted: false
    property real maxValue: 1
    property string label: ""
    // Requested presentation, and whether the surface exists.
    property bool presenting: false
    property bool mapped: false
    // Values PipeWire reports while the shell starts are not changes.
    property bool armed: false
    readonly property int lifetimeMs: 1500

    function show(nextKind) {
        if (!armed || Ui.deckMapped)
            return;
        kind = nextKind;
        if (nextKind === "mic") {
            value = Audio.source && Audio.source.audio ? Audio.source.audio.volume : NaN;
            muted = Audio.sourceMuted;
            maxValue = 1;
            label = Audio.source ? Audio.label(Audio.source) : "";
        } else {
            value = Audio.volume;
            muted = Audio.muted;
            maxValue = Math.max(1, Audio.maxLevel() / 100);
            label = Audio.sink ? Audio.label(Audio.sink) : "";
        }
        mapped = true;
        presenting = true;
        expiry.restart();
    }
    // For diagnostics and tests (ControlSurface status).
    Binding {
        target: Ui
        property: "osdKind"
        value: host.presenting ? host.kind : ""
    }

    Connections {
        target: Audio
        function onVolumeChanged() {
            host.show("volume");
        }
        function onMutedChanged() {
            host.show("volume");
        }
        function onSourceMutedChanged() {
            host.show("mic");
        }
        function onVolumeKnownChanged() {
            if (Audio.volumeKnown)
                arming.restart();
        }
    }
    Timer {
        id: arming
        interval: 1000
        onTriggered: host.armed = true
    }
    Timer {
        id: expiry
        interval: host.lifetimeMs
        onTriggered: host.presenting = false
    }
    // The Deck opening over the OSD takes over.
    Connections {
        target: Ui
        function onDeckMappedChanged() {
            if (Ui.deckMapped) {
                expiry.stop();
                host.presenting = false;
            }
        }
    }

    LazyLoader {
        active: host.mapped && Ui.screen !== null
        PanelWindow {
            screen: Ui.screen
            color: "transparent"
            anchors.bottom: true
            margins.bottom: Theme.du(96)
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: view.implicitWidth
            implicitHeight: view.implicitHeight
            mask: Region {}
            WlrLayershell.namespace: "aerolith-osd"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            OsdView {
                id: view
                anchors.fill: parent
                kind: host.kind
                value: host.value
                muted: host.muted
                maxValue: host.maxValue
                label: host.label
                presentationOpen: host.presenting
                // settled() can fire while the loader is still creating the
                // surface (a view created already closed settles at once);
                // unload on the next turn, not inside that creation.
                onSettled: Qt.callLater(() => {
                    if (!host.presenting)
                        host.mapped = false;
                })
            }
        }
    }

    Component.onCompleted: if (Audio.volumeKnown)
        arming.start()
}
