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

    property string filter: ""

    readonly property var commands: {
        Registry.revision;
        const f = filter.toLowerCase();
        return Registry.list().filter(c => f === "" || (c.title + " " + c.id + " " + (c.alias || "") + " " + (c.keywords || []).join(" ")).toLowerCase().indexOf(f) !== -1);
    }

    readonly property var keyGroups: [
        {
            title: "Global (Hyprland binds → global shortcuts)",
            keys: [["aerolith:command", "Command Core"], ["aerolith:navigator", "Spatial Navigator"], ["aerolith:systems", "Systems Bay"], ["aerolith:signal", "Signal Rack"], ["aerolith:routines", "Routine Console"], ["aerolith:volume-up/-down", "Volume"], ["aerolith:mute", "Mute"], ["aerolith:play-pause", "Media"]]
        },
        {
            title: "Deck",
            keys: [["Ctrl+1…6", "Switch bay"], ["F1", "This help"], ["PgUp / PgDn", "Scroll these keys"], ["Esc", "Close"]]
        },
        {
            title: "Command Core",
            keys: [["↑↓ / Ctrl+J K", "Select"], ["Enter", "Run"], ["Shift+Enter", "Run, keep open"], ["Tab", "Scope"], ["> @ !", "Commands, windows, routines"], ["alias args", "e.g. vol 40, ws 3, out <device>"]]
        },
        {
            title: "Spatial Navigator",
            keys: [["←↑↓→ / hjkl", "Sector"], ["Tab", "Window"], ["1-9", "Go to workspace"], ["M then 1-9", "Move window"], ["X X", "Close window"], ["/", "Filter"]]
        },
        {
            title: "Systems Bay",
            keys: [["C / M", "Sort processes by CPU / memory"], ["P", "Performance mode (halve sampling)"]]
        },
        {
            title: "Signal Rack",
            keys: [["←→", "Volume"], ["M", "Mute"], ["Enter", "Default / play / re-route"], [", .", "Previous / next"]]
        },
        {
            title: "Routine Console",
            keys: [["Enter", "Run (twice if sensitive)"], ["Esc", "Cancel between steps"], ["R", "Revert last run"], ["E", "Edit routines.json"]]
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

    Bezel {
        anchors.centerIn: parent
        width: Math.min(Theme.px(1280), parent.width - Theme.pad * 4)
        height: Math.min(Theme.px(820), parent.height - Theme.pad)
        designation: "HLP-00"
        title: "Help and shortcuts"
        status: help.commands.length + " COMMANDS"

        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.pad
            z: -1
        }

        RowLayout {
            anchors.fill: parent
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
                            Label {
                                text: modelData.title
                                strong: true
                            }
                            Repeater {
                                model: modelData.keys
                                delegate: Row {
                                    required property var modelData
                                    spacing: Theme.gap
                                    Text {
                                        width: Theme.px(170)
                                        text: modelData[0]
                                        color: Theme.signal
                                        font.family: Theme.mono
                                        font.pixelSize: Theme.fontXs
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: modelData[1]
                                        color: Theme.text
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
                    color: Theme.bg
                    border.color: filterInput.activeFocus ? Theme.signal : Theme.grid
                    border.width: Theme.border
                    radius: Theme.radius
                    TextInput {
                        id: filterInput
                        anchors.fill: parent
                        anchors.leftMargin: Theme.pad
                        verticalAlignment: TextInput.AlignVCenter
                        focus: true
                        color: Theme.text
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontSm
                        onTextChanged: help.filter = text
                        Text {
                            visible: filterInput.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: "filter commands"
                            color: Theme.textDim
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
                    section.delegate: Label {
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
                            Layout.preferredWidth: Theme.px(230)
                            text: modelData.title
                            color: modelData.hidden ? Theme.textDim : Theme.text
                            font.family: Theme.sans
                            font.pixelSize: Theme.fontXs
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.preferredWidth: Theme.px(150)
                            text: modelData.alias ? modelData.alias + (modelData.params.length ? " " + modelData.params.map(p => "‹" + p.name + "›").join(" ") : "") : ""
                            color: Theme.signal
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontXs
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.id + (modelData.sensitive ? " · confirm" : "") + (modelData.routine ? " · routine" : "") + (modelData.source !== "core" ? " · " + modelData.source : "")
                            color: Theme.textDim
                            font.family: Theme.mono
                            font.pixelSize: Theme.fontXs
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
