import QtQuick
import qs.core
Item {
    id: frame
    required property var s
    property real progress: 1
    property bool active: true
    property bool outer: false
    Canvas {
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var c=getContext('2d'); c.reset(); var w=width,h=height;
            c.fillStyle=frame.s.alpha(frame.s.surface, frame.s.keel ? 0.91 : 0.86);
            c.beginPath(); c.moveTo(0,0);
            if(frame.outer && frame.s.keel) {
                c.lineTo(w*.7,0);c.lineTo(w*.7,56);c.lineTo(w-40,56);c.lineTo(w,96);
                c.lineTo(w,h-130);c.lineTo(w*.72,h-130);c.lineTo(w*.72,h);c.lineTo(0,h);
            } else if(frame.outer && frame.s.fault) {
                c.lineTo(w*.69-46,0);c.lineTo(w*.69,46);c.lineTo(w*.69,h-46);c.lineTo(w*.69-46,h);c.lineTo(46,h);c.lineTo(0,h-46);
            } else {
                c.lineTo(w-(frame.s.fault?46:20),0); c.lineTo(w,frame.s.fault?46:20);
                c.lineTo(w,h); c.lineTo(frame.s.fault?46:0,h); c.lineTo(0,h-(frame.s.fault?46:0));
            }
            c.closePath(); c.fill();
            c.strokeStyle=frame.s.line; c.lineWidth=1; c.stroke();
            c.strokeStyle=frame.active?frame.s.accent:frame.s.line;c.lineWidth=2;
            c.beginPath();c.moveTo(0,28);c.lineTo(0,0);c.lineTo(54,0);
            c.moveTo(w,h-28);c.lineTo(w,h);c.lineTo(w-54,h);c.stroke();
            c.strokeStyle=frame.s.line;c.lineWidth=1;c.beginPath();
            for(var i=72;i<w-36;i+=12) { c.moveTo(i,0);c.lineTo(i,i%60===0?8:4); } c.stroke();
        }
    }
    Rectangle { visible: s.keel; x: -s.px(12); y: s.px(40); width: 2; height: Math.max(0,parent.height-s.px(80)); color: s.line }
}
