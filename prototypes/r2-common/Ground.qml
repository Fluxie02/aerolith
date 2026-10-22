import QtQuick
import qs.core
import qs.services
Item {
    id: ground
    required property var s
    property bool instrument: false
    property real progress: 1
    property string bay: Ui.activeBay
    readonly property int workspace: Compositor.focusedWorkspaceId
    Canvas {
        id: art
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: ground; function onWorkspaceChanged() { art.requestPaint(); } function onBayChanged() { art.requestPaint(); } function onProgressChanged() { if(ground.instrument) art.requestPaint(); } }
        onPaint: {
            var c=getContext('2d');c.reset();var w=width,h=height,s=ground.s;
            function line(x,y,a,b,color,weight) {c.strokeStyle=color;c.lineWidth=weight||1;c.beginPath();c.moveTo(x,y);c.lineTo(a,b);c.stroke();}
            function poly(points,fill) {c.fillStyle=fill;c.beginPath();c.moveTo(points[0][0],points[0][1]);for(var i=1;i<points.length;i++)c.lineTo(points[i][0],points[i][1]);c.closePath();c.fill();}
            if(s.keel) {
                poly([[w*.54,h*.07],[w*.86,h*.07],[w*.68,h],[w*.36,h]], '#101c26');
                poly([[w*.86,h*.07],[w*.91,h*.07],[w*.73,h],[w*.68,h]], '#162631');
                line(w*.54,h*.07,w*.36,h,'#2a3d4b');line(w*.86,h*.07,w*.68,h,'#314553');
                for(var k=0;k<13;k++){var yy=h*.62+k*18;line(0,yy,w*.38-k*4,yy,'#17232c');}
                line(w*.12,h*.14,w*.12,h*.87,s.line);
                for(var j=0;j<41;j++)line(w*.12-(j%5===0?12:5),h*.14+j*h*.018,w*.12,h*.14+j*h*.018,'#40505b');
                line(w*.12,h*.14+(Math.max(1,ground.workspace)-1)*h*.09,w*.12+32,h*.14+(Math.max(1,ground.workspace)-1)*h*.09,s.accent,2);
                if(ground.instrument) {line(w*.12,h*.22,w*.19,h*.22,s.accent);line(w*.19,h*.22,w*.19,h*.31,s.accent);}
            } else if(s.limb) {
                var x=w*.27,y=h*.55,r=h*.34;
                c.fillStyle='#142123';c.beginPath();c.arc(x,y,r,0,Math.PI*2);c.fill();
                c.fillStyle='#0d171b';c.beginPath();c.arc(x-18,y-12,r*.91,0,Math.PI*2);c.fill();
                var rings=[1,1.05,1.17];
                for(var t=0;t<rings.length;t++){c.strokeStyle=t===0?'#34484b':'#253538';c.lineWidth=1;c.beginPath();c.arc(x,y,r*rings[t],-.76,4.7);c.stroke();}
                for(var i=0;i<100;i++){var a=i*Math.PI/60-2.0;var len=i%5===0?13:5;line(x+Math.cos(a)*(r+20),y+Math.sin(a)*(r+20),x+Math.cos(a)*(r+20+len),y+Math.sin(a)*(r+20+len),i%5===0?'#59716e':'#314745');}
                var a=-1.6+Math.max(1,ground.workspace)*.24 + (ground.instrument?(1-ground.progress)*.4:0);
                line(x+Math.cos(a)*(r-8),y+Math.sin(a)*(r-8),x+Math.cos(a)*(r+38),y+Math.sin(a)*(r+38),s.accent,3);
                line(x-r*.22,y,x+r*.22,y,'#536b68');line(x,y-16,x,y+16,'#536b68');
                if(ground.instrument){line(x+r*.7,y-r*.55,w*.71,y-r*.55,s.line);line(w*.71,y-r*.55,w*.74,y-r*.55+32,s.line);}
            } else {
                poly([[w*.43,0],[w*.67,0],[w*.67,h*.79],[w*.43,h]], '#1c1e23');
                poly([[w*.68,h*.13],[w*.89,h*.13],[w*.89,h],[w*.68,h]], '#25252a');
                poly([[w*.67,h*.11],[w*.68,h*.13],[w*.68,h],[w*.67,h*.79]], '#090b0f');
                line(w*.43,0,w*.43,h,'#48434a');line(w*.68,h*.13,w*.89,h*.13,'#60554f');
                for(var i=0;i<34;i++){var yy=h*.23+i*15;line(w*.67-12,yy,w*.67-(i%5===0?38:22),yy,'#5b5457');}
                line(w*.67-42,h*(.23+Math.max(1,ground.workspace)*.045),w*.67,h*(.23+Math.max(1,ground.workspace)*.045),s.accent,3);
                line(w*.07,h*.81,w*.43,h*.81,'#453e40');
            }
            // Sparse registration crosses describe the drawing plane, not invented telemetry.
            for(var v=0;v<4;v++){var xx=w*(v===0||v===2?.06:.94), yy=h*(v<2?.12:.91);line(xx-5,yy,xx+5,yy,s.line);line(xx,yy-5,xx,yy+5,s.line);}
        }
    }
    Column {
        visible: !ground.instrument && !Ui.deckOpen
        x: parent.width*(s.keel?.16:s.limb?.55:.09); y: parent.height*(s.keel?.74:s.limb?.67:.65)
        spacing: s.px(12)
        Ink { s: ground.s; text: "A E R O L I T H"; font.pixelSize: s.px(16); font.weight: Font.DemiBold; color: s.dim }
        Ink { s: ground.s; text: "WS " + (ground.workspace>0?ground.workspace:"N/A") + "  /  " + (Compositor.activeClass || "NO FOCUSED APPLICATION").toUpperCase(); color: s.dim; font.pixelSize: s.px(11) }
        Row { spacing: s.px(20)
            Repeater { model: [{t:"⌘ COMMAND",b:"command"},{t:"↗ NAVIGATOR",b:"navigator"},{t:"∿ SYSTEMS",b:"systems"}]
                delegate: Ink { required property var modelData; s: ground.s; text:modelData.t; color:s.accent; font.pixelSize:s.px(11); MouseArea { anchors.fill:parent; onClicked:Ui.open(modelData.b) } }
            }
        }
    }
}
