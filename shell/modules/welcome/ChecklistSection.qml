import QtQuick
import qs.core
import qs.services

WelcomeSection {
    id: section
    heading: "FIRST-RUN CHECKLIST"
    signal actionRequested(var entry)
    signal focused(var item)
    Repeater {
        model: Welcome.checklist
        Column {
            id: row
            required property var modelData
            width: section.width; spacing: Theme.du(5)
            Text {
                objectName: "welcomeCheck_" + row.modelData.id
                width: parent.width
                text: (row.modelData.state === "passed" ? "✓  Passed" : row.modelData.state === "attention" ? "!  Needs attention" : "?  Unknown") + " · " + row.modelData.label
                textFormat: Text.PlainText; wrapMode: Text.Wrap
                color: row.modelData.state === "passed" ? section.profile.nominal : row.modelData.state === "attention" ? section.profile.caution : section.profile.textDim
                font.family: Theme.sans; font.pixelSize: Theme.fontSm
            }
            WelcomeText { profile: section.profile; text: row.modelData.detail }
            WelcomeAction {
                objectName: "welcomeCheckAction_" + row.modelData.id
                profile: section.profile
                enabled: row.modelData.id !== "tour" || (!Config.previewDirty && !Config.previewApplying)
                text: row.modelData.id === "startup" ? "Review startup" : row.modelData.id === "tour" ? "Take tour" : row.modelData.id === "output" ? "Review displays" : "Review configuration"
                onTriggered: section.actionRequested(row.modelData)
                onFocused: item => section.focused(item)
            }
        }
    }
}
