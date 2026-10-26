//@ pragma UseQApplication
// UI-007 preview fixture only. This is an ordinary PanelWindow, NOT a locker.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.core
import qs.components
import "modules/osd"

ShellRoot {
    id: preview
    property string sample: "volume"
    property string lastEvent: "none"
    readonly property bool configurationReady: Config.loaded
    function actions() { return [
        {id:"lock",label:"Lock",sensitive:false,available:true,reason:""},
        {id:"logout",label:"Log out",sensitive:true,available:true,reason:""},
        {id:"suspend",label:"Suspend",sensitive:true,available:true,reason:""},
        {id:"reboot",label:"Reboot",sensitive:true,available:true,reason:""},
        {id:"shutdown",label:"Shut down",sensitive:true,available:true,reason:""}
    ]; }
    function reset() {
        lastEvent = "none";
        view.kind = "volume"; view.value = .64; view.maxValue = 1; view.muted = false; view.label = "Built-in Audio · Speakers"; view.presentationOpen = true;
    }
    function setSample(name) {
        reset(); sample = name;
        if (name.indexOf("brightness") === 0) { view.kind = "brightness"; view.label = "Built-in display"; view.value = .42; }
        if (name.indexOf("mic") === 0) { view.kind = "mic"; view.label = "Studio Microphone · Input"; view.value = .78; }
        if (name.indexOf("muted") >= 0) view.muted = true;
        if (name.indexOf("unknown") >= 0) view.value = NaN;
        if (name === "zero") view.value = 0;
        if (name === "maximum") view.value = 1;
        if (name === "amplified") { view.maxValue = 1.5; view.value = 1.25; }
        if (name === "clamped") { view.maxValue = 1.5; view.value = 2; }
        if (name === "literal") view.label = "<b>Audio & display</b> · A very long device label that must remain literal and be elided";
        if (name === "exit") view.presentationOpen = false;
    }
    PanelWindow {
        id: window
        screen: Ui.screen
        visible: Ui.screen !== null
        anchors { top: true; bottom: true; left: true; right: true }
        color: Theme.bg
        WlrLayershell.namespace: "aerolith-visual-preview"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        Rectangle { anchors.fill: parent; color: Theme.bg
            Text { x: Theme.du(40); y: Theme.du(40); text: "AEROLITH / OSD PREVIEW"; color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontSm }
            OsdView { id: view; anchors.horizontalCenter: parent.horizontalCenter; y: Math.min(parent.height*.76,parent.height-height-Theme.du(32)); width: Math.min(implicitWidth,parent.width-Theme.du(32)); height: implicitHeight; onSettled: preview.lastEvent = "settled" }
        }
    }
    IpcHandler {
        target: "preview"
        function setCase(name: string): void { preview.setSample(name); }
        function theme(intensity: string, motion: string, low: string, scale: string): void {
            Config.apply(JSON.stringify({schemaVersion:1,theme:{intensity:intensity,motion:motion,lowEffects:low === "true",uiScale:Number(scale),fontSans:scale === "1.25" ? "Noto Sans" : "Inter",fontMono:scale === "1.25" ? "Noto Sans Mono" : "JetBrains Mono"}}));
        }
        function status(): string { return JSON.stringify({sample:preview.sample,event:preview.lastEvent,intensity:Theme.intensity,motion:Config.theme.motion,lowEffects:Theme.lowEffects,kind:view.kind,known:view.known,value:view.known ? view.bounded : null,presenting:view.presenting}); }
    }
    Component.onCompleted: reset()
}
