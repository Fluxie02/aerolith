import QtQuick
import qs.core
import qs.services

WelcomeSection {
    id: section
    heading: "TROUBLESHOOTING"
    property bool reportVisible: false
    property string copyState: ""
    signal focused(var item)
    Repeater {
        model: Welcome.info.configErrors.concat(Welcome.info.configWarnings)
        WelcomeText {
            required property var modelData
            required property int index
            objectName: "welcomeConfigIssue_" + index
            profile: section.profile; color: profile.caution
            text: modelData.path + ": " + modelData.message + " · Review in Settings / All settings."
        }
    }
    WelcomeText {
        objectName: "welcomeDiagnosticsState"; profile: section.profile
        text: Welcome.diagnostics.running ? "Running diagnostics…" : Welcome.diagnostics.error ? "Unavailable · " + Welcome.diagnostics.error : Welcome.diagnostics.ok === null ? "Diagnostics have not been run. Run them only when you need them." : Welcome.diagnostics.ok ? "Diagnostics completed · Passed" : "Diagnostics completed · Needs attention"
        color: Welcome.diagnostics.error || Welcome.diagnostics.ok === false ? profile.caution : profile.textDim
    }
    Repeater {
        model: Welcome.diagnostics.checks
        WelcomeText {
            required property var modelData
            profile: section.profile
            text: modelData.status + " · " + modelData.name + ": " + modelData.detail
        }
    }
    Flow {
        width: parent.width; spacing: Theme.du(8)
        WelcomeAction { objectName: "welcomeRunDiagnostics"; profile: section.profile; text: Welcome.diagnostics.running ? "Running…" : "Run diagnostics"; enabled: !Welcome.diagnostics.running; onTriggered: Welcome.runDiagnostics(); onFocused: item => section.focused(item) }
        WelcomeAction { objectName: "welcomePreviewReport"; profile: section.profile; text: section.reportVisible ? "Hide report" : "Preview report"; onTriggered: { section.reportVisible = !section.reportVisible; if (section.reportVisible) section.focused(report); } onFocused: item => section.focused(item) }
    }
    WelcomeText { profile: section.profile; visible: section.reportVisible; text: "Review before copying. This report includes output names and configuration errors." }
    TextEdit {
        id: report; objectName: "welcomeReport"
        visible: section.reportVisible; width: parent.width; height: visible ? implicitHeight : 0
        text: Welcome.report(); textFormat: TextEdit.PlainText
        readOnly: true; selectByMouse: true; activeFocusOnTab: true; wrapMode: TextEdit.Wrap
        color: section.profile.text; font.family: Theme.mono; font.pixelSize: Theme.fontXs
        selectionColor: section.profile.signal; selectedTextColor: section.profile.bg
        onActiveFocusChanged: if (activeFocus) section.focused(report)
        Accessible.name: "Report preview; select text to copy"
    }
    WelcomeAction {
        objectName: "welcomeCopyReport"; visible: section.reportVisible
        height: visible ? implicitHeight : 0; profile: section.profile; text: "Copy report"
        onTriggered: { report.selectAll(); report.copy(); section.copyState = "Report copied"; }
        onFocused: item => section.focused(item)
    }
    WelcomeText { profile: section.profile; visible: section.reportVisible && section.copyState !== ""; text: section.copyState }
}
