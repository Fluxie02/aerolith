import QtQuick
import qs.core
import "../../lib/config.mjs" as ConfigLib

Column {
    id: names
    property var profile: Theme
    signal changed(var path, var value)
    signal focused(var item)
    spacing: Theme.du(10)
    readonly property var ids: {
        const result = Object.keys(Config.data.workspaces.names);
        for (let i = 1; i <= Config.strip.workspaceCount; i++) if (result.indexOf(String(i)) < 0) result.push(String(i));
        return result.sort((a,b) => Number(a) - Number(b));
    }
    Text { width: parent.width; text: "WORKSPACE NAMES"; textFormat: Text.PlainText; color: names.profile.signal; font.family: Theme.mono; font.pixelSize: Theme.fontXs }
    Text { width: parent.width; text: "Enter a name, then press Enter to preview. Apply saves. IDs stay fixed; an empty name restores its number."; textFormat: Text.PlainText; wrapMode: Text.Wrap; color: names.profile.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontSm }
    Repeater {
        model: names.ids
        Column {
            required property string modelData
            width: names.width; spacing: Theme.du(4)
            Text { width: parent.width; text: "Workspace " + parent.modelData; textFormat: Text.PlainText; color: names.profile.text; font.family: Theme.sans; font.pixelSize: Theme.fontSm }
            PersonalizeInput {
                objectName: "workspaceName_" + parent.modelData
                profile: names.profile; label: "Workspace " + parent.modelData + " name"; maximumLength: ConfigLib.schemaAt(["workspaces", "names", parent.modelData]).maxLength
                text: Config.data.workspaces.names[parent.modelData] || ""
                onAccepted: names.changed(["workspaces", "names", parent.modelData], text)
                onFocused: item => names.focused(item)
                Keys.onEscapePressed: { text = Config.data.workspaces.names[parent.modelData] || ""; names.forceActiveFocus(); }
            }
        }
    }
    Text { width: parent.width; text: "Another workspace ID"; textFormat: Text.PlainText; color: names.profile.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontSm }
    PersonalizeInput { id: extraId; objectName: "workspaceExtraId"; profile: names.profile; label: "Positive workspace ID"; maximumLength: 9; validator: RegularExpressionValidator { regularExpression: /[1-9][0-9]{0,8}/ } onFocused: item => names.focused(item) }
    PersonalizeInput { id: extraName; objectName: "workspaceExtraName"; profile: names.profile; label: "Workspace name"; maximumLength: 48; onFocused: item => names.focused(item) }
    PersonalizeAction { objectName: "workspaceAddName"; profile: names.profile; text: "Preview workspace name"; enabled: extraId.acceptableInput; onTriggered: names.changed(["workspaces", "names", extraId.text], extraName.text); onFocused: item => names.focused(item) }
}
