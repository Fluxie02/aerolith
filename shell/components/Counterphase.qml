import QtQuick
import qs.core
import qs.services

// COUNTERPHASE: opposed escapements, not synthetic telemetry. The bearings
// express that the workspace is live; app-link colour and workspace direction
// come from real compositor state. Only small retained marks move. The large
// instrument and all typography stay registered to the desktop.
Item {
    id: machine
    property bool instrument: false
    readonly property bool exposed: visible && Window.window && Window.window.visible
    readonly property bool driving: Theme.ambient && exposed && (instrument || !Ui.deckOpen) && Theme.bootProgress >= 1
    readonly property real stroke: Theme.ambientReduced ? Theme.du(3) : Theme.du(Theme.insane ? 120 : 80)
    readonly property int direction: Compositor.focusedWorkspaceId % 2 === 0 ? -1 : 1
    signal beat()
    // A single low-frequency escapement starts finite all-Animator groups.
    // Pauses inside an Animation group would move it off the render thread.
    Timer {
        id: escapement
        interval: Theme.carrierDuration * 2 + Theme.carrierRest
        running: machine.driving; repeat: true; triggeredOnStart: true
        onTriggered: machine.beat()
    }
    function beginCadence() {
        // Recheck after construction: the Timer's first beat can precede its
        // delegate Connections. Their running guard makes this catch-up beat
        // harmless if a finite stroke has already started.
        if (!machine.driving) return;
        if (!escapement.running) escapement.start();
        else machine.beat();
    }
    Component.onCompleted: Qt.callLater(machine.beginCadence)

    // A pair of opposed linear bearings continues the fixed command datum.
    // Both are bounded within the same track even when motion is disabled.
    Repeater {
        model: Theme.insane ? 3 : 2
        delegate: Item {
            id: bearing
            required property int index
            x: machine.width * (index === 0 ? .055 : index === 1 ? .72 : .49)
            y: machine.height * (index === 0 ? .22 : index === 1 ? .79 : .105)
            width: machine.width * (index === 2 ? .12 : .16)
            height: Theme.du(11)
            opacity: machine.instrument ? .55 : 1
            Rectangle { width: parent.width; height: Theme.du(2); color: Theme.grid }
            Rectangle { width: Theme.du(3); height: parent.height; color: Theme.textDim }
            Rectangle { x: parent.width - width; width: Theme.du(3); height: parent.height; color: Theme.textDim }
            Rectangle {
                id: carrier
                x: bearing.width * .42; y: -Theme.du(2)
                width: Theme.du(bearing.index === 2 ? 24 : 42); height: Theme.du(5)
                color: bearing.index === 1 ? Theme.appLink : Theme.signal
                Material {
                    anchors.fill: parent
                    shader: "catch"
                    accent: carrier.color
                    visible: Theme.ambient
                }
                // Animator changes the scene-graph transform, not layout.
                SequentialAnimation {
                    id: cycle
                    property real home: 0
                    property real tip: 0
                    property int strokeMs: 0
                    XAnimator {
                        target: carrier
                        from: cycle.home
                        to: cycle.tip
                        duration: cycle.strokeMs
                        easing.type: Easing.InOutSine
                    }
                    XAnimator {
                        target: carrier
                        from: cycle.tip
                        to: cycle.home
                        duration: cycle.strokeMs
                        easing.type: Easing.InOutSine
                    }
                }
                Connections {
                    target: machine
                    function onBeat() {
                        if (!machine.driving || cycle.running) return;
                        cycle.home = bearing.width * .42;
                        cycle.tip = cycle.home + Math.min(machine.stroke, bearing.width * .30) * (bearing.index % 2 ? -machine.direction : machine.direction);
                        cycle.strokeMs = Theme.carrierDuration;
                        cycle.start();
                    }
                    function onDrivingChanged() { if (!machine.driving) { cycle.stop(); carrier.x = Qt.binding(function() { return bearing.width * .42; }); } }
                }
                Connections {
                    target: Theme
                    // Reduced motion cancels a full-travel stroke at once.
                    function onAmbientReducedChanged() { cycle.stop(); carrier.x = Qt.binding(function() { return bearing.width * .42; }); }
                }
            }
        }
    }

    // The right-hand vernier is the return path of the application bearing.
    // Its slow, short travel in reduced mode never becomes a scanning wipe.
    Item {
        id: vernier
        x: machine.width * .968; y: machine.height * .38
        width: Theme.du(9); height: machine.height * .37
        Rectangle { width: Theme.du(2); height: parent.height; color: Theme.grid }
        Repeater {
            model: 7
            delegate: Rectangle {
                required property int index
                y: index * vernier.height / 6
                x: -Theme.du(3); width: Theme.du(index % 3 === 0 ? 12 : 7); height: Theme.du(2)
                color: Theme.textDim
            }
        }
        Rectangle {
            id: returnMark
            y: vernier.height * .44; x: -Theme.du(3)
            width: Theme.du(8); height: Theme.du(24)
            color: Theme.appLink
            Material {
                anchors.fill: parent
                shader: "catch"
                parameters: Qt.vector4d(1, 0, 0, 0)
                visible: Theme.ambient
            }
            SequentialAnimation {
                id: returnCycle
                property real home: 0
                property real tip: 0
                property int strokeMs: 0
                YAnimator { target: returnMark; from: returnCycle.home; to: returnCycle.tip; duration: returnCycle.strokeMs; easing.type: Easing.InOutSine }
                YAnimator { target: returnMark; from: returnCycle.tip; to: returnCycle.home; duration: returnCycle.strokeMs; easing.type: Easing.InOutSine }
            }
            Connections {
                target: machine
                function onBeat() {
                    if (!machine.driving || !Theme.insane || returnCycle.running) return;
                    returnCycle.home = vernier.height * .44;
                    returnCycle.tip = returnCycle.home + machine.stroke * .5;
                    returnCycle.strokeMs = Theme.carrierDuration;
                    returnCycle.start();
                }
                function onDrivingChanged() { if (!machine.driving) { returnCycle.stop(); returnMark.y = Qt.binding(function() { return vernier.height * .44; }); } }
            }
            Connections {
                target: Theme
                function onInsaneChanged() {
                    if (!Theme.insane) { returnCycle.stop(); returnMark.y = Qt.binding(function() { return vernier.height * .44; }); }
                }
                function onAmbientReducedChanged() { returnCycle.stop(); returnMark.y = Qt.binding(function() { return vernier.height * .44; }); }
            }
        }
    }
}
