//@ pragma UseQApplication
// UI-007 preview fixture only. This is an ordinary PanelWindow, NOT a locker.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.core
import qs.components
import "modules/session"

ShellRoot {
    id: preview
    property string sample: "menu"
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
        view.actions = preview.actions(); view.selected = 0; view.forceActiveFocus();
    }
    function setSample(name) {
        reset(); sample = name;
        if (name === "unavailable") { const a = preview.actions(); a[2] = {id:"suspend",label:"Suspend",sensitive:false,available:false,reason:"Sleep is inhibited by an active recording."}; view.actions = a; view.selected = 2; }
        if (name === "empty") view.actions = [];
        if (name.indexOf("selected-") === 0) { const id = name.slice(9); const a = preview.actions(); for (let i=0;i<a.length;i++) if (a[i].id === id) view.selected = i; }
        if (name === "literal") { const a = preview.actions(); a[2] = {id:"suspend",label:"<b>Suspend & resume</b>",sensitive:false,available:false,reason:"<i>Unavailable</i> & a long inhibition reason that wraps across the row without covering its neighbours."}; view.actions = a; view.selected = 2; }
        if (name.indexOf("confirm-") === 0) { const id = name.slice(8).replace("-accept", ""); const a = preview.actions(); for (let i=0;i<a.length;i++) if (a[i].id === id) view.choose(i); view.confirmSelected = name.indexOf("-accept") >= 0; }
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
        SessionView { id: view; anchors.fill: parent; onActivated: id => { preview.lastEvent = "activated:" + id; } onCancelled: preview.lastEvent = "cancelled" }
    }
    IpcHandler {
        target: "preview"
        function inhibitPending(): void {
            const a = view.actions.slice();
            for (let i=0;i<a.length;i++) if (a[i].id === view.pendingId) a[i] = {id:a[i].id,label:a[i].label,sensitive:a[i].sensitive,available:false,reason:"New inhibitor"};
            view.actions = a;
        }
        function setCase(name: string): void { preview.setSample(name); }
        function theme(intensity: string, motion: string, low: string, scale: string): void {
            Config.apply(JSON.stringify({schemaVersion:1,theme:{intensity:intensity,motion:motion,lowEffects:low === "true",uiScale:Number(scale),fontSans:scale === "1.25" ? "Noto Sans" : "Inter",fontMono:scale === "1.25" ? "Noto Sans Mono" : "JetBrains Mono"}}));
        }
        function status(): string { return JSON.stringify({sample:preview.sample,event:preview.lastEvent,intensity:Theme.intensity,motion:Config.theme.motion,lowEffects:Theme.lowEffects,pending:view.pendingId,confirmSelected:view.confirmSelected,selected:view.selected}); }
    }
    Component.onCompleted: reset()
}
