import QtQuick
import qs.core

Column {
    property var profile: Theme
    spacing: Theme.du(8)
    Text { width: parent.width; text: "AEROLITH"; textFormat: Text.PlainText; color: parent.profile.text; font.family: Theme.sans; font.pixelSize: Theme.fontXl; font.weight: Font.DemiBold }
    WelcomeText { profile: parent.profile; text: "Search, switch windows and control your desktop."; color: profile.text; font.pixelSize: Theme.fontMd }
    WelcomeText { profile: parent.profile; text: "Search opens apps and actions. Windows finds and moves windows. Systems shows resource use. The hatch holds parked windows. The status strip offers sound, time and connections." }
}
