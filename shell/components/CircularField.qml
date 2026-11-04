import QtQuick
import qs.core
import qs.services

// Limb's collimator. The engraving is event-painted; the workspace needle
// is a retained transform, including for legacy users of progress.
Item {
    id: field
    property var profile: Theme
    property bool instrument: false
    property real progress: 1
    readonly property int workspace: Compositor.focusedWorkspaceId

    function blend(a, b, amount) {
        return Qt.rgba(a.r + (b.r - a.r) * amount,
                       a.g + (b.g - a.g) * amount,
                       a.b + (b.b - a.b) * amount, 1);
    }

    Canvas {
        id: art
        opacity: field.profile.decorationOpacity === undefined ? 1 : field.profile.decorationOpacity
        Connections {
            target: field.profile
            function onPaletteChanged() { art.requestPaint(); }
        }
        Connections {
            target: field
            function onProfileChanged() { art.requestPaint(); }
        }
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: field
            function onWorkspaceChanged() { art.requestPaint(); }
            function onInstrumentChanged() { art.requestPaint(); }
        }
        Connections {
            target: Theme
            function onPaletteChanged() { art.requestPaint(); }
            function onScaleChanged() { art.requestPaint(); }
        }
        onPaint: {
            var c = getContext("2d");
            c.reset();
            var w = width, h = height;
            var x = w * .27, y = h * .55, r = h * .34;
            function line(x1, y1, x2, y2, color, weight) {
                c.strokeStyle = color;
                c.lineWidth = weight || 1;
                c.beginPath(); c.moveTo(x1, y1); c.lineTo(x2, y2); c.stroke();
            }
            c.fillStyle = field.blend(field.profile.bg, field.profile.surface, .65);
            c.beginPath(); c.arc(x, y, r, 0, Math.PI * 2); c.fill();
            c.fillStyle = field.blend(field.profile.bg, field.profile.surface, .18);
            c.beginPath(); c.arc(x - Theme.px(18), y - Theme.px(12), r * .91, 0, Math.PI * 2); c.fill();
            var rings = [1, 1.05, 1.17];
            for (var t = 0; t < rings.length; t++) {
                c.strokeStyle = field.blend(field.profile.bg, field.profile.grid, t === 0 ? .9 : .55);
                c.lineWidth = 1;
                c.beginPath(); c.arc(x, y, r * rings[t], -.76, 4.7); c.stroke();
            }
            for (var i = 0; i < 100; i++) {
                var a = i * Math.PI / 60 - 2;
                var len = Theme.px(i % 5 === 0 ? 13 : 5);
                var inner = r + Theme.px(20);
                line(x + Math.cos(a) * inner, y + Math.sin(a) * inner,
                     x + Math.cos(a) * (inner + len), y + Math.sin(a) * (inner + len),
                     field.blend(field.profile.grid, field.profile.textDim, i % 5 === 0 ? .3 : 0));
            }
            var registration = field.blend(field.profile.grid, field.profile.textDim, .25);
            line(x - r * .22, y, x + r * .22, y, registration);
            line(x, y - Theme.px(16), x, y + Theme.px(16), registration);
            if (field.instrument) {
                line(x + r * .7, y - r * .55, w * .71, y - r * .55, field.profile.grid);
                line(w * .71, y - r * .55, w * .74, y - r * .55 + Theme.px(32), field.profile.grid);
            }
            for (var v = 0; v < 4; v++) {
                var xx = w * (v === 0 || v === 2 ? .06 : .94), yy = h * (v < 2 ? .12 : .91);
                line(xx - 5, yy, xx + 5, yy, field.profile.grid);
                line(xx, yy - 5, xx, yy + 5, field.profile.grid);
            }
        }
    }
    Item {
        x: field.width * .27; y: field.height * .55
        width: field.height * .34; height: 0
        transformOrigin: Item.Left
        visible: field.workspace > 0
        rotation: (-1.6 + field.workspace * .24 + (field.instrument && Theme.travel ? (1 - field.progress) * .4 : 0)) * 180 / Math.PI
        Behavior on rotation { enabled: Theme.travel; RotationAnimator { id: needle; duration: Theme.normal; easing.type: Easing.OutCubic } }
        Connections {
            target: Theme
            function onTravelChanged() { if (!Theme.travel) needle.complete(); }
        }
        Rectangle { x: parent.width - Theme.px(8); y: -height / 2; width: Theme.px(46); height: Theme.px(3); color: field.profile.signal }
    }
}
