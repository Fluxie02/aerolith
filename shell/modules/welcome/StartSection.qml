import QtQuick
import qs.core
import qs.services

WelcomeSection {
    id: section
    heading: "START HERE"
    signal personalizeRequested()
    signal focused(var item)
    WelcomeText { profile: section.profile; text: "A short tour introduces five places on your desktop. Personalization is optional; you can change it any time in Settings." }
    WelcomeText { profile: section.profile; visible: Config.previewDirty || Config.previewApplying; text: "Resolve your Personalize draft in Settings before starting the tour." }
    Flow {
        width: parent.width; spacing: Theme.du(8)
        WelcomeAction { objectName: "welcomeTakeTour"; profile: section.profile; primary: true; text: Store.welcome.tourStep > 0 && !Tour.completed ? "Resume tour · " + (Store.welcome.tourStep + 1) + "/5" : "Take tour"; enabled: !Config.previewDirty && !Config.previewApplying; onTriggered: Welcome.takeTour(); onFocused: item => section.focused(item) }
        WelcomeAction { objectName: "welcomePersonalize"; profile: section.profile; text: "Personalize"; onTriggered: section.personalizeRequested(); onFocused: item => section.focused(item) }
    }
}
