import QtQuick
import qs.core
import qs.services

// Limb's collimator. Static between workspace, palette and layout changes;
// only the Deck's bounded opening transition supplies changing progress.
Item {
    id: field
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
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections {
            target: field
            function onWorkspaceChanged() { art.requestPaint(); }
            function onInstrumentChanged() { art.requestPaint(); }
            function onProgressChanged() { if (field.instrument) art.requestPaint(); }
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
            c.fillStyle = field.blend(Theme.bg, Theme.surface, .65);
            c.beginPath(); c.arc(x, y, r, 0, Math.PI * 2); c.fill();
            c.fillStyle = field.blend(Theme.bg, Theme.surface, .18);
            c.beginPath(); c.arc(x - Theme.px(18), y - Theme.px(12), r * .91, 0, Math.PI * 2); c.fill();
            var rings = [1, 1.05, 1.17];
            for (var t = 0; t < rings.length; t++) {
                c.strokeStyle = field.blend(Theme.bg, Theme.grid, t === 0 ? .9 : .55);
                c.lineWidth = 1;
                c.beginPath(); c.arc(x, y, r * rings[t], -.76, 4.7); c.stroke();
            }
            for (var i = 0; i < 100; i++) {
                var a = i * Math.PI / 60 - 2;
                var len = Theme.px(i % 5 === 0 ? 13 : 5);
                var inner = r + Theme.px(20);
                line(x + Math.cos(a) * inner, y + Math.sin(a) * inner,
                     x + Math.cos(a) * (inner + len), y + Math.sin(a) * (inner + len),
                     field.blend(Theme.grid, Theme.textDim, i % 5 === 0 ? .3 : 0));
            }
            // An unavailable workspace has no marker, rather than claiming WS 1.
            if (field.workspace > 0) {
                var angle = -1.6 + field.workspace * .24 + (field.instrument && Theme.travel ? (1 - field.progress) * .4 : 0);
                line(x + Math.cos(angle) * (r - Theme.px(8)), y + Math.sin(angle) * (r - Theme.px(8)),
                     x + Math.cos(angle) * (r + Theme.px(38)), y + Math.sin(angle) * (r + Theme.px(38)), Theme.signal, Theme.px(3));
            }
            var registration = field.blend(Theme.grid, Theme.textDim, .25);
            line(x - r * .22, y, x + r * .22, y, registration);
            line(x, y - Theme.px(16), x, y + Theme.px(16), registration);
            if (field.instrument) {
                line(x + r * .7, y - r * .55, w * .71, y - r * .55, Theme.grid);
                line(w * .71, y - r * .55, w * .74, y - r * .55 + Theme.px(32), Theme.grid);
            }
            for (var v = 0; v < 4; v++) {
                var xx = w * (v === 0 || v === 2 ? .06 : .94), yy = h * (v < 2 ? .12 : .91);
                line(xx - 5, yy, xx + 5, yy, Theme.grid);
                line(xx, yy - 5, xx, yy + 5, Theme.grid);
            }
        }
    }
}
