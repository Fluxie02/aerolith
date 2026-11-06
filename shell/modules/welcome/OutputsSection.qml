import QtQuick
import qs.core
import qs.services

WelcomeSection {
    id: section
    heading: "DISPLAYS & SETTINGS"
    signal settingsRequested()
    signal focused(var item)
    Repeater {
        model: Welcome.info.outputs
        WelcomeText {
            required property var modelData
            objectName: "welcomeOutput_" + modelData.name
            profile: section.profile
            text: modelData.name + " · " + (modelData.mode || "Mode unavailable") + " · Scale " + (modelData.scale || "Unavailable") + " · " + (modelData.profile || "Profile unavailable")
            color: profile.text
        }
    }
    WelcomeText { profile: section.profile; text: "Settings → Personalize → Displays changes shell placement and output profiles. Resolution and refresh rate belong to your system display settings. Open your distribution’s settings tool for hardware and session options." }
    WelcomeAction { objectName: "welcomeDisplays"; profile: section.profile; text: "Display preferences"; onTriggered: section.settingsRequested(); onFocused: item => section.focused(item) }
}
