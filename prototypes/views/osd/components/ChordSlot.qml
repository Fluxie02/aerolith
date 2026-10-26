import QtQuick
import qs.core

// A retained Deck slot's visual transform. Input and demand stay with the
// host; this item never waits for the opening animation before showing it.
Item {
    id: chord
    required property var slot
    readonly property bool wide: slot.bay !== "command" && slot.bay !== "ai"
    readonly property bool compactScreen: parent.width < Theme.du(1500) || parent.height < Theme.du(850)
    readonly property real leftOrigin: compactScreen ? parent.width * .045 : parent.width * (wide ? .12 : .37)
    readonly property real topOrigin: compactScreen ? Math.max(Theme.stripHeight + Theme.du(78), parent.height * .14) : parent.height * .22
    property real progress: 0

    x: leftOrigin
    y: topOrigin + (Theme.travel ? (1 - progress) * Theme.du(12) : 0)
    width: parent.width - leftOrigin - parent.width * (compactScreen ? .045 : .08)
    height: Math.max(0, parent.height - topOrigin - (compactScreen ? Theme.du(28) : Theme.du(130)) - (Config.strip.edge === "bottom" ? Theme.stripHeight : 0))
    opacity: Theme.animate ? Math.min(1, progress * 2) : 1
    scale: Theme.travel ? .94 + progress * .06 : 1
    transformOrigin: Item.Left
    z: slot.current ? 2 : 1

    // The complete chord, including its header, is a surface. Only clicks
    // outside it reach DeckView's backdrop; controls remain above this area.
    MouseArea { anchors.fill: parent; z: -1 }

    function transition() {
        motion.stop();
        if (slot.current) {
            progress = Theme.animate ? 0 : 1;
            motion.to = 1;
        } else {
            motion.to = 0;
        }
        if (Theme.animate)
            motion.restart();
        else
            progress = slot.current ? 1 : 0;
    }

    Connections {
        target: chord.slot
        function onCurrentChanged() { chord.transition(); }
    }
    Connections {
        target: Theme
        function onAnimateChanged() {
            if (!Theme.animate) {
                motion.stop();
                chord.progress = chord.slot.current ? 1 : 0;
            }
        }
    }
    Component.onCompleted: transition()
    NumberAnimation {
        id: motion
        target: chord
        property: "progress"
        duration: Theme.normal
        easing.type: Easing.OutCubic
    }
}
