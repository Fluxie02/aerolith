import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.services
PanelWindow {
    id:column
    required property var s
    screen:Ui.screen;visible:Ui.screen!==null && (Ui.notices.length>0 || Notifications.popups.length>0)
    anchors {right:true;top:Config.strip.edge==="top";bottom:Config.strip.edge==="bottom"}
    margins {right:s.px(s.fault?84:40);top:Theme.stripHeight+s.px(s.limb?120:50);bottom:Theme.stripHeight+s.px(32)}
    implicitWidth:s.px(440);implicitHeight:Math.max(1,stack.implicitHeight)
    color:"transparent";exclusionMode:ExclusionMode.Ignore;exclusiveZone:0
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.namespace:"aerolith-notices"
    WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
    Column {
        id:stack;width:parent.width;spacing:s.px(12)
        Repeater {model:Notifications.popups
            delegate:Annotation {required property var modelData;s:column.s;width:stack.width;message:modelData.summary||modelData.appName;detail:modelData.body||"";severity:modelData.urgency===2?"error":"info";onDismissed:Notifications.dropPopup(modelData)
                Timer {running:true;interval:Config.notifications.popupTimeoutMs;onTriggered:parent.dismissed()}
            }
        }
        Repeater {model:Ui.notices
            delegate:Annotation {required property var modelData;s:column.s;width:stack.width;message:modelData.message;detail:modelData.detail;severity:modelData.severity;onDismissed:Ui.dismiss(modelData.id)
                Timer {running:true;interval:Math.max(1,(modelData.severity==="error"||modelData.severity==="caution"?8000:3500)-(Date.now()-modelData.at));onTriggered:parent.dismissed()}
            }
        }
    }
    component Annotation:Item {
        id:note
        required property var s
        property string message:""
        property string detail:""
        property string severity:"info"
        signal dismissed()
        readonly property color tone:severity==="error"?s.error:severity==="caution"?s.caution:s.accent
        height:content.implicitHeight+s.px(40)
        Frame {anchors.fill:parent;s:note.s}
        Rectangle {x:s.px(14);y:s.px(18);width:s.px(6);height:s.px(6);rotation:s.limb?45:0;color:note.tone}
        Column {id:content;x:s.px(34);y:s.px(18);width:parent.width-s.px(65);spacing:s.px(10)
            Ink {s:note.s;text:note.severity.toUpperCase()+" / ANNUNCIATION";color:note.tone;font.pixelSize:s.px(10);font.letterSpacing:1}
            Ink {s:note.s;width:parent.width;text:note.message;wrapMode:Text.WordWrap;maximumLineCount:3;mono:!s.fault;font.pixelSize:s.px(14)}
            Ink {s:note.s;visible:note.detail!=="";width:parent.width;text:note.detail;wrapMode:Text.WordWrap;maximumLineCount:3;color:s.dim;font.pixelSize:s.px(11)}
        }
        Ink {s:note.s;anchors.right:parent.right;anchors.rightMargin:s.px(14);y:s.px(14);text:"×";color:s.dim;MouseArea {anchors.fill:parent;anchors.margins:-5;onClicked:note.dismissed()}}
        property real entry:0
        Component.onCompleted:entry=1
        opacity:s.animate?entry:1
        x:s.travel?(1-entry)*(s.fault?30:-18):0
        Behavior on entry {enabled:s.animate;NumberAnimation {duration:Theme.fast;easing.type:Easing.OutCubic}}
    }
}
