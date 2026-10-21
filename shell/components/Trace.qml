import QtQuick
import qs.core

// Flight-recorder style trace of a bounded history. Repaints only when
// `seq` changes while visible, so a hidden trace costs nothing.
Canvas {
    id: root
    property var values: []
    property int seq: 0
    property real min: 0
    property real max: 100
    property bool autoMax: false
    property color color: Theme.signal
    property int capacity: 120
    property real caution: NaN
    renderStrategy: Canvas.Cooperative
    renderTarget: Canvas.Image

    onSeqChanged: if (visible)
        requestPaint()
    onVisibleChanged: if (visible)
        requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        const w = width;
        const h = height;
        ctx.reset();
        ctx.clearRect(0, 0, w, h);

        // Grid: quarter lines and a vertical line every 10 samples.
        ctx.strokeStyle = Theme.alpha(Theme.grid, Theme.gridMinorOpacity);
        ctx.lineWidth = 1;
        ctx.beginPath();
        for (let i = 1; i < 4; i++) {
            const y = Math.round(h * i / 4) + 0.5;
            ctx.moveTo(0, y);
            ctx.lineTo(w, y);
        }
        const step = w / Math.max(1, root.capacity - 1);
        for (let s = root.capacity - 1; s >= 0; s -= 10) {
            const x = Math.round(s * step) + 0.5;
            ctx.moveTo(x, 0);
            ctx.lineTo(x, h);
        }
        ctx.stroke();

        const vals = root.values || [];
        let top = root.max;
        if (root.autoMax) {
            top = 1;
            for (let i = 0; i < vals.length; i++)
                if (vals[i] !== null && vals[i] > top)
                    top = vals[i];
            top *= 1.15;
        }
        const span = Math.max(1e-9, top - root.min);
        const offset = root.capacity - vals.length;

        if (!isNaN(root.caution) && !root.autoMax) {
            const cy = Math.round(h - (root.caution - root.min) / span * h) + 0.5;
            ctx.strokeStyle = Theme.alpha(Theme.caution, 0.6);
            ctx.setLineDash([3, 3]);
            ctx.beginPath();
            ctx.moveTo(0, cy);
            ctx.lineTo(w, cy);
            ctx.stroke();
            ctx.setLineDash([]);
        }

        // Line segments; gaps where a sample is unknown (null).
        ctx.strokeStyle = root.color;
        ctx.lineWidth = 1.5;
        let open = false;
        ctx.beginPath();
        for (let i = 0; i < vals.length; i++) {
            const v = vals[i];
            const x = (offset + i) * step;
            if (v === null || v === undefined || !isFinite(v)) {
                open = false;
                continue;
            }
            const y = h - Math.max(0, Math.min(1, (v - root.min) / span)) * (h - 2) - 1;
            if (!open) {
                ctx.moveTo(x, y);
                open = true;
            } else
                ctx.lineTo(x, y);
        }
        ctx.stroke();
    }
}
