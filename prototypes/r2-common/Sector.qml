import QtQuick
import qs.core
Item {
    id:tile
    required property var s
    property var sector: ({id:0,windows:[],focused:false})
    property var monitor:null
    property bool selected:false
    property string selectedWindow:""
    property string closeArmed:""
    property var filterFn:w=>true
    signal sectorClicked()
    signal windowClicked(var w)
    Frame {anchors.fill:parent;s:tile.s;active:tile.selected}
    Rectangle {width:parent.width;height:s.px(3);color:sector.focused?s.accent:s.line}
    Ink {s:tile.s;x:s.px(12);y:s.px(15);text:"WS "+tile.sector.id;font.pixelSize:s.px(14);font.weight:Font.DemiBold;color:tile.selected?s.accent:s.text}
    Ink {s:tile.s;anchors.right:parent.right;anchors.rightMargin:s.px(12);y:s.px(17);text:tile.sector.focused?"ACTIVE":tile.sector.windows.length+" WIN";color:s.dim;font.pixelSize:s.px(10)}
    MouseArea {anchors.fill:parent;onClicked:tile.sectorClicked()}
    Item {
        id:map;x:s.px(12);y:s.px(47);width:parent.width-s.px(24);height:s.keel?parent.height-s.px(64):Math.min(width*.62,parent.height*.34);clip:true
        Rectangle {anchors.fill:parent;color:s.bg;border.color:s.line}
        Repeater {model:tile.sector.windows
            Rectangle {
                required property var modelData
                required property int index
                readonly property bool placed:tile.monitor !== null && tile.monitor.width>0 && modelData.at !== null && modelData.size !== null
                x:placed?(modelData.at[0]-tile.monitor.x)*map.width/tile.monitor.width+2:4
                y:placed?(modelData.at[1]-tile.monitor.y)*map.height/tile.monitor.height+2:6+index*map.height/Math.max(1,tile.sector.windows.length)
                width:placed?Math.max(12,modelData.size[0]*map.width/tile.monitor.width-4):map.width-12
                height:placed?Math.max(12,modelData.size[1]*map.height/tile.monitor.height-4):map.height/Math.max(1,tile.sector.windows.length)-12
                color:modelData.address===tile.selectedWindow?s.alpha(s.accent,.15):s.inset
                border.color:modelData.address===tile.closeArmed?s.error:modelData.address===tile.selectedWindow?s.accent:s.line
                opacity:tile.filterFn(modelData)?1:.25
                clip:true
                Column {x:s.px(6);y:s.px(6);width:parent.width-s.px(12);spacing:s.px(4);visible:s.keel
                    Ink {s:tile.s;width:parent.width;text:modelData.appId.toUpperCase();color:s.accent;font.pixelSize:s.px(10)}
                    Ink {s:tile.s;width:parent.width;text:modelData.title;wrapMode:Text.WordWrap;maximumLineCount:3;mono:false;font.pixelSize:s.px(12)}
                }
                MouseArea {anchors.fill:parent;onClicked:tile.windowClicked(modelData)}
            }
        }
        Ink {s:tile.s;visible:tile.sector.windows.length===0;anchors.centerIn:parent;text:"—";color:s.dim}
    }
    Column {
        visible:!s.keel;x:s.px(12);y:map.y+map.height+s.px(22);width:parent.width-s.px(24);spacing:s.px(18)
        Repeater {model:tile.sector.windows
            delegate:Item {
                required property var modelData
                width:parent.width;height:body.implicitHeight+s.px(12)
                Rectangle {x:-s.px(12);width:2;height:parent.height;visible:modelData.address===tile.selectedWindow;color:modelData.address===tile.closeArmed?s.error:s.accent}
                Column {id:body;width:parent.width;spacing:s.px(8)
                    Ink {s:tile.s;width:parent.width;text:modelData.appId.toUpperCase();color:modelData.address===tile.selectedWindow?s.accent:s.dim;font.pixelSize:s.px(10)}
                    Ink {s:tile.s;width:parent.width;text:modelData.title;wrapMode:Text.WordWrap;maximumLineCount:4;mono:false;font.pixelSize:s.px(14);font.weight:s.fault?Font.DemiBold:Font.Normal}
                }
                opacity:tile.filterFn(modelData)?1:.25
                MouseArea {anchors.fill:parent;onClicked:tile.windowClicked(modelData)}
            }
        }
        Ink {s:tile.s;visible:tile.sector.windows.length===0;text:"UNASSIGNED";color:s.dim;font.pixelSize:s.px(10)}
    }
}
