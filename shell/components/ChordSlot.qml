import QtQuick
import qs.core

// A retained bay is a rigid machine plane: it docks against the datum, then
// becomes completely still. The host owns focus, demand and its lifetime.
Item {
    id: chord
    required property var slot
    readonly property bool wide: slot.bay !== "command" && slot.bay !== "ai"
    readonly property bool compactScreen: parent.width < Theme.du(1500) || parent.height < Theme.du(850)
    readonly property real leftOrigin: compactScreen ? parent.width * .045 : parent.width * (wide ? .12 : .37)
    readonly property real topOrigin: compactScreen ? Math.max(Theme.stripHeight + Theme.du(78), parent.height * .14) : parent.height * .22
    // Progress is a presentation target kept for DeckView's compatibility.
    // No JavaScript binding fans a per-frame scalar out across this plane.
    property bool presented: false
    property int presentationGeneration: 0
    property bool entrySyncArmed: false
    property bool dockQueued: false
    readonly property real progress: presented && slot.current ? 1 : 0

    x: leftOrigin + (Theme.travel ? !presented ? Theme.du(compactScreen ? 14 : 34) : slot.current ? 0 : -Theme.du(24) : 0)
    y: topOrigin + (Theme.travel ? !presented ? -Theme.du(12) : slot.current ? 0 : Theme.du(16) : 0)
    width: parent.width - leftOrigin - parent.width * (compactScreen ? .045 : .08)
    height: Math.max(0, parent.height - topOrigin - (compactScreen ? Theme.du(28) : Theme.du(130)) - (Config.strip.edge === "bottom" ? Theme.stripHeight : 0))
    // Incoming text is present immediately. The outgoing plane alone fades
    // away; no input, load or service action waits for the docking stroke.
    opacity: !Theme.animate ? (slot.current ? 1 : 0) : !presented ? .84 : slot.current ? 1 : 0
    scale: Theme.travel && (!presented || !slot.current) ? .988 : 1
    rotation: Theme.travel && !compactScreen ? !presented ? -.55 : slot.current ? 0 : .4 : 0
    transformOrigin: Item.TopLeft
    z: slot.current ? 2 : 1
    visible: slot.bay !== ""
    Behavior on x { enabled: chord.presented && Theme.travel; XAnimator { id: dockX; duration: Theme.normal; easing.type: Easing.OutCubic } }
    Behavior on y { enabled: chord.presented && Theme.travel; YAnimator { id: dockY; duration: Theme.normal; easing.type: Easing.OutCubic } }
    Behavior on scale { enabled: chord.presented && Theme.travel; ScaleAnimator { id: dockScale; duration: Theme.normal; easing.type: Easing.OutCubic } }
    Behavior on rotation { enabled: chord.presented && Theme.travel; RotationAnimator { id: dockRotation; duration: Theme.normal; easing.type: Easing.OutCubic } }
    Behavior on opacity { enabled: chord.presented && Theme.animate; OpacityAnimator { id: dockOpacity; duration: Theme.normal; easing.type: Easing.OutCubic } }

    // A solid offset undercarriage carries depth on the software renderer.
    // The bay itself remains an ordinary, rectangular functional surface.
    Canvas {
        id: carriage
        x: -Theme.du(12); y: -Theme.du(12)
        width: chord.width + Theme.du(36)
        height: chord.height + Theme.du(32)
        z: -3
        visible: chord.slot.bay !== "" && !Theme.lowEffects
        renderTarget: Canvas.Image
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        onAvailableChanged: if (available) requestPaint()
        onPaint: {
            var c = getContext("2d"); c.reset();
            var u = Theme.du(12), w = width, h = height;
            c.beginPath();
            c.moveTo(u * 3, u); c.lineTo(w - u * 3, u);
            c.lineTo(w - 1, u * 4); c.lineTo(w - 1, h - u * 2);
            c.lineTo(w - u * 3, h - 1); c.lineTo(u * 2, h - 1);
            c.lineTo(1, h - u * 3); c.lineTo(1, u * 3); c.closePath();
            c.fillStyle = Theme.surface2; c.fill();
            c.strokeStyle = Theme.grid; c.lineWidth = Theme.border; c.stroke();
            // Finite index comb: machining marks, never a frame callback.
            c.strokeStyle = Theme.textDim; c.beginPath();
            for (var i = 0; i < (Theme.insane ? 12 : 7); i++) {
                var px = w - Theme.du(30 + i * 7);
                c.moveTo(px, h - Theme.du(6));
                c.lineTo(px + Theme.du(3), h - Theme.du(i % 3 === 0 ? 13 : 10));
            }
            c.stroke();
        }
        Connections {
            target: Theme
            function onPaletteChanged() { carriage.requestPaint(); }
            function onInsaneChanged() { carriage.requestPaint(); }
            function onUnitChanged() { carriage.requestPaint(); }
        }
        Connections {
            target: carriage.Window.window
            function onVisibleChanged() { if (carriage.Window.window.visible) carriage.requestPaint(); }
        }
    }
    Rectangle {
        z: -2
        x: -Theme.du(8); y: Theme.du(24)
        width: Theme.du(3); height: Math.min(chord.height * .36, Theme.du(112))
        color: Theme.signal
        visible: chord.slot.bay !== "" && !chord.compactScreen && !Theme.lowEffects
    }

    // The whole chord, including its header, shields backdrop clicks.
    MouseArea { anchors.fill: parent; z: -1 }

    function settleTravel() {
        dockX.complete(); dockY.complete(); dockScale.complete(); dockRotation.complete();
    }
    function queueDock() {
        if (!entrySyncArmed || dockQueued) return;
        dockQueued = true;
        const generation = presentationGeneration;
        Qt.callLater(function() {
            // Release/reuse can happen before a queued render callback runs.
            if (generation !== chord.presentationGeneration) return;
            chord.dockQueued = false;
            if (chord.slot.bay !== "") chord.presented = true;
        });
    }

    Connections {
        target: chord.slot
        // A new host incarnation starts at its entry pose. Interrupting a
        // live incarnation only retargets Behaviors from their current pose.
        function onBayChanged() {
            chord.presentationGeneration++;
            chord.presented = false;
            chord.entrySyncArmed = false;
            chord.dockQueued = false;
        }
    }
    // A cold Animator reads its scene-graph transform, which does not exist
    // until the entry pose has been synced. Wait for that first render,
    // rather than using a guessed delay. These handlers disconnect as soon
    // as docking starts; they do not perform ongoing per-frame work.
    Connections {
        target: chord.Window.window
        enabled: chord.visible && !chord.presented
        function onAfterAnimating() { chord.entrySyncArmed = true; }
        function onFrameSwapped() { chord.queueDock(); }
    }
    Connections {
        target: Theme
        function onAnimateChanged() {
            if (!Theme.animate) {
                chord.settleTravel(); dockOpacity.complete();
            }
        }
        function onTravelChanged() { if (!Theme.travel) chord.settleTravel(); }
    }
}
