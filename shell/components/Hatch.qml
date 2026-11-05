import QtQuick
import qs.core
import qs.services
import "../lib/geometry.mjs" as Geometry

// The scratch space has a physical entrance. Only these two retained leaves
// travel; no canvas, texture, timer, thumbnail or independent surface is owned.
Item {
    id: hatch
    readonly property var geometry: Geometry.ground(width, height, Theme.unit, Theme.stripHeight, Config.strip.edge === "bottom")
    property bool instrument: false
    property var profile: Theme
    readonly property string outputName: Screen.name
    readonly property bool ambient: Theme.ambientFor(outputName)
    readonly property bool deckHere: Ui.deckOpen && !!Ui.overlayScreen && Ui.overlayScreen.name === outputName
    // Guard the shared interface while the systems change lands separately.
    readonly property var parkedWindows: Compositor.scratchWindows || []
    readonly property bool known: Compositor.available && typeof Compositor.scratchWindows !== "undefined"
    readonly property bool opened: Compositor.scratchOpen === true
    readonly property bool canToggle: {
        const revision = Registry.revision;
        return Compositor.available && !!Registry.get("scratch.toggle");
    }
    readonly property bool exposed: visible && Window.window !== null && Window.window.visible
    readonly property bool motionAllowed: !(profile.idleDimmed || profile.idleAnimationHeld) && Theme.travel && hatch.ambient && exposed && !hatch.deckHere
    readonly property string inventory: known ? (parkedWindows.length ? parkedWindows.length + " PARKED" : "EMPTY") : "UNAVAILABLE"
    function toggle() {
        if (canToggle) Registry.run("scratch.toggle", {}, {record: false});
    }

    Item {
        id: entrance
        objectName: "hatchEntrance"
        AnchorTarget { name: "hatch"; anchors.fill: parent; active: !hatch.instrument }
        x: hatch.geometry.hatch.x
        y: hatch.geometry.hatch.y
        width: hatch.geometry.hatch.width
        height: hatch.geometry.hatch.height
        enabled: hatch.canToggle
        activeFocusOnTab: hatch.canToggle
        Keys.onReturnPressed: hatch.toggle()
        Keys.onSpacePressed: hatch.toggle()
        Accessible.role: Accessible.Button
        Accessible.name: (hatch.opened ? "Close" : "Open") + " scratch space, " + hatch.inventory.toLowerCase()
        Accessible.description: "Super+S toggles. Super+Shift+S parks the focused window."
        Accessible.checkable: true
        Accessible.checked: hatch.opened
        Accessible.onPressAction: hatch.toggle()

        Text {
            text: "HATCH"; textFormat: Text.PlainText
            color: hatch.profile.signal; font.family: Theme.mono; font.pixelSize: Theme.fontSm; font.letterSpacing: 1
        }
        Text {
            anchors.right: parent.right; width: parent.width * .65
            horizontalAlignment: Text.AlignRight; elide: Text.ElideRight
            text: hatch.inventory; textFormat: Text.PlainText
            color: hatch.profile.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs
        }

        Rectangle {
            id: aperture
            y: hatch.geometry.apertureY; width: parent.width
            height: hatch.geometry.apertureHeight
            color: hatch.profile.bg
            border.color: entrance.activeFocus || pointer.containsMouse || hatch.opened ? hatch.profile.signal : hatch.profile.textDim
            border.width: entrance.activeFocus ? Theme.du(2) : Theme.border

            // Recessed contents sit behind the leaves, never over real windows.
            Item {
                id: well
                anchors.fill: parent; anchors.margins: Theme.du(14)
                clip: true
                Column {
                    width: parent.width; spacing: Theme.du(8)
                    Text {
                        text: "SCRATCH SPACE"; textFormat: Text.PlainText
                        color: hatch.profile.signal; font.family: Theme.mono; font.pixelSize: Theme.fontXs; font.letterSpacing: 1
                    }
                    Rectangle { width: parent.width; height: Theme.border; color: hatch.profile.grid }
                    Repeater {
                        model: hatch.parkedWindows.slice(0, 3)
                        delegate: Item {
                            required property var modelData
                            width: well.width; height: Theme.du(42)
                            Rectangle { width: Theme.du(3); height: Theme.du(24); y: Theme.du(4); color: hatch.profile.signal }
                            Column {
                                x: Theme.du(12); width: parent.width - x; spacing: Theme.du(3)
                                Text {
                                    width: parent.width; elide: Text.ElideRight
                                    text: modelData.title || "Untitled window"; textFormat: Text.PlainText
                                    color: hatch.profile.text; font.family: Theme.sans; font.pixelSize: Theme.fontSm
                                }
                                Text {
                                    width: parent.width; elide: Text.ElideRight
                                    text: modelData.appId || "Application"; textFormat: Text.PlainText
                                    color: hatch.profile.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs
                                }
                            }
                        }
                    }
                    Text {
                        visible: hatch.parkedWindows.length > 3
                        text: "+ " + (hatch.parkedWindows.length - 3) + " MORE"; textFormat: Text.PlainText
                        color: hatch.profile.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs
                    }
                }
                Column {
                    anchors.centerIn: parent; width: parent.width
                    spacing: Theme.du(10); visible: hatch.parkedWindows.length === 0
                    Text {
                        width: parent.width; horizontalAlignment: Text.AlignHCenter
                        text: hatch.known ? "EMPTY" : "UNAVAILABLE"; textFormat: Text.PlainText
                        color: hatch.profile.text; font.family: Theme.mono; font.pixelSize: Theme.fontLg
                    }
                    Text {
                        width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                        text: hatch.known ? "Park a window to keep it here." : "Scratch space is not connected."
                        textFormat: Text.PlainText
                        color: hatch.profile.textDim; font.family: Theme.sans; font.pixelSize: Theme.fontSm
                    }
                }
            }

            // A shallow rim stays visible when both leaves retract into it.
            Item {
                anchors.fill: parent; anchors.margins: Theme.du(5)
                clip: true
                Repeater {
                    model: 2
                    delegate: Rectangle {
                        id: leaf
                        required property int index
                        readonly property bool leftLeaf: index === 0
                        width: parent.width / 2; height: parent.height
                        x: leftLeaf ? (hatch.opened ? -width + Theme.du(5) : 0)
                            : (hatch.opened ? parent.width - Theme.du(5) : width)
                        color: hatch.profile.surface
                        border.color: hatch.profile.grid; border.width: Theme.border
                        Behavior on x {
                            enabled: hatch.motionAllowed
                            XAnimator { id: leafMotion; duration: Theme.slow; easing.type: Easing.InOutCubic }
                        }
                        Connections {
                            target: hatch
                            function onMotionAllowedChanged() { if (!hatch.motionAllowed) leafMotion.complete(); }
                        }
                        Rectangle {
                            x: leaf.leftLeaf ? Theme.du(8) : parent.width - width - Theme.du(8)
                            y: Theme.du(10); width: Theme.du(3); height: parent.height - Theme.du(20)
                            color: hatch.profile.grid
                        }
                        Repeater {
                            model: Theme.insane ? 9 : 5
                            delegate: Rectangle {
                                required property int index
                                x: Theme.du(18); y: Theme.du(18) + index * Theme.du(6)
                                width: leaf.width - Theme.du(36); height: Theme.border; color: hatch.profile.grid
                            }
                        }
                        Text {
                            y: parent.height * .65; width: parent.width - Theme.du(16); x: Theme.du(8)
                            horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                            text: leaf.leftLeaf ? "SCRATCH" : "SPACE"; textFormat: Text.PlainText
                            color: hatch.profile.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs
                        }
                        Rectangle {
                            x: leaf.leftLeaf ? parent.width - width - Theme.du(8) : Theme.du(8)
                            y: parent.height * .36; width: Theme.du(8); height: parent.height * .20
                            color: hatch.profile.surface2; border.color: hatch.profile.textDim; border.width: Theme.border
                            Rectangle {
                                anchors.centerIn: parent; width: Theme.du(2); height: parent.height - Theme.du(10)
                                color: hatch.canToggle && (pointer.containsMouse || entrance.activeFocus) ? hatch.profile.signal : hatch.profile.text
                            }
                        }
                        Rectangle {
                            x: leaf.leftLeaf ? parent.width - width : 0
                            width: Theme.border; height: parent.height
                            color: hatch.canToggle && pointer.containsMouse ? hatch.profile.signal : hatch.profile.textDim
                        }
                    }
                }
            }
            // Four fixed corner registrations define a door frame, not a card.
            Repeater {
                model: 4
                delegate: Item {
                    required property int index
                    x: index % 2 ? aperture.width - width : 0
                    y: index < 2 ? 0 : aperture.height - height
                    width: Theme.du(15); height: Theme.du(15)
                    Rectangle { width: parent.width; height: Theme.du(2); y: index < 2 ? 0 : parent.height - height; color: hatch.profile.signal }
                    Rectangle { width: Theme.du(2); height: parent.height; x: index % 2 ? parent.width - width : 0; color: hatch.profile.signal }
                }
            }
        }

        Rectangle {
            y: aperture.y + aperture.height + Theme.du(8)
            width: parent.width; height: Theme.du(30)
            color: hatch.canToggle && (pointer.containsMouse || entrance.activeFocus) ? hatch.profile.signal : hatch.profile.bg
            border.color: hatch.canToggle ? hatch.profile.signal : hatch.profile.grid; border.width: Theme.border
            Text {
                anchors.centerIn: parent; width: parent.width - Theme.du(12)
                horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                text: hatch.canToggle ? (hatch.opened ? "CLOSE SCRATCH SPACE" : "OPEN SCRATCH SPACE") : "SCRATCH SPACE UNAVAILABLE"
                textFormat: Text.PlainText
                color: hatch.canToggle && (pointer.containsMouse || entrance.activeFocus) ? hatch.profile.bg : hatch.profile.text
                font.family: Theme.mono; font.pixelSize: Theme.fontXs
            }
        }
        Text {
            y: aperture.y + aperture.height + Theme.du(46); width: parent.width
            text: "Super+S · toggle\nSuper+Shift+S · park window"; textFormat: Text.PlainText
            color: hatch.profile.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs
            horizontalAlignment: Text.AlignHCenter; lineHeight: 1.5
        }
        MouseArea {
            id: pointer; anchors.fill: parent
            enabled: hatch.canToggle; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: hatch.toggle()
        }
    }
}
