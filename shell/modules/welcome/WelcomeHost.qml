import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.components
import qs.services
import "../settings"

// Mounted only while the service allows Welcome, on its resolved output.
PanelWindow {
    id: host
    objectName: "welcomeHost"
    readonly property var profile: displayProfile
    DisplayProfile { id: displayProfile; output: Welcome.output ? Welcome.output.name : "" }
    screen: Welcome.output ? Welcome.output.screen : null
    color: profile.bg
    implicitWidth: Math.min(Theme.du(compact ? 880 : 1120), screen ? screen.width - Theme.du(32) : Theme.du(880))
    implicitHeight: Math.min(Theme.du(820), screen ? screen.height - Theme.stripHeight - Theme.du(32) : Theme.du(640))
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "aerolith-welcome"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    readonly property bool compact: !screen || screen.width - Theme.du(32) < Theme.du(1000)
        || screen.height - Theme.stripHeight - Theme.du(32) < Theme.du(800) || Theme.textScale > 1.25
    function settings(section) {
        SettingsEntry.openPersonalize(section);
        Welcome.close();
    }
    FocusScope {
        id: keys; anchors.fill: parent; focus: true
        Component.onCompleted: close.forceActiveFocus()
        Keys.onEscapePressed: Welcome.close()
        Bezel {
            anchors.fill: parent; profile: host.profile; showHeader: false
            contentPadding: Theme.du(host.compact ? 16 : 24)
            Rectangle { anchors.fill: parent; color: host.profile.surface; z: -1 }
            Column {
                id: header; width: parent.width; spacing: Theme.du(10)
                RowLayout {
                    width: parent.width; spacing: Theme.du(12)
                    Text { text: "WELCOME"; textFormat: Text.PlainText; color: host.profile.signal; font.family: Theme.mono; font.pixelSize: Theme.fontSm; font.letterSpacing: 2 }
                    Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; text: Welcome.output ? Welcome.output.name : "Unavailable"; textFormat: Text.PlainText; elide: Text.ElideRight; color: host.profile.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs }
                    WelcomeAction { id: close; objectName: "welcomeClose"; profile: host.profile; text: "Close"; onTriggered: Welcome.close(); KeyNavigation.backtab: startUsing }
                }
                Rectangle { width: parent.width; height: Theme.border; color: host.profile.grid }
            }
            Flickable {
                id: scroll; objectName: "welcomeScroll"
                anchors { top: header.bottom; topMargin: Theme.du(16); bottom: footer.top; bottomMargin: Theme.du(14); left: parent.left; right: parent.right }
                clip: true; contentWidth: width; contentHeight: body.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                function reveal(item) {
                    const p = item.mapToItem(body, 0, 0);
                    if (p.y < contentY) contentY = p.y;
                    else if (p.y + item.height > contentY + height) contentY = Math.max(0, Math.min(contentHeight - height, p.y + item.height - height));
                }
                Column {
                    id: body; width: scroll.width; spacing: Theme.du(22)
                    OverviewSection { width: parent.width; profile: host.profile }
                    GridLayout {
                        width: parent.width; columns: host.compact ? 1 : 2
                        columnSpacing: Theme.du(24); rowSpacing: Theme.du(24)
                        StartSection { Layout.row: 0; Layout.column: 0; Layout.fillWidth: true; Layout.preferredWidth: 640; Layout.alignment: Qt.AlignTop; profile: host.profile; onPersonalizeRequested: host.settings(0); onFocused: item => scroll.reveal(item) }
                        ChecklistSection {
                            Layout.row: host.compact ? 1 : 0; Layout.column: host.compact ? 0 : 1; Layout.rowSpan: host.compact ? 1 : 2
                            Layout.fillWidth: true; Layout.preferredWidth: 368; Layout.alignment: Qt.AlignTop; profile: host.profile
                            onFocused: item => scroll.reveal(item)
                            onActionRequested: entry => {
                                if (entry.action === "startup") startup.focusControl();
                                else if (entry.action === "tour.start") Welcome.takeTour();
                                else host.settings(entry.id === "output" ? 4 : 0);
                            }
                        }
                        OutputsSection { Layout.row: host.compact ? 2 : 1; Layout.column: 0; Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; profile: host.profile; onSettingsRequested: host.settings(4); onFocused: item => scroll.reveal(item) }
                        StartupSection { id: startup; Layout.row: host.compact ? 3 : 2; Layout.column: host.compact ? 0 : 1; Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; profile: host.profile; onFocused: item => scroll.reveal(item) }
                        DocsSection { Layout.row: host.compact ? 4 : 2; Layout.column: 0; Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; profile: host.profile; onFocused: item => scroll.reveal(item) }
                        InfoSection { Layout.row: host.compact ? 5 : 3; Layout.column: host.compact ? 0 : 1; Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; profile: host.profile }
                        DiagnosticsSection { Layout.row: host.compact ? 6 : 3; Layout.column: 0; Layout.fillWidth: true; profile: host.profile; onFocused: item => scroll.reveal(item) }
                    }
                }
                ScrollMark { profile: host.profile; viewport: scroll }
            }
            Column {
                id: footer; width: parent.width; anchors.bottom: parent.bottom; spacing: Theme.du(10)
                Rectangle { width: parent.width; height: Theme.border; color: host.profile.grid }
                Flow {
                    width: parent.width; spacing: Theme.du(12)
                    WelcomeAction {
                        objectName: "welcomeShowStartup"; profile: host.profile
                        text: (Welcome.showOnStartup ? "☑  " : "☐  ") + "Show Welcome on startup"
                        enabled: !Config.previewActive && !Config.previewApplying
                        onTriggered: host.feedback = Config.setValues([{path: "welcome.showOnStartup", value: !Welcome.showOnStartup}])
                    }
                    WelcomeAction { id: startUsing; objectName: "welcomeStartUsing"; profile: host.profile; text: "Start using"; primary: true; onTriggered: Welcome.startUsing(); KeyNavigation.tab: close }
                }
                WelcomeText { objectName: "welcomeFeedback"; profile: host.profile; visible: host.feedback !== "" || Config.previewActive; text: host.feedback || "Apply or cancel your Personalize preview in Settings before changing this saved preference."; color: profile.caution }
            }
        }
    }
    property string feedback: ""
}
