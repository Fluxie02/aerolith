import QtQuick
import qs.core
import qs.services

WelcomeSection {
    id: section
    heading: "LEARN & MAINTAIN"
    signal focused(var item)
    Repeater {
        model: Welcome.docs
        WelcomeAction {
            required property var modelData
            objectName: "welcomeDoc_" + modelData.id
            profile: section.profile; text: modelData.title + (modelData.available ? " →" : " · Unavailable")
            enabled: modelData.available
            onTriggered: Welcome.openDoc(modelData.id)
            onFocused: item => section.focused(item)
        }
    }
    WelcomeText { profile: section.profile; text: "Documents open from your installed local documentation. Unavailable entries are not installed." }
    WelcomeText { profile: section.profile; text: "Updates · No automatic update check. Installed version: " + (Welcome.info.version.aerolith || "Unavailable") + ". Update method unavailable; use your installation’s instructions." }
}
