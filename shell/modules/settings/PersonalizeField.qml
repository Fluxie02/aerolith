import QtQuick
import qs.core
import "personalize.mjs" as Personalize

FocusScope {
    id: field
    property var profile: Theme
    required property var setting
    required property var value
    property bool writable: true
    property bool editing: false
    readonly property bool fontPicker: setting.path === "theme.fontSans" || setting.path === "theme.fontMono"
    readonly property real rowHeight: Math.max(Theme.du(92), labels.implicitHeight + Theme.du(26), control.implicitHeight + Theme.du(28))
    signal changed(var value)
    signal focused(var item)
    width: parent.width
    height: rowHeight + (editing && fontPicker ? Theme.du(144) : 0)
    activeFocusOnTab: writable
    onActiveFocusChanged: if (activeFocus) focused(field)
    onFocusChanged: if (!focus) editing = false
    onVisibleChanged: if (!visible) editing = false
    function change(direction) { if (writable && setting.type !== "string") changed(Personalize.step(setting, value, direction)); }
    function edit() {
        editing = true; input.text = String(value);
        Qt.callLater(() => {
            if (!field.editing) return;
            input.forceActiveFocus(); input.selectAll(); field.focused(field);
        });
    }
    function commit() {
        changed(fontPicker && families.currentIndex >= 0 ? families.model[families.currentIndex] : input.text);
        editing = false; field.forceActiveFocus();
    }
    Keys.onPressed: event => {
        if (editing || !writable) return;
        if (event.key === Qt.Key_Right) change(1);
        else if (event.key === Qt.Key_Left) change(-1);
        else if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].indexOf(event.key) >= 0) {
            if (setting.type === "string") edit(); else change(1);
        } else if (event.key === Qt.Key_Down) { nextItemInFocusChain().forceActiveFocus(); }
        else if (event.key === Qt.Key_Up) { nextItemInFocusChain(false).forceActiveFocus(); }
        else return;
        event.accepted = true;
    }
    Rectangle {
        anchors.fill: parent
        color: field.activeFocus ? field.profile.surface2 : field.profile.surface
        border.color: field.activeFocus ? field.profile.signal : field.profile.grid
        border.width: Theme.border; radius: Theme.du(4)
        Rectangle { visible: field.activeFocus; width: Theme.du(3); height: parent.height - Theme.du(16); y: Theme.du(8); color: field.profile.signal }
    }
    MouseArea { anchors.fill: parent; onClicked: field.forceActiveFocus() }
    Column {
        id: labels
        x: Theme.du(14); width: parent.width * .48 - x; y: (field.rowHeight - height) / 2
        spacing: Theme.du(6)
        Text { width: parent.width; text: field.setting.label; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: field.profile.text; font.family: Theme.sans; font.pixelSize: Theme.fontMd }
        Text { width: parent.width; text: field.writable ? field.setting.description : "Preview support is pending. The global visibility switch must also be on."; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: field.profile.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontSm }
    }
    SettingControl {
        id: control
        x: parent.width * .52; width: parent.width - x - Theme.du(14); height: implicitHeight; y: (field.rowHeight - height) / 2
        profile: field.profile; setting: field.setting; value: field.value
        selected: field.activeFocus; editing: field.editing; draft: input.text
        enabled: field.writable
        onStepped: direction => { field.forceActiveFocus(); field.change(direction); }
        onChoicePicked: value => { field.forceActiveFocus(); field.changed(value); }
        onEditRequested: field.edit()
    }
    TextInput {
        id: input
        objectName: "personalizeEditor_" + field.setting.path
        x: control.x; y: control.y; width: control.width; height: control.height
        visible: field.editing; enabled: field.editing
        color: field.profile.text; selectionColor: field.profile.signal; selectedTextColor: field.profile.bg
        font.family: Theme.sans; font.pixelSize: Theme.fontMd
        clip: true; selectByMouse: true; maximumLength: 128
        Rectangle { anchors.fill: parent; color: field.profile.bg; z: -1; border.color: field.profile.signal }
        Keys.onReturnPressed: field.commit()
        Keys.onEnterPressed: field.commit()
        Keys.onDownPressed: if (field.fontPicker) families.incrementCurrentIndex()
        Keys.onUpPressed: if (field.fontPicker) families.decrementCurrentIndex()
        Keys.onEscapePressed: { field.editing = false; field.forceActiveFocus(); }
        onTextChanged: families.currentIndex = -1
        onFocusChanged: if (!focus) field.editing = false
        Accessible.name: field.setting.label
    }
    ListView {
        id: families
        objectName: "personalizeFonts_" + field.setting.path
        visible: field.editing && field.fontPicker
        x: control.x; y: field.rowHeight; width: control.width; height: Theme.du(132)
        clip: true; currentIndex: -1; boundsBehavior: Flickable.StopAtBounds
        model: field.fontPicker ? Theme.installedFontFamilies.filter(name => name.toLowerCase().indexOf(input.text.toLowerCase()) >= 0) : []
        delegate: Rectangle {
            required property string modelData
            required property int index
            width: families.width; height: Theme.du(32)
            color: index === families.currentIndex ? field.profile.surface2 : field.profile.bg
            Text { anchors.fill: parent; anchors.margins: Theme.du(6); text: modelData; textFormat: Text.PlainText; elide: Text.ElideRight; color: field.profile.text; font.family: modelData; font.pixelSize: Theme.fontSm }
            MouseArea { anchors.fill: parent; onClicked: { field.changed(modelData); field.editing = false; field.forceActiveFocus(); } }
        }
        Text { visible: families.count === 0; width: parent.width; text: "No installed match. Enter keeps this fallback name."; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: field.profile.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontSm }
    }
    Accessible.role: Accessible.Grouping
    Accessible.name: setting.label + ": " + String(value)
}
