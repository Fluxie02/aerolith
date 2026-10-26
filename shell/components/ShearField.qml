import QtQuick
import qs.core
import qs.services

// An exploded airframe. Native faces retain the engraving and fallback;
// the bounded material pass supplies shallow relief beneath those marks.
// The leading-edge
// tension strip breathes through a retained opacity animator.
Item {
    id: shear
    property bool instrument: false
    readonly property real assembly: instrument ? 1 : Theme.bootProgress
    readonly property int workspace: Compositor.focusedWorkspaceId
    readonly property real station: workspace > 0 ? (workspace - 1) % 9 : 0
    readonly property real route: Theme.travel ? station : 0
    readonly property bool exposed: visible && Window.window && Window.window.visible
    readonly property bool breathing: Theme.ambient && exposed && (instrument || !Ui.deckOpen) && assembly >= 1
    signal stroke()
    signal focusStroke()
    signal settleFocus()
    function breathe() { if (breathing) stroke(); }

    function focusImpulse() {
        if (!exposed || !Theme.ambient || !Theme.travel || assembly < 1) return;
        focusStroke();
    }
    Connections {
        target: Compositor
        function onActiveToplevelChanged() { shear.focusImpulse(); }
    }
    Connections {
        target: Theme
        function onAnimateChanged() {
            if (!Theme.animate) shear.settleFocus();
        }
        function onAmbientChanged() {
            if (!Theme.ambient) shear.settleFocus();
        }
        function onTravelChanged() {
            if (!Theme.travel) shear.settleFocus();
        }
    }
    onExposedChanged: if (!exposed) settleFocus()

    Repeater {
        model: Theme.insane ? 5 : 3
        delegate: Item {
            id: blade
            required property int index
            readonly property real open: Math.max(0, Math.min(1, (shear.assembly - index * .075) / .62))
            x: shear.width * (.405 + index * .024) + (Theme.travel ? (1 - open) * Theme.du(140 + index * 18) : 0)
            readonly property real restY: shear.height * (.18 + index * .038)
            y: restY
            width: shear.width * .135; height: shear.height * .52
            rotation: -24 + (Theme.insane ? index * 2.2 : index * 1.4) + shear.route * (index % 2 ? -.34 : .34)
            scale: shear.instrument ? .84 : 1
            transformOrigin: Item.Center
            opacity: open
            z: 8 - index
            Behavior on rotation { enabled: Theme.travel && Theme.ambient && shear.exposed; RotationAnimator { id: bladeMotion; duration: Theme.slow * 2; easing.type: Easing.OutCubic } }
            SequentialAnimation {
                id: focusTravel
                // No explicit from: a second focus continues at the current
                // visible position instead of injecting a fresh displacement.
                YAnimator { target: blade; to: blade.restY + Theme.du(blade.index % 2 ? -10 : 9); duration: Theme.fast; easing.type: Easing.OutCubic }
                YAnimator { target: blade; to: blade.restY; duration: Theme.slow * 2; easing.type: Easing.OutCubic }
            }
            Connections {
                target: shear
                function onExposedChanged() { if (!shear.exposed) bladeMotion.complete(); }
                function onFocusStroke() { focusTravel.restart(); }
                function onSettleFocus() { focusTravel.stop(); blade.y = Qt.binding(function() { return blade.restY; }); }
            }
            Connections {
                target: Theme
                function onTravelChanged() { if (!Theme.travel) bladeMotion.complete(); }
                function onAmbientChanged() { if (!Theme.ambient) bladeMotion.complete(); }
            }
            Material {
                id: mineral
                anchors.fill: parent
                shader: "bevel"
                parameters: Qt.vector4d(blade.index, 0, 0, 0)
                onActiveChanged: plate.requestPaint()
            }
            Canvas {
                id: plate
                anchors.fill: parent
                renderTarget: Canvas.Image
                onAvailableChanged: if (available) requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onVisibleChanged: if (visible) requestPaint()
                Connections {
                    target: Theme
                    function onPaletteChanged() { plate.requestPaint(); }
                    function onInsaneChanged() { plate.requestPaint(); }
                    function onMonoChanged() { plate.requestPaint(); }
                    function onFontXsChanged() { plate.requestPaint(); }
                    function onUnitChanged() { plate.requestPaint(); }
                }
                Connections {
                    target: plate.Window.window
                    function onVisibleChanged() { if (plate.Window.window.visible) plate.requestPaint(); }
                }
                onPaint: {
                    var c = getContext('2d'); c.reset();
                    var w=width,h=height,i=blade.index;
                    function face(points, fill, stroke) {
                        c.beginPath(); c.moveTo(points[0][0]*w,points[0][1]*h);
                        for(var k=1;k<points.length;k++)c.lineTo(points[k][0]*w,points[k][1]*h);
                        c.closePath();
                        if (!mineral.active) { c.fillStyle=fill;c.fill(); }
                        if(stroke){c.strokeStyle=stroke;c.lineWidth=1;c.stroke();}
                    }
                    // Opposing bevels make thickness visible without a shadow.
                    face([[.08,.08],[.62,.01],[.97,.82],[.75,.99],[.25,.85]],Theme.bg,Theme.grid);
                    face([[.08,.08],[.25,.02],[.79,.82],[.75,.99],[.25,.85]],Theme.surface2,Theme.grid);
                    face([[.25,.02],[.62,.01],[.97,.82],[.79,.82]],Theme.surface,Theme.grid);
                    face([[.79,.82],[.97,.82],[.75,.99]],Theme.bg,Theme.grid);
                    c.strokeStyle=Theme.grid;c.lineWidth=1;
                    for(var j=0;j<(Theme.insane?25:16);j++) {
                        var t=j/(Theme.insane?25:16), yy=.10+t*.65;
                        var xx=.28+t*.43;
                        c.beginPath();c.moveTo(xx*w,yy*h);c.lineTo((xx+.26)*w,(yy-.012)*h);c.stroke();
                    }
                    if(i===0) {
                        // Inscriptions stay native, above either material.
                        c.beginPath(); c.moveTo(.25*w,.02*h); c.lineTo(.29*w,.019*h);
                        c.lineTo(.83*w,.82*h); c.lineTo(.79*w,.82*h); c.closePath();
                        c.fillStyle=Theme.signal; c.fill();
                        c.beginPath(); c.moveTo(.08*w,.08*h); c.lineTo(.14*w,.06*h);
                        c.lineTo(.31*w,.85*h); c.lineTo(.25*w,.85*h); c.closePath();
                        c.fillStyle=Theme.grid; c.fill();
                        c.fillStyle=Theme.textDim;c.font=Theme.fontXs+'px "'+Theme.mono+'"';
                        c.save();c.translate(w*.43,h*.29);c.rotate(1.03);
                        c.fillText('AEROLITH / WORKSPACE STRUCTURE',0,0);c.restore();
                    }
                }
            }
            Rectangle {
                id: tension
                x: parent.width * .27; y: parent.height * .10
                width: Theme.du(3); height: parent.height * (Theme.insane ? .34 : .24)
                rotation: -17; transformOrigin: Item.TopLeft
                color: Theme.appLink; opacity: .42
                visible: blade.index === 0
                SequentialAnimation {
                    id: respiration
                    property real peak: .42
                    property int strokeMs: 0
                    OpacityAnimator { target: tension; from: .42; to: respiration.peak; duration: respiration.strokeMs; easing.type: Easing.InOutSine }
                    OpacityAnimator { target: tension; from: respiration.peak; to: .42; duration: respiration.strokeMs; easing.type: Easing.InOutSine }
                }
                Connections {
                    target: shear
                    function onStroke() {
                        if (!shear.breathing || blade.index !== 0 || respiration.running) return;
                        respiration.peak = Theme.ambientReduced ? .49 : .88;
                        respiration.strokeMs = Theme.carrierDuration;
                        respiration.start();
                    }
                    function onBreathingChanged() { if (!shear.breathing) { respiration.stop(); tension.opacity = .42; } }
                }
                Connections {
                    target: Theme
                    function onAmbientReducedChanged() { respiration.stop(); tension.opacity = .42; }
                }
            }
            // Focus is a short strain along the leading edge, not a pulse loop.
            Rectangle {
                id: focusMark
                x: parent.width * .28; y: parent.height * .08
                width: Theme.du(3); height: parent.height * .42
                rotation: -17; transformOrigin: Item.TopLeft
                color: Theme.signal
                visible: blade.index === 0 && !Theme.lowEffects
                opacity: 0
                SequentialAnimation {
                    id: focusFlash
                    OpacityAnimator { target: focusMark; to: 1; duration: Theme.fast; easing.type: Easing.OutCubic }
                    OpacityAnimator { target: focusMark; to: 0; duration: Theme.slow * 2; easing.type: Easing.OutCubic }
                }
                Connections {
                    target: shear
                    function onFocusStroke() { if (blade.index === 0) focusFlash.restart(); }
                    function onSettleFocus() { focusFlash.stop(); focusMark.opacity = 0; }
                }
            }
        }
    }
}
