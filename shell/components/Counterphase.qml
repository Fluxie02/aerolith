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
    Connections {
        target: Theme
        function onAmbientReducedChanged() { if (machine.driving) Qt.callLater(function() { escapement.restart(); }); }
        function onUnitChanged() { if (machine.driving) Qt.callLater(function() { escapement.restart(); }); }
        function onInsaneChanged() { if (machine.driving) Qt.callLater(function() { escapement.restart(); }); }
    }
    onDirectionChanged: if (driving) Qt.callLater(function() { escapement.restart(); })
    Component.onCompleted: if (driving) Qt.callLater(function() { escapement.restart(); })

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
                // Animator changes the scene-graph transform, not layout.
                SequentialAnimation {
                    id: cycle
                    XAnimator {
                        target: carrier
                        from: bearing.width * .42
                        to: bearing.width * .42 + Math.min(machine.stroke, bearing.width * .30) * (bearing.index % 2 ? -machine.direction : machine.direction)
                        duration: Theme.carrierDuration
                        easing.type: Easing.InOutSine
                    }
                    XAnimator {
                        target: carrier
                        from: bearing.width * .42 + Math.min(machine.stroke, bearing.width * .30) * (bearing.index % 2 ? -machine.direction : machine.direction)
                        to: bearing.width * .42
                        duration: Theme.carrierDuration
                        easing.type: Easing.InOutSine
                    }
                }
                Connections {
                    target: machine
                    function onBeat() { if (machine.driving) cycle.restart(); }
                    function onDrivingChanged() { if (!machine.driving) { cycle.stop(); carrier.x = Qt.binding(function() { return bearing.width * .42; }); } }
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
            SequentialAnimation {
                id: returnCycle
                YAnimator { target: returnMark; from: vernier.height * .44; to: vernier.height * .44 + machine.stroke * .5; duration: Theme.carrierDuration; easing.type: Easing.InOutSine }
                YAnimator { target: returnMark; from: vernier.height * .44 + machine.stroke * .5; to: vernier.height * .44; duration: Theme.carrierDuration; easing.type: Easing.InOutSine }
            }
            Connections {
                target: machine
                function onBeat() { if (machine.driving && Theme.insane) returnCycle.restart(); }
                function onDrivingChanged() { if (!machine.driving) { returnCycle.stop(); returnMark.y = Qt.binding(function() { return vernier.height * .44; }); } }
            }
        }
    }
}
