import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.components
import qs.services
import "../../lib/config.mjs" as ConfigLib
import "../../lib/tokens.mjs" as Tokens
import "personalize.mjs" as Personalize

FocusScope {
    id: pane
    property var profile: Theme
    property int section: 0
    property bool advanced: false
    property bool specimenExpanded: false
    property string selectedOutput: profile.output || (Ui.overlayScreen ? Ui.overlayScreen.name : Ui.screenName)
    property string feedback: ""
    property string pendingLeave: ""
    property bool leavePending: false
    property bool applyingLeave: false
    property var safetyValues: []
    property bool desktop: false
    property var desktopContent: null
    property real desktopOpacity: 1
    property var caller: null
    readonly property bool compact: width < Theme.du(1000) || height < Theme.du(610)
    readonly property var fields: section === 4 ? Personalize.outputControls(selectedOutput) : Personalize.controls(section)
    readonly property var outputs: {
        const live = Displays.outputs.map(o => ({name: o.name, connected: true}));
        for (const name in Config.display.outputs)
            if (!live.some(o => o.name === name)) live.push({name: name, connected: false});
        return live;
    }
    signal leaveResolved(string destination)

    function begin() { if (!Config.previewActive) feedback = Config.beginPreview(); }
    function valueOf(row) {
        Config.revision;
        const v = ConfigLib.getPath(Config.data, Personalize.pathOf(row.path));
        return v === undefined ? row.default : v;
    }
    function draft(path, value) {
        path = Personalize.pathOf(path);
        if (!Config.previewActive) begin();
        if (!Config.previewActive) return;
        if (path === "theme.palette" || path === "theme.scheme") {
            feedback = Personalize.paletteError(path === "theme.palette" ? value : Config.theme.palette,
                path === "theme.scheme" ? value : Config.theme.scheme, Theme.integratedApps);
            if (feedback) return;
        }
        const previous = ConfigLib.getPath(Config.data, path);
        const error = Config.setPreviewValues([{path: path, value: value}]);
        feedback = error;
        if (!error && Personalize.safetyPath(path) && previous !== value) {
            if (!safetyValues.some(v => JSON.stringify(v.path) === JSON.stringify(path)))
                safetyValues = safetyValues.concat([{path: path, value: previous}]);
            safety.restart();
        }
    }
    function editRole(role, hex, reset) {
        const overrides = Object.assign({}, Config.theme.palette);
        if (reset) delete overrides[role]; else overrides[role] = hex.trim();
        draft("theme.palette", overrides);
    }
    function keepPreview() { safety.stop(); safetyValues = []; }
    function revertSafety() {
        safety.stop();
        if (Config.previewActive && safetyValues.length)
            feedback = Config.setPreviewValues(safetyValues) || "Scale and visibility restored. Other draft changes are retained.";
        safetyValues = [];
    }
    function apply() {
        if (safety.running || Config.previewApplying) return;
        feedback = Personalize.paletteError(Config.theme.palette, Config.theme.scheme, Theme.integratedApps);
        if (feedback) { restoreDesktop(); return; }
        if (Config.previewConflicts.length) {
            feedback = "Configuration changed at " + Config.previewConflicts.join(", ") + ". Cancel to reload saved values, then review your changes.";
            restoreDesktop();
            return;
        }
        feedback = Config.applyPreview();
        if (feedback) restoreDesktop();
    }
    function discard() {
        restoreDesktop(); keepPreview();
        applyingLeave = false;
        if (Config.previewActive) Config.cancelPreview();
        feedback = ""; leavePending = false;
    }
    function requestLeave(destination) {
        restoreDesktop();
        if (Config.previewApplying) { feedback = "Wait for Apply to finish."; return; }
        if (Config.previewDirty) {
            if (!leavePending) caller = pane.Window.window ? pane.Window.window.activeFocusItem : null;
            pendingLeave = destination; leavePending = true;
            Qt.callLater(() => { if (pane.leavePending) keepEditing.forceActiveFocus(); });
        } else { discard(); leaveResolved(destination); }
    }
    function discardAndLeave() { const destination = pendingLeave; discard(); leaveResolved(destination); }
    function applyAndLeave() { applyingLeave = true; apply(); if (feedback) applyingLeave = false; }
    function keepEditingDraft() {
        if (Config.previewApplying) return;
        leavePending = false;
        const target = caller;
        Qt.callLater(() => {
            if (target && target.visible && target.enabled) target.forceActiveFocus(); else pane.forceActiveFocus();
        });
        caller = null;
    }
    function finishApplyLeave() { applyingLeave = false; leavePending = false; leaveResolved(pendingLeave); }
    function viewDesktop() {
        // Visual-only suppression of this Deck's content. The independent bar
        // stays mapped; host lifecycle, input policy and demand are unchanged.
        if (!pane.Window.window) return;
        desktopContent = pane.Window.window.contentItem;
        desktopOpacity = desktopContent.opacity;
        desktopContent.opacity = 0;
        desktop = true;
    }
    function restoreDesktop() {
        desktop = false;
        if (desktopContent) desktopContent.opacity = desktopOpacity;
        desktopContent = null;
    }
    Component.onDestruction: restoreDesktop()
    Connections {
        target: Config
        function onPreviewErrorChanged() { if (Config.previewError && pane.desktop) pane.restoreDesktop(); }
        function onPreviewActiveChanged() {
            if (Config.previewActive) return;
            pane.keepPreview(); pane.restoreDesktop();
            if (pane.applyingLeave && !Config.previewApplying) pane.finishApplyLeave();
        }
        function onPreviewApplyingChanged() {
            if (!Config.previewApplying && pane.applyingLeave) {
                if (!Config.previewActive) pane.finishApplyLeave();
                else pane.applyingLeave = false;
            }
        }
    }
    Connections { target: Ui; function onLockedChanged() { if (Ui.locked) pane.discard(); } }
    Timer { id: safety; interval: 20000; repeat: false; onTriggered: pane.revertSafety() }
    DisplayProfile { id: specimenProfile; output: pane.selectedOutput }

    Bezel {
        enabled: !pane.leavePending
        anchors.fill: parent; profile: pane.profile
        designation: "PERSONALIZE"; title: "Make it yours"
        status: Config.previewApplying ? "APPLYING" : Config.previewDirty ? "UNSAVED PREVIEW" : "SAVED BASELINE"
        statusColor: Config.previewDirty ? pane.profile.caution : pane.profile.signal
        Rectangle { anchors.fill: parent; color: pane.profile.surface; z: -1 }
        Column {
            id: layout
            anchors.fill: parent; anchors.bottomMargin: footer.height + Theme.du(12)
            spacing: Theme.du(12); clip: true
            Text {
                width: parent.width
                text: "Preview across your desktop. Apply saves once and refreshes consented application themes."
                textFormat: Text.PlainText; wrapMode: Text.WordWrap
                color: pane.profile.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontSm
            }
            Flow {
                id: compactRail
                visible: pane.compact; width: parent.width; spacing: Theme.du(6)
                Repeater {
                    model: Personalize.SECTIONS
                    PersonalizeAction {
                        required property string modelData; required property int index
                        objectName: "personalizeCompactSection_" + index
                        profile: pane.profile; text: modelData; chosen: index === pane.section; enabled: index < 5
                        onTriggered: { pane.section = index; scroll.contentY = 0; }
                    }
                }
            }
            Item {
                id: body
                width: parent.width
                height: Math.max(0, layout.height - y - (feedbackBox.visible ? feedbackBox.height + layout.spacing : 0) - (safetyBar.visible ? safetyBar.height + layout.spacing : 0))
                Column {
                    id: rail
                    visible: !pane.compact; width: visible ? Theme.du(176) : 0; height: parent.height; spacing: Theme.du(6)
                    Repeater {
                        model: Personalize.SECTIONS
                        PersonalizeAction {
                            required property string modelData; required property int index
                            objectName: "personalizeSection_" + index
                            width: rail.width; profile: pane.profile; text: modelData; chosen: index === pane.section; enabled: index < 5
                            onTriggered: { pane.section = index; scroll.contentY = 0; }
                        }
                    }
                    Text {
                        width: parent.width; text: "PRESETS\nComing in the next update"; textFormat: Text.PlainText
                        wrapMode: Text.WordWrap; color: pane.profile.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontSm; lineHeight: 1.4
                    }
                }
                Flickable {
                    id: scroll; objectName: "personalizeScroll"
                    x: pane.compact ? 0 : rail.width + Theme.du(20)
                    width: Math.max(0, parent.width - x - (pane.compact ? 0 : Theme.du(320)))
                    height: parent.height; clip: true; contentWidth: width; contentHeight: registerColumn.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    function reveal(item) {
                        const p = item.mapToItem(registerColumn, 0, 0);
                        if (p.y < contentY) contentY = p.y;
                        else if (p.y + item.height > contentY + height)
                            contentY = Math.min(Math.max(0, contentHeight - height), p.y + item.height - height);
                    }
                    Column {
                        id: registerColumn
                        width: scroll.width; spacing: Theme.du(10)
                        PersonalizeAction {
                            visible: pane.compact; height: visible ? implicitHeight : 0
                            profile: pane.profile; text: "Specimen · " + pane.selectedOutput + (pane.specimenExpanded ? " / Hide" : " / Show")
                            onFocused: item => scroll.reveal(item)
                            onTriggered: pane.specimenExpanded = !pane.specimenExpanded
                        }
                        Loader { width: parent.width; active: pane.compact && pane.specimenExpanded; height: active ? Theme.du(320) : 0; sourceComponent: specimen }
                        Text {
                            width: parent.width; text: Personalize.SECTIONS[pane.section].toUpperCase()
                            textFormat: Text.PlainText; color: pane.profile.signal; font.family: Theme.mono; font.pixelSize: Theme.fontXs; font.letterSpacing: 1.5
                        }
                        SchemePicker {
                            id: personalSpectra
                            objectName: "personalizeSchemes"
                            width: parent.width
                            height: visible ? Math.min(Theme.du(650), Math.max(Theme.du(pane.compact ? 310 : 350), body.height - Theme.du(70))) : 0
                            visible: pane.section === 0; profile: pane.profile; embedded: true
                            activeFocusOnTab: true
                            onActiveFocusChanged: if (activeFocus) scroll.reveal(personalSpectra)
                            onPicked: scheme => pane.draft("theme.scheme", scheme)
                            onRegisterRequested: advancedAction.forceActiveFocus()
                        }
                        PersonalizeAction {
                            id: advancedAction; objectName: "personalizeAdvanced"
                            visible: pane.section === 0; height: visible ? implicitHeight : 0
                            profile: pane.profile; text: pane.advanced ? "− Advanced palette roles" : "+ Advanced palette roles"
                            onFocused: item => scroll.reveal(item)
                            onTriggered: { pane.advanced = !pane.advanced; scroll.reveal(advancedAction); }
                        }
                        Text {
                            visible: pane.section === 0 && pane.advanced; width: parent.width
                            text: "Opaque #RRGGBB overrides. Reset restores the scheme role. All text roles must pass 4.5:1 on normal, selected and tinted fills in standard, black and OLED profiles. Link colour is derived."
                            textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: pane.profile.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontSm
                        }
                        Repeater {
                            model: pane.section === 0 && pane.advanced ? Personalize.ROLES : []
                            Rectangle {
                                id: paletteRow
                                required property string modelData
                                objectName: "paletteRole_" + modelData
                                width: registerColumn.width; height: Theme.du(68)
                                color: pane.profile.surface; border.color: hex.activeFocus ? pane.profile.signal : pane.profile.grid; radius: Theme.du(4)
                                Rectangle {
                                    x: Theme.du(12); anchors.verticalCenter: parent.verticalCenter; width: Theme.du(26); height: width
                                    color: Tokens.resolvePalette(Config.theme.palette, Config.theme.scheme)[paletteRow.modelData]; border.color: pane.profile.textDim; radius: Theme.du(3)
                                }
                                Text {
                                    x: Theme.du(48); width: Math.max(0, hex.x - x - Theme.du(8)); anchors.verticalCenter: parent.verticalCenter
                                    text: paletteRow.modelData; textFormat: Text.PlainText; elide: Text.ElideRight; color: pane.profile.text; font.family: Theme.sans; font.pixelSize: Theme.fontSm
                                }
                                TextInput {
                                    id: hex; objectName: "paletteHex_" + paletteRow.modelData
                                    x: Math.max(Theme.du(100), parent.width - Theme.du(200)); width: Theme.du(110); height: Theme.du(36); anchors.verticalCenter: parent.verticalCenter
                                    text: Tokens.resolvePalette(Config.theme.palette, Config.theme.scheme)[paletteRow.modelData]
                                    color: pane.profile.text; font.family: Theme.mono; font.pixelSize: Theme.fontMd
                                    verticalAlignment: TextInput.AlignVCenter; leftPadding: Theme.du(8); clip: true; maximumLength: 9
                                    selectByMouse: true; activeFocusOnTab: true
                                    selectionColor: pane.profile.signal; selectedTextColor: pane.profile.bg
                                    onActiveFocusChanged: if (activeFocus) { selectAll(); scroll.reveal(paletteRow); }
                                    Keys.onReturnPressed: pane.editRole(paletteRow.modelData, text, false)
                                    Keys.onEnterPressed: pane.editRole(paletteRow.modelData, text, false)
                                    Keys.onEscapePressed: { text = Tokens.resolvePalette(Config.theme.palette, Config.theme.scheme)[paletteRow.modelData]; advancedAction.forceActiveFocus(); }
                                    Rectangle { anchors.fill: parent; z: -1; color: pane.profile.bg; border.color: hex.activeFocus ? pane.profile.signal : pane.profile.grid; radius: Theme.du(3) }
                                    Accessible.name: paletteRow.modelData + " hex colour; Enter to preview"
                                }
                                PersonalizeAction {
                                    anchors.right: parent.right; anchors.rightMargin: Theme.du(8); anchors.verticalCenter: parent.verticalCenter
                                    text: "Reset"; profile: pane.profile
                                    onFocused: item => scroll.reveal(paletteRow)
                                    onTriggered: { pane.editRole(paletteRow.modelData, "", true); hex.text = Tokens.resolvePalette(Config.theme.palette, Config.theme.scheme)[paletteRow.modelData]; }
                                }
                            }
                        }
                        PersonalizeAction {
                            visible: pane.section === 0 && pane.advanced
                            text: "Reset all palette overrides"; profile: pane.profile
                            onFocused: item => scroll.reveal(item)
                            onTriggered: pane.draft("theme.palette", {})
                        }
                        Flow {
                            width: parent.width; spacing: Theme.du(6); visible: pane.section === 4; height: visible ? implicitHeight : 0
                            Repeater {
                                model: pane.outputs
                                PersonalizeAction {
                                    required property var modelData
                                    objectName: "personalizeOutput_" + modelData.name
                                    profile: pane.profile; text: modelData.name + (modelData.connected ? "" : " · disconnected"); chosen: pane.selectedOutput === modelData.name
                                    onFocused: item => scroll.reveal(item)
                                    onTriggered: pane.selectedOutput = modelData.name
                                }
                            }
                        }
                        Text {
                            visible: pane.section === 4; width: parent.width
                            text: "Schemes, type and motion are global. Profile follows this named output. Resolution and refresh rate belong to your system display settings."
                            textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: pane.profile.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontSm
                        }
                        Repeater {
                            model: pane.fields
                            PersonalizeField {
                                required property var modelData
                                objectName: "personalizeField_" + (typeof modelData.path === "string" ? modelData.path : Personalize.pathOf(modelData.path).join("_"))
                                profile: pane.profile; setting: modelData; value: pane.valueOf(modelData)
                                writable: ConfigLib.previewAllowed(Personalize.pathOf(modelData.path))
                                onChanged: value => pane.draft(modelData.path, value)
                                onFocused: item => scroll.reveal(item)
                            }
                        }
                        Text {
                            visible: pane.section === 1; width: parent.width
                            text: "Font sample / The quick brown fox 0123456789\n" + Theme.sans + " · " + Theme.mono + "\nFonts use the shell’s fallback families when unavailable."
                            textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: pane.profile.text; font.family: Theme.sans; font.pixelSize: Theme.fontMd; lineHeight: 1.5
                        }
                        PersonalizeAction {
                            visible: pane.section === 2; height: visible ? implicitHeight : 0
                            text: "Play transition"; profile: pane.profile
                            onFocused: item => scroll.reveal(item)
                            onTriggered: { scroll.reveal(transitionStage); transitionSample.x = 0; transitionSample.opacity = .3; sampleMotion.restart(); }
                        }
                        Item {
                            id: transitionStage
                            visible: pane.section === 2; height: visible ? Theme.du(42) : 0; width: parent.width
                            Rectangle { id: transitionSample; x: Theme.du(80); width: Theme.du(80); height: Theme.du(24); color: pane.profile.signal; radius: Theme.du(3) }
                            ParallelAnimation {
                                id: sampleMotion
                                NumberAnimation { target: transitionSample; property: "x"; to: Theme.du(80); duration: Theme.travel ? Theme.normal : 0; easing.type: Easing.OutCubic }
                                NumberAnimation { target: transitionSample; property: "opacity"; to: 1; duration: Theme.animate ? Theme.normal : 0 }
                            }
                        }
                        Text {
                            visible: pane.compact; width: parent.width
                            text: "Presets · Coming in the next update"; textFormat: Text.PlainText
                            color: pane.profile.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontSm
                        }
                    }
                    ScrollMark { profile: pane.profile; viewport: scroll }
                }
                Loader { anchors.right: parent.right; width: Theme.du(300); height: parent.height; active: !pane.compact; sourceComponent: specimen }
            }
            Rectangle {
                id: safetyBar
                width: parent.width; visible: safety.running; height: visible ? safetyContent.implicitHeight + Theme.du(16) : 0
                color: pane.profile.bg; border.color: pane.profile.caution; radius: Theme.du(4)
                Flow {
                    id: safetyContent; x: Theme.du(8); y: Theme.du(8); width: parent.width - 2 * x; spacing: Theme.du(8)
                    PersonalizeAction { objectName: "personalizeKeepPreview"; profile: pane.profile; text: "Keep preview"; onTriggered: pane.keepPreview() }
                    PersonalizeAction { profile: pane.profile; text: "Revert scale / visibility"; onTriggered: pane.revertSafety() }
                    Text { height: Theme.du(36); verticalAlignment: Text.AlignVCenter; text: "Reverts after 20 seconds"; textFormat: Text.PlainText; color: pane.profile.caution; font.family: Theme.sans; font.pixelSize: Theme.fontSm }
                }
            }
            Rectangle {
                id: feedbackBox
                width: parent.width; visible: feedbackLabel.text !== ""; height: visible ? feedbackLabel.implicitHeight + Theme.du(16) : 0
                color: pane.profile.bg; border.color: pane.profile.critical; radius: Theme.du(4)
                Text {
                    id: feedbackLabel; objectName: "personalizeFeedback"
                    x: Theme.du(10); y: Theme.du(8); width: parent.width - 2 * x
                    text: pane.feedback || Config.previewError || (Config.previewConflicts.length ? "External changes: " + Config.previewConflicts.join(", ") + ". Cancel to reload and review." : "")
                    textFormat: Text.PlainText; wrapMode: Text.WrapAnywhere; color: pane.profile.text; font.family: Theme.sans; font.pixelSize: Theme.fontSm
                    Accessible.role: Accessible.AlertMessage; Accessible.name: text
                }
            }
        }
        Row {
            id: footer
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            spacing: Theme.du(8)
            PersonalizeAction { objectName: "personalizeApply"; text: Config.previewApplying ? "Applying…" : "Apply"; profile: pane.profile; enabled: Config.previewDirty && !Config.previewApplying && !safety.running && !Config.previewConflicts.length; onTriggered: pane.apply() }
            PersonalizeAction { objectName: "personalizeCancel"; text: "Cancel"; profile: pane.profile; enabled: !Config.previewApplying; onTriggered: { pane.discard(); pane.begin(); } }
            PersonalizeAction { objectName: "personalizeDesktop"; text: "View desktop"; profile: pane.profile; enabled: !Config.previewApplying; onTriggered: pane.viewDesktop() }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "Tab / focus · Arrows / change · Esc / leave"; visible: !pane.compact; textFormat: Text.PlainText; color: pane.profile.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs }
        }
    }
    Component {
        id: specimen
        Rectangle {
            id: specimenCard
            color: specimenProfile.bg; border.color: pane.profile.grid; radius: Theme.du(4)
            Column {
                anchors.fill: parent; anchors.margins: Theme.du(18); spacing: Theme.du(14)
                Text { width: parent.width; text: "SPECIMEN / " + pane.selectedOutput + " / " + specimenProfile.profile.toUpperCase(); textFormat: Text.PlainText; elide: Text.ElideRight; color: specimenProfile.signal; font.family: Theme.mono; font.pixelSize: Theme.fontXs }
                Text { width: parent.width; text: "Your desktop,\nyour bearings."; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: specimenProfile.text; font.family: Theme.sans; font.pixelSize: Theme.fontXl; font.weight: Font.Light }
                Text { width: parent.width; text: "Body text · 0123456789\nSecondary inscription"; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: specimenProfile.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontMd; lineHeight: 1.5 }
                Rectangle {
                    width: parent.width; height: Theme.du(40); color: specimenProfile.surface2; border.color: specimenProfile.signal; radius: Theme.du(4)
                    Text { anchors.centerIn: parent; text: "✓  Selected row"; textFormat: Text.PlainText; color: specimenProfile.text; font.family: Theme.sans; font.pixelSize: Theme.fontMd }
                }
                Row {
                    width: parent.width; spacing: Theme.du(16)
                    Text { text: "!  Attention"; textFormat: Text.PlainText; color: specimenProfile.caution; font.family: Theme.mono; font.pixelSize: Theme.fontSm }
                    Text { text: "×  Error"; textFormat: Text.PlainText; color: specimenProfile.critical; font.family: Theme.mono; font.pixelSize: Theme.fontSm }
                }
                Rectangle {
                    visible: !pane.compact; width: parent.width; height: Theme.du(70); color: specimenProfile.surface; radius: Theme.du(4)
                    Text { anchors.fill: parent; anchors.margins: Theme.du(12); text: "STATUS STRIP    14:32\nWorkspace 01 / Research"; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: specimenProfile.text; font.family: Theme.mono; font.pixelSize: Theme.fontSm; lineHeight: 1.6 }
                }
                Text { visible: !pane.compact && specimenCard.height >= Theme.du(430); width: parent.width; text: "Preview is in memory. External themes change only after Apply."; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: specimenProfile.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontSm; lineHeight: 1.5 }
            }
        }
    }
    Rectangle {
        id: leaveDialog; objectName: "personalizeLeaveDialog"
        anchors.fill: parent; z: 20; visible: pane.leavePending
        color: pane.profile.surface; border.color: pane.profile.caution; radius: Theme.radius
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) pane.keepEditingDraft();
            else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                const actions = [leaveApply, leaveDiscard, keepEditing].filter(a => a.enabled);
                const current = actions.findIndex(a => a.activeFocus);
                const direction = event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1;
                actions[(current + direction + actions.length) % actions.length].forceActiveFocus();
            } else return;
            event.accepted = true;
        }
        MouseArea { anchors.fill: parent }
        Column {
            width: Math.min(parent.width - Theme.du(48), Theme.du(500)); anchors.centerIn: parent; spacing: Theme.du(18)
            Text { width: parent.width; text: "Keep your changes?"; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: pane.profile.text; font.family: Theme.sans; font.pixelSize: Theme.fontXl }
            Text { width: parent.width; text: "Your desktop is showing an unsaved preview. Apply saves it; Discard restores the saved desktop."; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: pane.profile.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontMd }
            Flow {
                width: parent.width; spacing: Theme.du(8)
                PersonalizeAction { id: leaveApply; objectName: "personalizeLeaveApply"; text: "Apply"; profile: pane.profile; enabled: !safety.running && !Config.previewApplying && !Config.previewConflicts.length; tabNext: leaveDiscard; tabPrevious: keepEditing; onTriggered: pane.applyAndLeave() }
                PersonalizeAction { id: leaveDiscard; objectName: "personalizeLeaveDiscard"; text: "Discard"; profile: pane.profile; enabled: !Config.previewApplying; tabNext: keepEditing; tabPrevious: leaveApply.enabled ? leaveApply : keepEditing; onTriggered: pane.discardAndLeave() }
                PersonalizeAction { id: keepEditing; objectName: "personalizeKeepEditing"; text: "Keep editing"; profile: pane.profile; enabled: !Config.previewApplying; tabNext: leaveApply.enabled ? leaveApply : leaveDiscard; tabPrevious: leaveDiscard; onTriggered: pane.keepEditingDraft(); Keys.onEscapePressed: pane.keepEditingDraft() }
            }
            Text { width: parent.width; text: pane.feedback || Config.previewError; visible: text !== ""; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: pane.profile.critical; font.family: Theme.sans; font.pixelSize: Theme.fontSm }
            Text { width: parent.width; visible: safety.running; text: "Keep or revert the scale / visibility preview before applying."; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: pane.profile.caution; font.family: Theme.sans; font.pixelSize: Theme.fontSm }
        }
    }
    // Constructed only for an explicit desktop inspection, never while closed.
    Loader {
        active: pane.desktop
        sourceComponent: Component {
            PanelWindow {
                screen: Ui.overlayScreen; color: "transparent"
                anchors { top: true; bottom: true; left: true; right: true }
                exclusionMode: ExclusionMode.Ignore
                WlrLayershell.namespace: "aerolith-personalize-preview"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
                // Inspection owns pointer input too: a click on the revealed
                // desktop cannot accidentally dismiss the hidden Deck draft.
                MouseArea { anchors.fill: parent }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.du(12) + (Config.strip.edge === "bottom" ? Theme.stripHeight : 0)
                    width: Math.min(parent.width - Theme.du(32), Theme.du(660)); height: Theme.du(58)
                    color: pane.profile.bg; border.color: pane.profile.signal; radius: Theme.du(4)
                    Row {
                        anchors.centerIn: parent; spacing: Theme.du(12)
                        PersonalizeAction { objectName: "personalizeReturn"; text: "Return to Personalize"; profile: pane.profile; focus: true; onTriggered: { pane.restoreDesktop(); pane.forceActiveFocus(); } }
                        PersonalizeAction { text: "Apply"; profile: pane.profile; enabled: Config.previewDirty && !safety.running && !Config.previewApplying && !Config.previewConflicts.length; onTriggered: pane.apply() }
                        PersonalizeAction { text: "Cancel"; profile: pane.profile; enabled: !Config.previewApplying; onTriggered: { pane.discard(); pane.begin(); } }
                        PersonalizeAction { visible: safety.running; text: "Keep preview"; profile: pane.profile; onTriggered: pane.keepPreview() }
                    }
                    Keys.onEscapePressed: { pane.restoreDesktop(); pane.forceActiveFocus(); }
                }
            }
        }
    }
}
