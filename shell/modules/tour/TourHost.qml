import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.services

// Destroyed by shell.qml as soon as the tour ends or fullscreen takes over.
PanelWindow {
    id: host
    objectName: "tourHost"
    readonly property var profile: displayProfile
    DisplayProfile { id: displayProfile; output: Tour.output ? Tour.output.name : "" }
    screen: Tour.output ? Tour.output.screen : null
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "aerolith-tour"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property bool compact: Theme.layoutFor(width, height, Tour.output ? Tour.output.name : "").compact
    readonly property string stepId: Tour.steps[Tour.step]
    // Each target maps only inside its own layer surface, then publishes
    // output-local logical coordinates. Tour is a full-output overlay at 0,0.
    readonly property var anchor: Anchors.lookup(Tour.output ? Tour.output.name : "", stepId)
    readonly property rect target: anchor ? Qt.rect(anchor.x, anchor.y, anchor.width, anchor.height) : Qt.rect(0, 0, 0, 0)
    readonly property bool targetVisible: anchor !== null
    readonly property var stepNames: ["Hatch", "Workspaces", "Search", "Used apps", "Status strip"]
    readonly property var words: [
        {title: "A SPACE TO KEEP THINGS", body: "The hatch opens your scratch space. Park any window here and bring it back when you need it.", key: "SUPER + S  OPEN / CLOSE\nSUPER + SHIFT + S  PARK A WINDOW"},
        {title: "ROOM FOR EACH TASK", body: "Click a station on the workspace " + (host.compact ? "row" : "ring") + " to switch. Its window count shows where your work is.", key: ""},
        {title: "FIND IT. OPEN IT.", body: "Search for an app or a shell action. Type a name, then press Enter.", key: "SUPER + SPACE  SEARCH & LAUNCH"},
        {title: "YOUR APPS, CLOSE BY", body: "The bottom bar keeps your most used apps nearby. Click to open an app or return to its windows.", key: ""},
        {title: Network.available || Bluetooth.available ? "CONNECTIONS AT A GLANCE" : "YOUR STATUS STRIP", body: (Network.available || Bluetooth.available ? "Click " + [Network.available ? "Network" : "", Bluetooth.available ? "Bluetooth" : ""].filter(s => s !== "").join(" or ") + " in the " + (Config.strip.edge === "top" ? "top" : "bottom") + " status strip to connect." : "The " + Config.strip.edge + " status strip shows your workspace, sound and time.") + " Open Settings to change the layout and decoration level.", key: "ENTER  FINISH   ·   ESC  SKIP"}
    ]
    // Four quiet scrims leave the actual target undimmed. No copied artwork.
    Repeater {
        model: host.targetVisible ? [Qt.rect(0, 0, host.width, Math.max(0, host.target.y)), Qt.rect(0, host.target.y, Math.max(0, host.target.x), host.target.height), Qt.rect(host.target.x + host.target.width, host.target.y, Math.max(0, host.width - host.target.x - host.target.width), host.target.height), Qt.rect(0, host.target.y + host.target.height, host.width, Math.max(0, host.height - host.target.y - host.target.height))] : [Qt.rect(0, 0, host.width, host.height)]
        Rectangle {
            required property var modelData
            objectName: "tourScrim"
            x: modelData.x; y: modelData.y; width: modelData.width; height: modelData.height
            color: host.profile.bg; opacity: .76
        }
    }
    Rectangle {
        objectName: "tourTarget"
        x: host.target.x; y: host.target.y; width: host.target.width; height: host.target.height
        visible: host.targetVisible
        color: "transparent"; border.color: host.profile.signal; border.width: Theme.px(2)
        Behavior on x { enabled: Theme.travel; NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
        Behavior on y { enabled: Theme.travel; NumberAnimation { duration: Theme.fast; easing.type: Easing.OutCubic } }
    }
    FocusScope {
        id: keys
        objectName: "tourNavigation"
        anchors.fill: parent; focus: true
        Component.onCompleted: forceActiveFocus()
        Keys.onEscapePressed: Tour.skip()
        Keys.onReturnPressed: Tour.next()
        Keys.onEnterPressed: Tour.next()
        Keys.onLeftPressed: Tour.back()
        Keys.onRightPressed: Tour.next()
        TourCard {
            id: card
            profile: host.profile
            width: Math.min(Theme.du(420), host.width - Theme.pad * 2, host.stepId === "hatch" ? Math.max(Theme.du(240), host.target.x - Theme.du(30) - Theme.pad) : host.width)
            step: Tour.step
            stepName: host.stepNames[Tour.step]
            heading: host.words[Tour.step].title
            explanation: host.words[Tour.step].body + (!host.targetVisible ? (host.stepId === "search" || host.stepId === "strip" ? (host.stepId === "strip" ? " Your status strip is hidden in this layout. Open Settings below or use Search (Super + Space by default)." : " Your status strip is hidden in this layout. Use Search (Super + Space by default) to find apps and Settings.") : " Your desktop background is hidden in this layout.") : "")
            shortcut: host.words[Tour.step].key
            // Hatch: left of its entrance. Ring/apps: above their lower rail.
            // Search/strip: directly below (or above a bottom-edge strip).
            x: Math.max(Theme.pad, Math.min(host.width - width - Theme.pad, host.stepId === "hatch" ? host.target.x - width - Theme.du(30) : host.stepId === "ring" || host.stepId === "apps" ? host.target.x : host.stepId === "search" ? host.target.x + Theme.du(12) : host.width - width - Theme.pad))
            y: Math.max(Theme.stripHeight + Theme.du(16), Math.min(host.height - height - Theme.stripHeight - Theme.du(16), host.stepId === "hatch" ? host.target.y : host.stepId === "apps" || host.stepId === "ring" ? host.target.y - height - Theme.du(24) : Config.strip.edge === "top" ? Theme.stripHeight + Theme.du(24) : host.target.y - height - Theme.du(24)))
        }
    }
}
