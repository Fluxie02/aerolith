import QtQuick
import qs.core

// Two views of one schema: staged appearance and the immediate-save register.
FocusScope {
    id: bay
    property var profile: Theme
    property bool active: true
    property bool personalizing: true
    signal leaveResolved(string destination)
    function requestLeave(destination) {
        if (!personalizing) return true;
        personal.requestLeave(destination);
        return false;
    }
    readonly property var rows: allSettings.rows
    function change(row, direction) { allSettings.change(row, direction); }
    function showPersonalize() { personalizing = true; personal.begin(); personal.forceActiveFocus(); }
    function showAllSettings() { personal.requestLeave("all"); }
    function completeLeave(destination) {
        if (destination.indexOf("deck:") === 0) {
            bay.leaveResolved(destination);
            return;
        }
        if (destination === "all") { personalizing = false; allSettings.forceActiveFocus(); }
        else if (destination === "close") Ui.close();
        else Ui.open(destination);
    }
    Component.onCompleted: if (active && Ui.activeBay === "settings") { personal.section = SettingsEntry.section; personal.begin(); }
    Connections {
        target: SettingsEntry
        function onPersonalizeRequested(targetSection) {
            if (!bay.active) return;
            bay.showPersonalize();
            personal.section = targetSection;
        }
    }
    // Host-forced retirement/lock/output loss cannot leave an orphan draft.
    onActiveChanged: if (!active) personal.discard()
    Component.onDestruction: personal.discard()
    Keys.onPressed: event => {
        if (!personalizing) return;
        if (event.key === Qt.Key_Escape) personal.requestLeave("close");
        else if (event.key === Qt.Key_F1) personal.requestLeave("help");
        else if ((event.modifiers & Qt.ControlModifier) && event.key >= Qt.Key_1 && event.key <= Qt.Key_6)
            personal.requestLeave(["command", "navigator", "systems", "signal", "routines", "ai"][event.key - Qt.Key_1]);
        else return;
        event.accepted = true;
    }
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, Theme.du(1120)); height: parent.height
        Row {
            id: modes; width: parent.width; spacing: Theme.du(8); enabled: !personal.leavePending
            PersonalizeAction { objectName: "personalizeMode"; profile: bay.profile; text: "Personalize"; chosen: bay.personalizing; onTriggered: if (!bay.personalizing) bay.showPersonalize() }
            PersonalizeAction { objectName: "allSettingsMode"; profile: bay.profile; text: "All settings"; chosen: !bay.personalizing; onTriggered: if (bay.personalizing) bay.showAllSettings() }
        }
        PersonalizePane {
            id: personal; objectName: "personalizePane"
            anchors { left: parent.left; right: parent.right; top: modes.bottom; topMargin: Theme.du(8); bottom: parent.bottom }
            profile: bay.profile; visible: bay.personalizing; enabled: visible; focus: visible
            onLeaveResolved: destination => bay.completeLeave(destination)
        }
        AllSettings {
            id: allSettings
            anchors { left: parent.left; right: parent.right; top: modes.bottom; topMargin: Theme.du(8); bottom: parent.bottom }
            profile: bay.profile; visible: !bay.personalizing; active: bay.active && visible; enabled: visible
        }
    }
}
