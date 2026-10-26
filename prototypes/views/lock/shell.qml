//@ pragma UseQApplication
// UI-007 preview fixture only. This is an ordinary PanelWindow, NOT a locker.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.core
import qs.components
import "modules/lock"

ShellRoot {
    id: preview
    property string sample: "idle"
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
        view.state = "idle"; view.message = ""; view.user = "Alex Morgan"; view.attempts = 0; view.password = ""; view.forceActiveFocus();
    }
    function setSample(name) {
        reset(); sample = name;
        view.state = ["idle","checking","failed","locked-out"].indexOf(name) >= 0 ? name : "idle";
        if (name === "failed") { view.message = "Password was not accepted. Try again."; view.attempts = 1; }
        if (name === "locked-out") { view.message = "Authentication is temporarily unavailable. Please try again later."; view.attempts = 5; }
        if (name === "prompt") view.message = "Password for alex@aerolith:";
        if (name === "literal") { view.user = "<b>Alex & Morgan</b>"; view.message = "<b>PAM prompt</b> & literal characters. An extended authentication prompt must wrap without hiding the password field or making the failure hard to understand. Check your credentials before continuing."; view.state = "failed"; }
        if (name === "typing") view.password = "preview-only";
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
        LockView { id: view; anchors.fill: parent; onSubmitted: secret => { preview.lastEvent = "submitted"; state = "checking"; } }
    }
    IpcHandler {
        target: "preview"
        function setCase(name: string): void { preview.setSample(name); }
        function theme(intensity: string, motion: string, low: string, scale: string): void {
            Config.apply(JSON.stringify({schemaVersion:1,theme:{intensity:intensity,motion:motion,lowEffects:low === "true",uiScale:Number(scale),fontSans:scale === "1.25" ? "Noto Sans" : "Inter",fontMono:scale === "1.25" ? "Noto Sans Mono" : "JetBrains Mono"}}));
        }
        function status(): string { return JSON.stringify({sample:preview.sample,event:preview.lastEvent,intensity:Theme.intensity,motion:Config.theme.motion,lowEffects:Theme.lowEffects,state:view.state,bufferLength:view.password.length}); }
    }
    Component.onCompleted: reset()
}
