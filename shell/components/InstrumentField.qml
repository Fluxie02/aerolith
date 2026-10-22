import QtQuick
import qs.core
import qs.services

// All geometry is reconstructed from CPU-side properties after a remap.
// No frame callbacks, persistent GPU content, shader or sampling timer.
Item {
    id: field
    property bool instrument: false
    // DeckView supplies progress for API compatibility. Opening moves the
    // retained chord only; its surrounding geometry stays registered.
    property real progress: 1
    readonly property int level: Theme.variantLevel
    readonly property int workspace: Compositor.focusedWorkspaceId
    function mix(a, b, t) { return Qt.rgba(a.r+(b.r-a.r)*t,a.g+(b.g-a.g)*t,a.b+(b.b-a.b)*t,1); }
    Canvas {
        id: art
        anchors.fill: parent
        renderTarget: Canvas.Image
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        onAvailableChanged: if (available) requestPaint()
        Connections {
            target: art.Window.window
            function onVisibleChanged() { if (art.Window.window.visible) art.requestPaint(); }
        }
        Connections {
            target: field
            function onWorkspaceChanged() { art.requestPaint(); }
            function onLevelChanged() { art.requestPaint(); }
        }
        Connections {
            target: Theme
            function onPaletteChanged() { art.requestPaint(); }
            function onUnitChanged() { art.requestPaint(); }
            function onMonoChanged() { art.requestPaint(); }
            function onFontXsChanged() { art.requestPaint(); }
            function onBootProgressChanged() { if (!field.instrument) art.requestPaint(); }
        }
        onPaint: {
            var c=getContext("2d"); c.reset();
            var w=width,h=height,x=w*.27,y=h*.55,r=h*.34,L=field.level;
            var boot=field.instrument ? 1 : Theme.bootProgress;
            function phase(start, end) {
                var t=Math.max(0,Math.min(1,(boot-start)/(end-start)));
                return t*t*(3-2*t);
            }
            var ringPhase=phase(.04,.60), indexPhase=phase(.20,.78), outerPhase=phase(.38,.96);
            var weak=field.mix(Theme.bg,Theme.grid,.48), rule=Theme.grid;
            function line(a,b,d,e,col,weight) {
                c.strokeStyle=col||rule;c.lineWidth=weight||1;
                c.beginPath();c.moveTo(a,b);c.lineTo(d,e);c.stroke();
            }
            function arc(cx,cy,rr,a,b,col,weight) {
                c.strokeStyle=col||rule;c.lineWidth=weight||1;
                c.beginPath();c.arc(cx,cy,rr,a,b);c.stroke();
            }
            function text(s,tx,ty,col,size) {
                c.fillStyle=col||Theme.textDim;c.font=(size||Theme.fontXs)+'px "'+Theme.mono+'"';c.fillText(s,tx,ty);
            }
            // Machined annulus: the original exposed circular Limb instrument.
            c.fillStyle=field.mix(Theme.bg,Theme.surface,.7);
            c.beginPath();c.arc(x,y,r,0,Math.PI*2);c.fill();
            c.fillStyle=Theme.bg;c.beginPath();c.arc(x,y,r*.91,0,Math.PI*2);c.fill();
            var rings=L===2 ? [.61,.69,.79,.86,1,1.055,1.17,1.27] : [.43,.48,.61,.69,.79,.86,1,1.055,1.17,1.27,1.39,1.48];
            for(var k=0;k<rings.length;k++) {
                var sweep=Math.max(0,Math.min(1,ringPhase*1.4-k/rings.length*.4));
                if(sweep>0)arc(x,y,r*rings[k],-2.9,-2.9+5.7*sweep,k%3===0?rule:weak);
            }
            for(var i=0;i<180;i++) {
                var a=i*Math.PI/90-1.57,rr=r*1.05,len=i%15===0?20:i%5===0?11:4;
                if(i/180>indexPhase)break;
                line(x+Math.cos(a)*rr,y+Math.sin(a)*rr,x+Math.cos(a)*(rr+len),y+Math.sin(a)*(rr+len),i%15===0?Theme.textDim:rule);
                if(i%15===0) text(String(i*2).padStart(3,"0"),x+Math.cos(a)*(rr+37)-9,y+Math.sin(a)*(rr+37)+3,Theme.textDim);
            }
            // Segmented, fixed index band. Its labels are angular coordinates.
            var n=L===2?64:96;
            for(i=0;i<n;i++) {
                if(i/n>indexPhase)break;
                a=-2.65+i*5.3/n;
                arc(x,y,r*.955,a,a+3.9/n,i%8===0?field.mix(Theme.grid,Theme.signal,.5):rule,Theme.du(L===3?14:8));
            }
            // Active workspace registration uses the same position as Limb.
            if(field.workspace>0 && indexPhase>0) {
                c.globalAlpha=indexPhase;
                a=-1.6+field.workspace*.24;
                line(x+Math.cos(a)*(r-8),y+Math.sin(a)*(r-8),x+Math.cos(a)*(r+54),y+Math.sin(a)*(r+54),Theme.signal,3);
                c.globalAlpha=1;
            }
            c.globalAlpha=.24+.76*phase(0,.30);
            line(x-r*.18,y,x+r*.18,y,rule);line(x,y-18,x,y+18,rule);
            // Straight command chord, continued into the screen structure.
            var datum=h*.22;
            line(w*.055,datum,w*.94,datum,rule);
            line(w*.055,datum+8,w*.94,datum+8,weak);
            line(w*.055,h*.87,w*.94,h*.87,rule);
            for(i=0;i<140;i++) {
                var xx=w*.055+i*(w*.885)/140;
                line(xx,datum,xx,datum-(i%10===0?10:4),i%10===0?Theme.textDim:rule);
            }
            // Datum extensions and genuine construction coordinates.
            var rows=L===2?8:14;
            for(i=0;i<rows;i++) {
                var yy=h*(.10+i*.79/Math.max(1,rows-1));
                line(w*.025,yy,w*.045,yy,rule);line(w*.955,yy,w*.975,yy,rule);
                text(String(Math.round(yy)),w*.975+3,yy+3,Theme.textDim);
                if(L>1) line(w*.047,yy,w*.953,yy,weak);
            }
            // Saturated: a second, screen-sized construction cuts the first.
            if(L>=2) {
                c.globalAlpha=outerPhase;
                var sx=w*.82,sy=h*.39,sr=h*.56;
                c.fillStyle=field.mix(Theme.bg,Theme.surface,.32);
                c.beginPath();c.arc(sx,sy,sr*.84,-2.7,1.9);c.lineTo(sx,sy);c.fill();
                for(k=0;k<(L===2?6:12);k++) arc(sx,sy,sr*(.72+k*.045),-2.8,-2.8+4.85*outerPhase,k%3===0?rule:weak);
                for(i=0;i<110;i++) {
                    a=-2.8+i*.044;rr=sr*1.02;
                    line(sx+Math.cos(a)*rr,sy+Math.sin(a)*rr,sx+Math.cos(a)*(rr+(i%5===0?13:5)),sy+Math.sin(a)*(rr+(i%5===0?13:5)),rule);
                }
                // Rectilinear joins deliberately cross the circular field.
                for(k=0;k<(L===2?7:15);k++) {
                    var ax=w*(.50+k*.024),ay=h*(.08+k*.016);
                    c.strokeStyle=k%4===0?field.mix(rule,Theme.signal,.25):weak;c.lineWidth=1;
                    c.beginPath();c.moveTo(ax,ay);c.lineTo(ax,h*.18);c.lineTo(ax+w*.09,h*.31);c.lineTo(w*.965,h*.31+k*9);c.stroke();
                }
            }
            // Insane: dense concentric architecture, indexed ribs and combs.
            if(L===3) {
                c.globalAlpha=outerPhase;
                for(k=0;k<18;k++) {
                    arc(x,y,r*(1.57+k*.037),-1.72,-1.72+3.42*outerPhase,k%4===0?rule:weak,k%4===0?2:1);
                }
                for(i=0;i<56;i++) {
                    xx=w*.055+i*w*.0158;
                    line(xx,h*.945,xx,h*(i%4===0?.975:.96),i%4===0?Theme.textDim:rule,i%4===0?3:1);
                }
                for(k=0;k<9;k++) {
                    var by=h*(.34+k*.048);
                    line(w*.013,by,w*.032,by,Theme.signal,2);
                    line(w*.032,by,w*.052,by+18,rule);
                    text(String(k+1).padStart(2,"0"),w*.014,by-8,Theme.textDim);
                }
                // An opaque phosphor index spine at the screen's right edge.
                c.fillStyle=Theme.signal;c.fillRect(w*.948,h*.38,w*.008,h*.37);
                for(i=0;i<40;i++) line(w*.948,h*(.38+i*.009),w*(i%5===0?.942:.945),h*(.38+i*.009),Theme.signal);
            }
            // All four registration points survive every intensity level.
            c.globalAlpha=1;
            for(k=0;k<4;k++) {
                xx=w*(k%2===0?.055:.94);yy=h*(k<2?.10:.87);
                line(xx-5,yy,xx+5,yy,Theme.textDim);line(xx,yy-5,xx,yy+5,Theme.textDim);
            }
        }
    }
}
