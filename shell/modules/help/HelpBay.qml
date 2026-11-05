import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core
import qs.components
import qs.services

// HLP · Help: every command with its alias and parameters, plus the keys of
// each bay. Generated from the live registry, so it is never out of date.
FocusScope {
    id: help
    property var profile: Theme
    Connections {
        target: Theme
        function onAnimateChanged() {
            if (!Theme.animate) { list.cancelFlick(); keysView.cancelFlick(); }
        }
    }

    property string filter: ""

    readonly property var commands: {
        Registry.revision;
        const f = filter.toLowerCase();
        return Registry.list().filter(c => f === "" || (c.title + " " + c.id + " " + (c.alias || "") + " " + (c.keywords || []).join(" ")).toLowerCase().indexOf(f) !== -1);
    }

    readonly property var keyGroups: [
        {
            title: "Global actions / bindings set in Hyprland",
            keys: [["aerolith:command", "Command Core"], ["aerolith:navigator", "Spatial Navigator"], ["aerolith:systems", "Systems Bay"], ["aerolith:signal", "Signal Rack"], ["aerolith:routines", "Routine Console"], ["aerolith:ai", "AI Bridge (when installed)"], ["aerolith:volume-up/-down", "Volume"], ["aerolith:mute", "Mute"], ["aerolith:play-pause", "Media"]]
        },
        {
            title: "Installer defaults / your bindings may differ",
            keys: [["Super + Shift + Esc", "Session menu (default)"], ["Super + S", "Open / close scratch space (default)"], ["Super + Shift + S", "Park focused window (default)"]]
        },
        {
            title: "Deck",
            keys: [["Ctrl+1…7", "Switch bay"], ["Ctrl+7", "Settings"], ["F1", "This help"], ["Esc", "Close"]]
        },
        {
            title: "Command Core",
            keys: [["↑↓ / Ctrl+J K / N P", "Select"], ["PgUp / PgDn", "Select by page"], ["Ctrl+L", "Clear query"], ["Enter", "Run"], ["Shift+Enter", "Run, keep open"], ["Tab / Shift+Tab", "Next / previous scope"], ["> @ ! ?", "Commands, windows, routines, AI"], ["alias args", "e.g. vol 40, ws 3, out <device>"]]
        },
        {
            title: "Spatial Navigator",
            keys: [["←→ / h l", "Workspace"], ["↑↓ / j k / Tab", "Window"], ["1-9", "Go to workspace"], ["M then 1-9", "Move window"], ["X X / Delete twice", "Close window"], ["Enter", "Focus window / workspace"], ["/", "Filter"]]
        },
        {
            title: "Systems Bay",
            keys: [["C / M", "Sort processes by CPU / memory"], ["P", "Performance mode (halve sampling)"], ["PgUp / PgDn", "Scroll instruments"]]
        },
        {
            title: "Signal Rack",
            keys: [["↑↓ / j k", "Select"], ["←→ / h l", "Volume"], ["M", "Mute"], ["Enter / Space", "Default / play / re-route"], ["PgUp / PgDn", "Scroll rack"], [", .", "Previous / next"]]
        },
        {
            title: "Routine Console",
            keys: [["↑↓ / j k", "Select routine"], ["Enter", "Run (twice if sensitive)"], ["Esc", "Cancel between steps"], ["R", "Revert last run"], ["E", "Edit routines.json"], ["PgUp / PgDn", "Scroll execution plan"]]
        },
        {
            title: "AI Bridge (when installed)",
            keys: [["Enter", "Send prompt"], ["Tab", "Prompt / proposal review"], ["↑↓ / j k", "Select proposal in review"], ["A / D", "Approve one / dismiss one"], ["Esc", "Cancel request / leave review / close"]]
        },
        {
            title: "Settings",
            keys: [["↑↓ / j k", "Select setting"], ["←→ / h l", "Change choice / number"], ["Enter / Space", "Toggle / step / edit text"], ["Enter", "Save text"], ["Esc", "Cancel text / close"], ["PgUp / PgDn", "Move ten settings"]]
        },
        {
            title: "This reference",
            keys: [["PgUp / PgDn", "Scroll key reference"], ["↑↓", "Scroll command register"], ["Esc", "Clear filter / close"]]
        }
    ]

    // Kinetic scrolling is motion: with theme.motion "off" the list jumps.
    function scrollList(dir) {
        if (Theme.animate)
            list.flick(0, -800 * dir);
        else
            list.contentY = Math.max(list.originY, Math.min(list.originY + list.contentHeight - list.height, list.contentY + list.height * 0.25 * dir));
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Down) {
            help.scrollList(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            help.scrollList(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) {
            // The key reference can be taller than a small screen.
            const step = keysView.height * 0.8 * (event.key === Qt.Key_PageDown ? 1 : -1);
            keysView.contentY = Math.max(0, Math.min(keysView.contentHeight - keysView.height, keysView.contentY + step));
            event.accepted = true;
        } else if (event.key === Qt.Key_Escape && filterInput.text !== "") {
            filterInput.text = "";
            event.accepted = true;
        }
    }

    Bezel { profile: help.profile;
        anchors.fill: parent
        designation: "HELP"
        title: "Help and shortcuts"
        status: help.commands.length + " COMMANDS"

        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.pad
            z: -1
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.pad
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.pad
                Text {
                    Layout.fillWidth: true
                    text: "Learn the desktop in five steps. Global action names below are not key combinations."
                    textFormat: Text.PlainText; wrapMode: Text.WordWrap
                    color: help.profile.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontSm
                }
                Rectangle {
                    id: tourAction
                    objectName: "helpTakeTour"
                    implicitWidth: tourCaption.implicitWidth + 2 * Theme.pad
                    implicitHeight: Theme.rowHeight
                    color: tourPointer.containsMouse ? help.profile.surface2 : help.profile.bg
                    border.color: activeFocus ? help.profile.text : help.profile.signal
                    border.width: activeFocus ? Theme.px(2) : Theme.border
                    radius: Theme.radius; activeFocusOnTab: true
                    function activate() { if (Tour.start()) Ui.close(); }
                    Keys.onReturnPressed: activate()
                    Keys.onEnterPressed: activate()
                    Keys.onSpacePressed: activate()
                    KeyNavigation.tab: filterInput
                    KeyNavigation.backtab: filterInput
                    Text {
                        id: tourCaption; anchors.centerIn: parent
                        text: "Take the tour"; textFormat: Text.PlainText
                        color: help.profile.text; font.family: Theme.sans; font.pixelSize: Theme.fontSm
                    }
                    MouseArea { id: tourPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: tourAction.activate() }
                    Accessible.role: Accessible.Button; Accessible.name: "Take the tour"
                    Accessible.onPressAction: activate()
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Theme.pad * 2

                // Keys
                Flickable {
                    id: keysView
                    Layout.fillWidth: true
                    Layout.preferredWidth: 38
                    Layout.fillHeight: true
                    contentHeight: keysCol.implicitHeight
                    clip: true
                    Column {
                        id: keysCol
                        width: parent.width
                        spacing: Theme.pad
                        Repeater {
                            model: help.keyGroups
                            delegate: Column {
                                required property var modelData
                                width: keysCol.width
                                spacing: Theme.px(3)
                                Label { profile: help.profile;
                                    text: modelData.title
                                    strong: true
                                }
                                Repeater {
                                    model: modelData.keys
                                    delegate: Row {
                                        required property var modelData
                                        width: keysCol.width
                                        spacing: Theme.gap
                                        Text {
                                            textFormat: Text.PlainText
                                            width: Math.min(Theme.px(170), keysCol.width * .48)
                                            text: modelData[0]
                                            color: help.profile.signal
                                            font.family: Theme.mono
                                            font.pixelSize: Theme.fontXs
                                            wrapMode: Text.WrapAnywhere
                                        }
                                        Text {
                                            textFormat: Text.PlainText
                                            width: Math.max(0, keysCol.width - Math.min(Theme.px(170), keysCol.width * .48) - Theme.gap)
                                            wrapMode: Text.WordWrap
                                            text: modelData[1]
                                            color: help.profile.text
                                            font.family: Theme.sans
                                            font.pixelSize: Theme.fontXs
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Commands
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 62
                    Layout.fillHeight: true
                    spacing: Theme.gap
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Math.round(Theme.rowHeight * 1.1)
                        color: help.profile.bg
                        border.color: filterInput.activeFocus ? help.profile.signal : help.profile.grid
                        border.width: Theme.border
                        radius: Theme.radius
                        TextInput {
                            id: filterInput
                            anchors.fill: parent
                            anchors.leftMargin: Theme.pad
                            verticalAlignment: TextInput.AlignVCenter
                            focus: true
                            activeFocusOnTab: true
                            KeyNavigation.tab: tourAction
                            KeyNavigation.backtab: tourAction
                            color: help.profile.text
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontSm
                            clip: true
                            onTextChanged: help.filter = text
                            Text {
                                textFormat: Text.PlainText
                                visible: filterInput.text === ""
                                anchors.verticalCenter: parent.verticalCenter
                                text: "filter commands"
                                color: help.profile.textDim
                                font: filterInput.font
                            }
                        }
                    }
                    ListView {
                        id: list
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: help.commands
                        spacing: Theme.px(2)
                        section.property: "category"
                        section.delegate: Label { profile: help.profile;
                            required property string section
                            text: section
                            strong: true
                            topPadding: Theme.gap
                        }
                        delegate: RowLayout {
                            required property var modelData
                            width: list.width
                            spacing: Theme.gap
                            Text {
                                textFormat: Text.PlainText
                                Layout.preferredWidth: list.width * .36
                                text: modelData.title
                                color: modelData.hidden ? help.profile.textDim : help.profile.text
                                font.family: Theme.sans
                                font.pixelSize: Theme.fontXs
                                elide: Text.ElideRight
                            }
                            Text {
                                textFormat: Text.PlainText
                                Layout.preferredWidth: list.width * .26
                                text: modelData.alias ? modelData.alias + (modelData.params.length ? " " + modelData.params.map(p => "‹" + p.name + "›").join(" ") : "") : ""
                                color: help.profile.signal
                                font.family: Theme.mono
                                font.pixelSize: Theme.fontXs
                                elide: Text.ElideRight
                            }
                            Text {
                                textFormat: Text.PlainText
                                Layout.fillWidth: true
                                text: modelData.id + (modelData.sensitive ? " · confirm" : "") + (modelData.routine ? " · routine" : "") + (modelData.source !== "core" ? " · " + modelData.source : "")
                                color: help.profile.textDim
                                font.family: Theme.mono
                                font.pixelSize: Theme.fontXs
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
        ScrollMark { profile: help.profile; viewport: keysView }
        ScrollMark { profile: help.profile; viewport: list }
    }
}
