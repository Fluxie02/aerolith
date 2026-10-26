import QtQuick
import qs.core
import qs.components
import qs.services
import "telemetry.mjs" as T
FocusScope {
    id:bay
    required property var s
    readonly property int seq:Telemetry.sampleSeq
    Component.onCompleted:{Telemetry.acquire("panel");Telemetry.acquire("detail");}
    Component.onDestruction:{Telemetry.release("panel");Telemetry.release("detail");}
    Keys.onPressed:event=>{if(event.key===Qt.Key_C){Telemetry.processSort="cpu";event.accepted=true;}else if(event.key===Qt.Key_M){Telemetry.processSort="memory";event.accepted=true;}else if(event.key===Qt.Key_P){Registry.run("telemetry.performance-mode");event.accepted=true;}}
    readonly property var metrics: [
        {label:"CPU LOAD",value:T.formatPercent(Telemetry.cpu.total),fraction:Telemetry.cpu.total,history:Telemetry.cpuHistory.values()},
        {label:"MEMORY",value:T.formatPercent(Telemetry.memory?Telemetry.memory.percent:null),fraction:Telemetry.memory?Telemetry.memory.percent:null,history:Telemetry.memHistory.values()},
        {label:"NETWORK / RX",value:T.formatRate(Telemetry.net?Telemetry.net.rxBps:null),fraction:null,history:Telemetry.rxHistory.values()},
        {label:"GPU LOAD",value:T.formatPercent(Telemetry.gpu?Telemetry.gpu.utilPercent:null),fraction:Telemetry.gpu?Telemetry.gpu.utilPercent:null,history:Telemetry.gpuHistory.values()}
    ]
    Ink {s:bay.s;text:"LIVE / "+Telemetry.interval+" MS    ·    "+Telemetry.samplesTaken+" SAMPLES    ·    GPU "+Telemetry.gpuStatus.toUpperCase();font.pixelSize:s.px(11);color:s.dim}
    Row {
        id:traces;y:s.px(38);width:parent.width;spacing:s.px(24)
        Repeater {model:bay.metrics
            delegate:Item {
                required property var modelData
                required property int index
                width:(traces.width-traces.spacing*3)/4;height:s.px(s.limb?215:180)
                Ink {s:bay.s;text:modelData.label;font.pixelSize:s.px(11);color:s.dim}
                Ink {s:bay.s;y:s.px(28);text:modelData.value;font.pixelSize:s.px(s.fault?36:32);color:index===0?s.accent:s.text;font.weight:Font.Medium}
                Rectangle {y:s.px(80);width:parent.width;height:parent.height-y-s.px(15);color:s.alpha(s.bg,.75);border.color:s.line
                    Trace {anchors.fill:parent;anchors.margins:1;values:{bay.seq;return index===0?Telemetry.cpuHistory.values():index===1?Telemetry.memHistory.values():index===2?Telemetry.rxHistory.values():Telemetry.gpuHistory.values();} seq:bay.seq;color:bay.s.accent;autoMax:index===2;capacity:Config.telemetry.historySamples}
                    Ink {s:bay.s;anchors.centerIn:parent;visible:modelData.fraction===null && index!==2;text:"N/A";color:s.dim;font.pixelSize:s.px(11)}
                }
                Rectangle {y:parent.height-1;width:parent.width;height:1;color:s.line}
            }
        }
    }
    Item {
        y:traces.y+s.px(s.limb?246:212);width:parent.width;height:parent.height-y-s.px(42)
        Column {
            width:parent.width*.4;spacing:s.px(16)
            Ink {s:bay.s;text:"CORE BUS / "+Telemetry.cpu.cores.length+" LOGICAL";color:s.dim;font.pixelSize:s.px(11)}
            Row {width:parent.width;spacing:s.px(3)
                Repeater {model:Telemetry.cpu.cores.slice(0,32)
                    Rectangle {required property var modelData;width:(parent.width-(Math.min(32,Telemetry.cpu.cores.length)-1)*s.px(3))/Math.max(1,Math.min(32,Telemetry.cpu.cores.length));height:s.px(38);color:s.bg;border.color:s.line
                        Rectangle {anchors.bottom:parent.bottom;width:parent.width;height:modelData===null?parent.height:Math.max(1,parent.height*modelData/100);color:modelData===null?"transparent":s.accent;border.color:modelData===null?s.line:"transparent"}
                    }
                }
            }
            Ink {s:bay.s;text:"STORAGE / FILESYSTEMS";color:s.dim;font.pixelSize:s.px(11)}
            Repeater {model:Telemetry.disks.slice(0,3)
                delegate:Item {required property var modelData;width:parent.width;height:s.px(40)
                    Ink {s:bay.s;width:parent.width;text:modelData.mount+"   "+T.formatBytes(modelData.usedBytes)+" / "+T.formatBytes(modelData.sizeBytes);font.pixelSize:s.px(11)}
                    TapeGauge {y:s.px(23);width:parent.width;height:s.px(12);value:modelData.percent===null?NaN:modelData.percent}
                }
            }
            Ink {s:bay.s;text:"SWAP / "+(!Telemetry.memory||Telemetry.memory.swapTotalBytes===null?"N/A":Telemetry.memory.swapTotalBytes===0?"NONE":T.formatPercent(Telemetry.memory.swapPercent));font.pixelSize:s.px(11);color:s.dim}
        }
        Column {
            x:parent.width*.46;width:parent.width-x;spacing:s.px(12)
            Ink {s:bay.s;text:"PROCESS TABLE / "+(Telemetry.processSort==="cpu"?"CPU · 1 CORE = 100%":"MEMORY");color:s.dim;font.pixelSize:s.px(11)}
            Row {width:parent.width
                Ink {s:bay.s;width:parent.width*.14;text:"PID";color:s.dim;font.pixelSize:s.px(10)}
                Ink {s:bay.s;width:parent.width*.48;text:"COMMAND";color:s.dim;font.pixelSize:s.px(10)}
                Ink {s:bay.s;width:parent.width*.16;text:"CPU";color:s.dim;font.pixelSize:s.px(10)}
                Ink {s:bay.s;width:parent.width*.22;text:"RSS";color:s.dim;font.pixelSize:s.px(10)}
            }
            Repeater {model:Telemetry.processes.slice(0,5)
                delegate:Row {required property var modelData;width:parent.width
                    Ink {s:bay.s;width:parent.width*.14;text:modelData.pid;font.pixelSize:s.px(11);color:s.dim}
                    Ink {s:bay.s;width:parent.width*.48;text:modelData.comm;font.pixelSize:s.px(11)}
                    Ink {s:bay.s;width:parent.width*.16;text:modelData.cpuPercent===null?"N/A":modelData.cpuPercent.toFixed(0)+"%";font.pixelSize:s.px(11)}
                    Ink {s:bay.s;width:parent.width*.22;text:T.formatBytes(modelData.rssBytes);font.pixelSize:s.px(11)}
                }
            }
        }
    }
    Ink {s:bay.s;y:parent.height-s.px(16);width:parent.width;text:"C SORT CPU   M SORT MEMORY   P PERFORMANCE MODE     /proc + sysfs · NO SYNTHETIC SIGNAL";color:s.dim;font.pixelSize:s.px(10)}
}
