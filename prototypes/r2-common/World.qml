import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.services
import qs.modules.routines
import qs.modules.help
import qs.modules.signal
import qs.modules.strip
Scope {
    id: world
    property int concept: 0
    Style { id: design; concept: world.concept }
    PanelWindow {
        screen: Ui.screen; visible: Ui.screen !== null
        color: design.bg
        anchors { top:true; bottom:true; left:true; right:true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "aerolith-prototype-ground"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        Ground { anchors.fill: parent; s: design }
    }
    // The strip retains the production telemetry, privacy and workspace controls.
    Strip {s:design}
    PanelWindow {
        id: deck
        screen: Ui.screen; visible: Ui.deckOpen && Ui.screen !== null
        anchors { top:true; bottom:true; left:true; right:true }
        color:"transparent"; exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "aerolith-deck"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        readonly property var rail: [{b:"command",t:"CMD",k:"1"},{b:"navigator",t:"NAV",k:"2"},{b:"systems",t:"SYS",k:"3"},{b:"signal",t:"SIG",k:"4"},{b:"routines",t:"RTN",k:"5"},{b:"ai",t:"AI",k:"6"},{b:"help",t:"HELP",k:"F1"}]
        Rectangle { anchors.fill:parent; color:design.alpha(design.bg,0.58) }
        Ground { anchors.fill:parent; s:design; instrument:true; progress:page.progress }
        MouseArea { anchors.fill:parent; onClicked:Ui.close() }
        // Sharing status remains unobscured above the full-screen overlay.
        Ink { s:design; x:40; y:Theme.stripHeight+10; width:parent.width-80; color:design.error; visible:Compositor.screencastActive; text:"● SHARING  " + Compositor.screencastOwner }
        FocusScope {
            anchors.fill:parent; focus:true
            Keys.priority: Keys.AfterItem
            Keys.onPressed: event => {
                if(event.key===Qt.Key_Escape){Ui.close();event.accepted=true;}
                else if(event.key===Qt.Key_F1){Ui.toggle("help");event.accepted=true;}
                else if((event.modifiers & Qt.ControlModifier) && event.key>=Qt.Key_1 && event.key<=Qt.Key_6){Ui.open(deck.rail[event.key-Qt.Key_1].b);event.accepted=true;}
            }
            Row {
                x: design.keel ? parent.width*.16 : design.limb ? parent.width*.37 : parent.width*.08
                y: Theme.stripHeight+design.px(42); spacing:design.px(25)
                Repeater { model:deck.rail
                    delegate: Item {
                        required property var modelData
                        width:design.px(modelData.b==="help"?88:74);height:design.px(34)
                        Ink { s:design; text:(modelData.k==="F1"?"F1":"^"+modelData.k)+" "+modelData.t; color:Ui.activeBay===modelData.b?design.accent:design.dim; font.pixelSize:design.px(11) }
                        Rectangle { y:design.px(25); width:Ui.activeBay===modelData.b?parent.width:8; height:Ui.activeBay===modelData.b?2:1; color:Ui.activeBay===modelData.b?design.accent:design.line; Behavior on width { enabled:design.animate; NumberAnimation {duration:Theme.fast;easing.type:design.ease} } }
                        MouseArea {anchors.fill:parent;onClicked:Ui.open(modelData.b)}
                    }
                }
            }
            Item {
                id: page
                property real progress: 1
                readonly property bool nav:Ui.activeBay==="navigator"
                readonly property bool sys:Ui.activeBay==="systems"
                readonly property real originX: design.keel ? parent.width*.16 : design.limb && !nav && !sys ? parent.width*.37 : design.fault ? parent.width*.08 : parent.width*.12
                x: originX + (design.travel && design.fault ? (1-progress)*-66 : 0)
                y: parent.height*(design.keel?.23:design.limb?.22:.26) + (design.travel && !design.keel ? (1-progress)*(design.fault?44:12):0)
                width:parent.width-originX-parent.width*(design.limb?.08:.12)
                height:parent.height-y-design.px(design.fault?100:130)
                opacity:design.animate?Math.min(1,progress*2):1
                clip:design.keel && progress<1
                scale:design.travel && design.limb ? .94 + progress*.06 : 1
                transformOrigin: Item.Left
                function reveal(){progress=0;enter.restart();}
                Connections { target:Ui; function onActiveBayChanged(){if(Ui.deckOpen)page.reveal();} }
                NumberAnimation { id:enter; target:page; property:"progress"; from:0;to:1;duration:design.enter;easing.type:design.ease }
                // This mask makes Keel extend from a fixed datum; it never delays input.
                Item {
                    width:design.keel && design.travel ? parent.width*page.progress : parent.width
                    height:parent.height; clip:design.keel
                    Item {
                        width:page.width;height:page.height
                        Frame { anchors.fill:parent; s:design;outer:true }
                        MouseArea {anchors.fill:parent}
                        Row { x:design.px(28);y:design.px(20);spacing:design.px(18)
                            Ink { s:design; text:Ui.activeBay==="command"?"CMD / 01":Ui.activeBay==="navigator"?"NAV / 02":Ui.activeBay==="systems"?"SYS / 03":Ui.activeBay.toUpperCase();color:design.accent;font.pixelSize:design.px(11) }
                            Ink { s:design; text:Ui.activeBay==="command"?"COMMAND CORE":Ui.activeBay==="navigator"?"SPATIAL NAVIGATOR":Ui.activeBay==="systems"?"SYSTEMS BAY":Ui.activeBay.toUpperCase();font.pixelSize:design.px(13);font.letterSpacing:2;font.weight:Font.DemiBold }
                        }
                        Ink { s:design; anchors.right:parent.right;anchors.rightMargin:design.px(40); y:design.px(20);text:"ESC / CLOSE";color:design.dim;font.pixelSize:design.px(11); MouseArea {anchors.fill:parent;onClicked:Ui.close()} }
                        Rectangle {x:design.px(28);y:design.px(55);width:parent.width-design.px(56);height:1;color:design.line}
                        Loader {
                            id:loader
                            x:design.px(28); y:design.px(82); width:parent.width-design.px(56);height:parent.height-y-design.px(24)
                            active:deck.visible;focus:true
                            sourceComponent:Ui.activeBay==="command"?command:Ui.activeBay==="navigator"?navigator:Ui.activeBay==="systems"?systems:Ui.activeBay==="signal"?signal:Ui.activeBay==="routines"?routines:Ui.activeBay==="help"?help:missing
                            onLoaded:{ item.forceActiveFocus();page.reveal(); }
                        }
                    }
                }
                // Offset registration planes: present a readable non-blurred depth cue.
                Rectangle {visible:design.fault && !Theme.lowEffects;x:parent.width+design.px(15)+(design.travel?(1-page.progress)*50:0);y:-design.px(50);width:design.px(24);height:parent.height+design.px(22);color:design.alpha(design.accent,.3)}
            }
            Column {
                visible:design.limb && Ui.activeBay==="command"
                x:parent.width*.105;y:parent.height*.43;spacing:design.px(16)
                Ink {s:design;text:"COMMAND";mono:false;font.pixelSize:design.px(34);font.weight:Font.Medium;font.letterSpacing:1}
                Ink {s:design;text:"CORE";mono:false;font.pixelSize:design.px(34);font.weight:Font.Medium;font.letterSpacing:9}
                Rectangle {width:design.px(92);height:2;color:design.accent}
                Ink {s:design;text:"KEYBOARD / FIRST\n>  COMMANDS\n@  WINDOWS\n!  ROUTINES\n?  AI IF INSTALLED";font.pixelSize:design.px(11);color:design.dim;lineHeight:1.7}
            }
            Ink {s:design;visible:design.fault;x:parent.width*.08;y:parent.height*.16;text:Ui.activeBay==="command"?"COMMAND / CORE":Ui.activeBay==="navigator"?"WORKSPACE / FIELD":Ui.activeBay==="systems"?"SYSTEM / PRESSURE":Ui.activeBay.toUpperCase();mono:false;font.pixelSize:design.px(46);font.weight:Font.Bold;font.letterSpacing:-1}
            Ink {s:design;x:parent.width*.08;y:parent.height-design.px(50);text:"AEROLITH   /   "+(design.keel?"KEEL":design.limb?"LIMB":"FAULT");font.pixelSize:design.px(11);color:design.dim}
        }
        Component {id:command; Command {s:design}}
        Component {id:navigator; Navigator {s:design}}
        Component {id:systems; Systems {s:design}}
        Component {id:signal;SignalRack {}}
        Component {id:routines;RoutineConsole {}}
        Component {id:help;HelpBay {}}
        Component {id:missing;FocusScope {Ink {s:design;width:parent.width;text:"This concept studies Command, Navigator and Systems. Other bays retain production support after selection.";wrapMode:Text.WordWrap}}}
    }
    Notices {s:design}
}
