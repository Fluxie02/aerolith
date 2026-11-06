pragma Singleton
import QtQuick
import qs.core

// Visual entry routing only. Settings/Personalize retains ownership of drafts.
QtObject {
    property int section: 0
    property bool importPending: false
    signal personalizeRequested(int targetSection)
    function openPersonalize(targetSection) {
        section = targetSection;
        Ui.open("settings");
        personalizeRequested(targetSection);
    }
}
