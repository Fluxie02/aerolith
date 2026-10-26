import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.services

// Surface for transient notices and notification popups (NoticeStack). It is
// only as large as its content and takes no keyboard focus, so it never
// blocks other windows. While the Deck is mapped the Deck shows the stack
// itself, because two Overlay surfaces have no reliable stacking order; this
// surface then unmaps.
PanelWindow {
    id: column

    screen: Ui.screen
    visible: stack.hasContent && Ui.screen !== null && !Ui.deckMapped
    color: "transparent"
    anchors {
        right: true
        top: Config.strip.edge === "top"
        bottom: Config.strip.edge === "bottom"
    }
    margins {
        right: Theme.pad
        top: Theme.pad
        bottom: Theme.pad
    }
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    implicitWidth: Math.min(stack.implicitWidth, (Ui.screen ? Ui.screen.width : stack.implicitWidth) - 2 * Theme.pad)
    implicitHeight: Math.max(1, stack.implicitHeight)
    WlrLayershell.namespace: "aerolith-notices"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    NoticeStack {
        id: stack
        width: parent.width
        maximumHeight: Math.max(0, (Ui.screen ? Ui.screen.height : 0) - Theme.stripHeight - 2 * Theme.pad)
    }
}
