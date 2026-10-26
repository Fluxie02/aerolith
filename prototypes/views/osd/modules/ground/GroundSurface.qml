import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core

// The desktop ground: a background-layer surface behind every window, on
// the shell's one display. It never takes keyboard focus, reserves no
// space and only redraws when what it shows changes (Ground.qml must not
// run timers or looping animations). ground.enabled = false leaves the
// background to another program (hyprpaper, swaybg).
PanelWindow {
    id: ground

    screen: Ui.screen
    visible: Config.ground.enabled && Ui.screen !== null
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "aerolith-ground"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Ground {
        anchors.fill: parent
    }
}
