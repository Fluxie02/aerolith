import QtQuick
import qs.core
import qs.services

WelcomeSection {
    id: section
    heading: "SYSTEM INFO"
    WelcomeText {
        objectName: "welcomeSystemInfo"; profile: section.profile
        text: "AEROLITH  " + (Welcome.info.version.aerolith || "Unavailable") + "\nQuickshell  " + (Welcome.info.version.quickshell || "Unavailable") + "\nHyprland  " + (Welcome.info.version.hyprland || "Unavailable") + "\nDialect  " + (Welcome.info.dialect || "Unavailable") + "\nGPU  " + (Welcome.info.gpu || "Unavailable")
    }
}
