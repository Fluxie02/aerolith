import QtQuick
import qs.core
import qs.services

Column {
    id: section
    property var profile: Theme
    property string removing: ""
    property string removingName: ""
    property string message: ""
    property bool includeOutputs: false
    property var lifetime: ({alive: true})
    Component.onDestruction: lifetime.alive = false
    readonly property var entries: { Presets.users; Presets.ready; return Presets.list(); }
    signal feedback(string message)
    signal previewRequested(string id)
    signal importRequested(string path)
    signal focused(var item)
    spacing: Theme.du(12)
    function result(error, success) { message = error || success; feedback(error || ""); }
    function fileResult(job, success) {
        const guard = lifetime;
        job.then(error => { if (guard.alive) section.result(error, success); });
    }
    Text { width: parent.width; text: "Preview a preset, then Apply to save or Cancel to restore. Default and Readable are built in. Saving a named preset captures the current draft without applying it."; textFormat: Text.PlainText; wrapMode: Text.Wrap; color: section.profile.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontSm }
    Text { width: parent.width; visible: !Presets.ready || Presets.busy; text: Presets.busy ? "Preset operation in progress…" : "Presets unavailable · " + Presets.error; textFormat: Text.PlainText; wrapMode: Text.Wrap; color: section.profile.caution; font.family: Theme.sans; font.pixelSize: Theme.fontSm }
    Repeater {
        model: section.entries
        Column {
            required property var modelData
            width: section.width; spacing: Theme.du(6)
            Text { width: parent.width; text: parent.modelData.name + (parent.modelData.builtin ? " · Built in" : " · User preset"); textFormat: Text.PlainText; wrapMode: Text.Wrap; color: section.profile.text; font.family: Theme.sans; font.pixelSize: Theme.fontMd }
            Flow {
                width: parent.width; spacing: Theme.du(8)
                property var entry: parent.modelData
                PersonalizeAction { objectName: "presetPreview_" + parent.entry.id; text: "Preview"; profile: section.profile; enabled: Presets.ready && !Presets.busy && !Config.previewApplying; onTriggered: section.previewRequested(parent.entry.id); onFocused: item => section.focused(item) }
                PersonalizeAction { objectName: "presetRemove_" + parent.entry.id; text: "Remove…"; visible: !parent.entry.builtin; profile: section.profile; enabled: !Presets.busy; onTriggered: { section.removing = parent.entry.id; section.removingName = parent.entry.name; Qt.callLater(() => { removeCancel.forceActiveFocus(); section.focused(removeCancel); }); } onFocused: item => section.focused(item) }
            }
        }
    }
    Rectangle {
        width: parent.width; height: visible ? confirmation.implicitHeight + Theme.du(20) : 0; visible: section.removing !== ""
        color: section.profile.bg; border.color: section.profile.caution
        Column {
            id: confirmation; x: Theme.du(10); y: x; width: parent.width - 2*x; spacing: Theme.du(10)
            Text { width: parent.width; text: 'Remove “' + section.removingName + '”? Your current appearance is retained.'; textFormat: Text.PlainText; wrapMode: Text.Wrap; color: section.profile.text; font.family: Theme.sans; font.pixelSize: Theme.fontSm }
            Flow {
                width: parent.width; spacing: Theme.du(8)
                PersonalizeAction { objectName: "presetRemoveConfirm"; profile: section.profile; text: "Remove preset"; enabled: !Presets.busy; onTriggered: { const id = section.removing; section.removing = ""; section.fileResult(Presets.remove(id), "Preset removed"); } onFocused: item => section.focused(item) }
                PersonalizeAction { id: removeCancel; objectName: "presetRemoveCancel"; profile: section.profile; text: "Keep preset"; onTriggered: section.removing = ""; Keys.onEscapePressed: section.removing = ""; onFocused: item => section.focused(item) }
            }
        }
    }
    Text { width: parent.width; text: "SAVE CURRENT"; textFormat: Text.PlainText; color: section.profile.signal; font.family: Theme.mono; font.pixelSize: Theme.fontXs }
    PersonalizeInput { id: name; objectName: "presetName"; profile: section.profile; label: "Preset name"; maximumLength: 80; onFocused: item => section.focused(item) }
    PersonalizeAction { objectName: "presetIncludeOutputs"; profile: section.profile; text: (section.includeOutputs ? "☑ " : "☐ ") + "Include named output overrides"; onTriggered: section.includeOutputs = !section.includeOutputs; onFocused: item => section.focused(item) }
    Text { width: parent.width; text: "Portable by default. Included outputs keep their exact connector names; they are never assigned to another display automatically."; textFormat: Text.PlainText; wrapMode: Text.Wrap; color: section.profile.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontSm }
    PersonalizeAction { objectName: "presetSave"; profile: section.profile; text: "Save named preset"; enabled: Presets.ready && !Presets.busy; onTriggered: section.fileResult(Presets.saveCurrent(name.text, section.includeOutputs), "Preset saved"); onFocused: item => section.focused(item) }
    Text { width: parent.width; text: "IMPORT / EXPORT"; textFormat: Text.PlainText; color: section.profile.signal; font.family: Theme.mono; font.pixelSize: Theme.fontXs }
    Text { width: parent.width; text: "Choose an absolute file path. Import validates and previews appearance settings; a backup is taken before an imported preset is applied. Unknown keys are refused. Export writes the current appearance to the path, replacing an existing preset file."; textFormat: Text.PlainText; wrapMode: Text.Wrap; color: section.profile.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontSm }
    PersonalizeInput { id: path; objectName: "presetPath"; profile: section.profile; label: "/absolute/path/preset.json"; onFocused: item => section.focused(item) }
    Flow {
        width: parent.width; spacing: Theme.du(8)
        PersonalizeAction { objectName: "presetImport"; profile: section.profile; text: "Import preview"; enabled: Presets.ready && !Presets.busy && !Config.previewApplying; onTriggered: section.importRequested(path.text); onFocused: item => section.focused(item) }
        PersonalizeAction { objectName: "presetExport"; profile: section.profile; text: "Export current"; enabled: Presets.ready && !Presets.busy; onTriggered: section.fileResult(Presets.exportFile(path.text, section.includeOutputs), "Preset exported"); onFocused: item => section.focused(item) }
    }
    Text { objectName: "presetMessage"; width: parent.width; text: section.message || Presets.error; textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere; color: section.profile.text; font.family: Theme.sans; font.pixelSize: Theme.fontSm; Accessible.role: Accessible.AlertMessage; Accessible.name: text }
    Text { width: parent.width; visible: Config.previewDirty; text: "PREVIEW CHANGES"; textFormat: Text.PlainText; color: section.profile.signal; font.family: Theme.mono; font.pixelSize: Theme.fontXs }
    Repeater {
        model: Config.preview ? Config.preview.changes : []
        Text { required property var modelData; width: section.width; text: modelData.path.join(".") + " → " + JSON.stringify(modelData.value); textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere; color: section.profile.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs }
    }
}
