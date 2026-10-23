import QtQuick
import qs.core
import qs.services

// An exploded airframe. Each face is cached CPU geometry; only the retained
// items move when a real workspace or focus changes. There is no idle clock.
Item {
    id: shear
    property bool instrument: false
    readonly property real assembly: instrument ? 1 : Theme.bootProgress
    readonly property int workspace: Compositor.focusedWorkspaceId
    readonly property real station: workspace > 0 ? (workspace - 1) % 9 : 0
    readonly property real route: Theme.travel ? station : 0
    property real recoil: 0
    readonly property bool exposed: visible && Window.window && Window.window.visible

    function focusImpulse() {
        if (!exposed || !Theme.animate || assembly < 1) return;
        impulse.stop(); recoil = 1; impulse.restart();
    }
    Connections {
        target: Compositor
        function onActiveToplevelChanged() { shear.focusImpulse(); }
    }
    Connections {
        target: Theme
        function onAnimateChanged() {
            if (!Theme.animate) { impulse.stop(); shear.recoil = 0; }
        }
    }
    onExposedChanged: if (!exposed) { impulse.stop(); recoil = 0; }
    NumberAnimation {
        id: impulse; target: shear; property: "recoil"; to: 0
        duration: Theme.slow * 2; easing.type: Easing.OutCubic
    }

    Repeater {
        model: Theme.insane ? 5 : 3
        delegate: Item {
            id: blade
            required property int index
            readonly property real open: Math.max(0, Math.min(1, (shear.assembly - index * .075) / .62))
            x: shear.width * (.405 + index * .024) + (Theme.travel ? (1 - open) * Theme.du(140 + index * 18) : 0)
            y: shear.height * (.18 + index * .038) + (Theme.travel ? shear.recoil * Theme.du(index % 2 ? -10 : 9) : 0)
            width: shear.width * .135; height: shear.height * .52
            rotation: -24 + (Theme.insane ? index * 2.2 : index * 1.4) + shear.route * (index % 2 ? -.34 : .34)
            scale: shear.instrument ? .84 : 1
            transformOrigin: Item.Center
            opacity: open
            z: 8 - index
            Behavior on rotation { enabled: Theme.travel && shear.exposed; NumberAnimation { id: bladeMotion; duration: Theme.slow * 2; easing.type: Easing.OutCubic } }
            Connections {
                target: shear
                function onExposedChanged() { if (!shear.exposed) bladeMotion.complete(); }
            }
            Connections {
                target: Theme
                function onTravelChanged() { if (!Theme.travel) bladeMotion.complete(); }
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
                        c.closePath();c.fillStyle=fill;c.fill();
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
                        face([[.25,.02],[.29,.019],[.83,.82],[.79,.82]],Theme.signal,null);
                        face([[.08,.08],[.14,.06],[.31,.85],[.25,.85]],Theme.grid,null);
                        c.fillStyle=Theme.textDim;c.font=Theme.fontXs+'px "'+Theme.mono+'"';
                        c.save();c.translate(w*.43,h*.29);c.rotate(1.03);
                        c.fillText('AEROLITH / WORKSPACE STRUCTURE',0,0);c.restore();
                    }
                }
            }
            // Focus is a short strain along the leading edge, not a pulse loop.
            Rectangle {
                x: parent.width * .28; y: parent.height * .08
                width: Theme.du(3); height: parent.height * .42
                rotation: -17; transformOrigin: Item.TopLeft
                color: Theme.signal
                visible: blade.index === 0 && shear.recoil > .01 && !Theme.lowEffects
                opacity: shear.recoil
            }
        }
    }
}
