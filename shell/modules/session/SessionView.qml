// UI-007 / visual-only session chooser. Host supplies actions as a replaced JS
// array of {id: string, label: plain string, sensitive: bool, available: bool,
// reason: plain string}. Missing available is treated as unavailable.
// Outputs: activated(string id), cancelled(). No commands or session calls.
// Every sensitive action (and canonical logout/reboot/shutdown) requires a
// second deliberate activation. Escape backs out of confirmation, then cancels.
// Host gives this FocusScope focus on open and closes it after either signal.
import QtQuick
import qs.core
import qs.components

FocusScope {
    id: root
    property var profile: Theme
    property var actions: []
    signal activated(string id)
    signal cancelled()
    property int selected: 0
    property string pendingId: ""
    property bool confirmSelected: false
    readonly property var pending: find(pendingId)
    readonly property bool confirming: pending !== null
    function find(id) {
        for (let i=0; i<actions.length; i++) if (actions[i].id === id) return actions[i];
        return null;
    }
    function sensitive(a) { return a.sensitive === true || ["logout", "reboot", "shutdown", "poweroff", "session.logout", "system.reboot", "system.poweroff"].indexOf(a.id) >= 0; }
    function choose(index) {
        const a = actions[index];
        if (!a || a.available !== true) return;
        selected = index;
        if (sensitive(a)) { pendingId = a.id; confirmSelected = false; }
        else activated(a.id);
    }
    function confirm() {
        const a = find(pendingId);
        if (a && a.available === true) { pendingId = ""; confirmSelected = false; activated(a.id); }
    }
    function back() { if (confirming) { pendingId = ""; confirmSelected = false; } else cancelled(); }
    onActionsChanged: { pendingId = ""; confirmSelected = false; selected = Math.max(0,Math.min(selected,Math.max(0,actions.length-1))); }
    onVisibleChanged: if (!visible) { pendingId = ""; confirmSelected = false; }
    Component.onCompleted: forceActiveFocus()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) { back(); event.accepted = true; }
        else if (confirming) {
            if ([Qt.Key_Left,Qt.Key_Right,Qt.Key_Tab,Qt.Key_Backtab].indexOf(event.key)>=0) { confirmSelected = !confirmSelected; event.accepted = true; }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                if (!event.isAutoRepeat) { if (confirmSelected) confirm(); else back(); }
                event.accepted = true;
            }
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) { selected = Math.max(0,selected-1); event.accepted = true; }
        else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) { selected = Math.max(0,Math.min(actions.length-1,selected+1)); event.accepted = true; }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { if (!event.isAutoRepeat) choose(selected); event.accepted = true; }
    }
    Rectangle { anchors.fill: parent; color: Theme.lowEffects ? root.profile.bg : Theme.alpha(root.profile.bg,.97) }
    // Static, content-free registration field. No compositor/window metadata.
    Repeater {
        model: Theme.insane ? 20 : 10
        Rectangle {
            required property int index
            x: Theme.du(36); y: (index+1)*root.height/((Theme.insane ? 20 : 10)+1)
            width: index%5 === 0 ? root.width-Theme.du(72) : Theme.du(24)
            height: 1; color: root.profile.grid
        }
    }
    Bezel { profile: root.profile;
        id: panel
        anchors.centerIn: parent
        width: Math.min(root.width-Theme.du(48),Theme.du(640))
        height: Math.min(root.height-Theme.du(48),Theme.du(600))
        designation: "02"; title: "Session control"
        status: root.confirming ? "CONFIRM" : "SELECT"; statusColor: root.confirming ? root.profile.caution : root.profile.signal
        accent: root.confirming ? root.profile.caution : root.profile.signal
        Column {
            id: heading; width: parent.width; spacing: Theme.du(10)
            Text {
                width: parent.width; text: root.confirming ? root.pending.label + "?" : "Leave the controls."
                textFormat: Text.PlainText; wrapMode: Text.Wrap
                color: root.profile.text; font.family: Theme.displaySans; font.pixelSize: Theme.du(32)
            }
            Text {
                width: parent.width
                text: root.confirming ? "Confirm this action to continue. Save your work first." : root.actions.length ? "Choose what happens to your session." : "No session actions are available."
                textFormat: Text.PlainText; wrapMode: Text.Wrap
                color: root.profile.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontLg
            }
        }
        ListView {
            id: list
            anchors { left: parent.left; right: parent.right; top: heading.bottom; topMargin: Theme.du(24); bottom: footer.top; bottomMargin: Theme.du(18) }
            visible: !root.confirming; clip: true; spacing: Theme.du(6)
            model: root.actions; currentIndex: root.selected
            highlightMoveDuration: 0
            Rectangle {
                x: list.width-Theme.du(3)
                y: list.visibleArea.yPosition*list.height
                width: Theme.du(3); height: list.visibleArea.heightRatio*list.height
                visible: list.contentHeight > list.height; color: root.profile.textDim
            }
            onCurrentIndexChanged: positionViewAtIndex(currentIndex,ListView.Contain)
            delegate: Rectangle {
                required property var modelData
                required property int index
                width: list.width; height: Math.max(Theme.du(62), labels.implicitHeight+Theme.du(20))
                color: root.selected === index ? root.profile.surface2 : root.profile.surface
                radius: Theme.radius
                border.width: Theme.border; border.color: root.selected === index ? root.profile.signal : root.profile.grid
                Rectangle { x: 0; y: 0; width: Theme.du(3); height: parent.height; color: modelData.available === true ? root.sensitive(modelData) ? root.profile.caution : root.profile.signal : root.profile.grid }
                Text {
                    x: Theme.du(16); anchors.verticalCenter: parent.verticalCenter
                    text: String(index+1).padStart(2,"0"); textFormat: Text.PlainText
                    color: root.profile.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontSm
                }
                Column {
                    id: labels; x: Theme.du(56); width: parent.width-x-Theme.du(48)
                    anchors.verticalCenter: parent.verticalCenter; spacing: Theme.du(4)
                    Text {
                        width: parent.width; text: modelData.label; textFormat: Text.PlainText; elide: Text.ElideRight
                        color: modelData.available === true ? root.profile.text : root.profile.textDim
                        font.family: Theme.sans; font.pixelSize: Theme.fontLg
                    }
                    Text {
                        width: parent.width; visible: modelData.available !== true
                        text: modelData.reason || "Unavailable"; textFormat: Text.PlainText; wrapMode: Text.Wrap
                        color: root.profile.caution; font.family: Theme.sans; font.pixelSize: Theme.fontMd
                    }
                }
                Text {
                    anchors.right: parent.right; anchors.rightMargin: Theme.du(16); anchors.verticalCenter: parent.verticalCenter
                    text: modelData.available !== true ? "—" : root.sensitive(modelData) ? "!" : "↵"
                    textFormat: Text.PlainText; color: root.sensitive(modelData) ? root.profile.caution : root.profile.signal
                    font.family: Theme.mono; font.pixelSize: Theme.fontMd
                }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true
                    onPositionChanged: root.selected = index
                    onClicked: { root.forceActiveFocus(); root.choose(index); }
                }
                Accessible.role: Accessible.Button; Accessible.name: modelData.label + (modelData.available === true ? "" : ". " + (modelData.reason || "Unavailable"))
                Accessible.onPressAction: root.choose(index)
            }
        }
        Column {
            visible: root.confirming
            anchors { left: parent.left; right: parent.right; top: heading.bottom; topMargin: Theme.du(32) }
            spacing: Theme.du(24)
            Rectangle { width: parent.width; height: Theme.border; color: root.profile.caution }
            Text {
                width: parent.width
                text: "This action changes your current session."
                textFormat: Text.PlainText; wrapMode: Text.Wrap; color: root.profile.caution
                font.family: Theme.mono; font.pixelSize: Theme.fontMd
            }
            Row {
                width: parent.width; spacing: Theme.du(12)
                Repeater {
                    model: ["Go back", root.pending ? root.pending.label : "Confirm"]
                    delegate: Rectangle {
                        required property string modelData
                        required property int index
                        width: (parent.width-Theme.du(12))/2; height: Theme.du(56)
                        color: (index === 1) === root.confirmSelected ? root.profile.surface2 : root.profile.surface
                        radius: Theme.radius
                        border.width: Theme.border
                        border.color: (index === 1) === root.confirmSelected ? (index === 1 ? root.profile.caution : root.profile.signal) : root.profile.grid
                        Text {
                            anchors.fill: parent; anchors.margins: Theme.du(12)
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            text: modelData; textFormat: Text.PlainText; elide: Text.ElideRight
                            color: index === 1 ? root.profile.caution : root.profile.text
                            font.family: Theme.sans; font.pixelSize: Theme.fontLg
                        }
                        MouseArea { anchors.fill: parent; onClicked: { root.forceActiveFocus(); if (index === 1) root.confirm(); else root.back(); } }
                        Accessible.role: Accessible.Button; Accessible.name: modelData
                        Accessible.onPressAction: { if (index === 1) root.confirm(); else root.back(); }
                    }
                }
            }
        }
        Text {
            id: footer; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            text: root.confirming ? "← →  CHOOSE     ↵  ACCEPT     ESC  BACK" : "↑ ↓  SELECT     ↵  CONTINUE     ESC  CANCEL"
            textFormat: Text.PlainText; wrapMode: Text.Wrap
            color: root.profile.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontSm
        }
    }
}
