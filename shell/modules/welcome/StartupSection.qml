import QtQuick
import qs.core
import qs.services

WelcomeSection {
    id: section
    heading: "LAUNCH ON STARTUP"
    signal focused(var item)
    function focusControl() { section.focused(section); if (launch.enabled) launch.forceActiveFocus(); else section.forceActiveFocus(); }
    WelcomeText {
        objectName: "welcomeStartupState"; profile: section.profile
        text: Welcome.startupBusy ? "Checking / updating startup…" : "Method: " + (Welcome.startup.method || "Unavailable") + " · " + (Welcome.startup.enabled === null ? "Unavailable" : Welcome.startup.enabled ? "Enabled" : "Disabled")
    }
    WelcomeText { profile: section.profile; text: "Launches the shell when you sign in. This is separate from showing Welcome." }
    WelcomeText { objectName: "welcomeStartupError"; profile: section.profile; visible: !!Welcome.startup.error; text: Welcome.startup.error || ""; color: profile.caution }
    WelcomeAction {
        id: launch; objectName: "welcomeLaunchStartup"; profile: section.profile
        text: "Launch on startup · " + (Welcome.startup.enabled === null ? "Unavailable" : Welcome.startup.enabled ? "On" : "Off")
        enabled: !Welcome.startupBusy && Welcome.startup.enabled !== null && !!Welcome.startup.method
        onTriggered: Welcome.setLaunchOnStartup(!Welcome.startup.enabled)
        onFocused: item => section.focused(item)
    }
    WelcomeText { profile: section.profile; visible: Welcome.startup.enabled === null || !Welcome.startup.method; text: "Automatic setup is unavailable. Consult Getting started for manual startup instructions." }
}
