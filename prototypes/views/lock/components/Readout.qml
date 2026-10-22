import QtQuick
import qs.core

// Label over a monospaced value with unit. `status` colours the value:
// nominal | caution | critical | unknown | active | "" (plain text).
Column {
    id: root
    property string label: ""
    property string value: "N/A"
    property string unit: ""
    property string status: ""
    property int valueSize: Theme.fontLg
    spacing: Math.round(Theme.gap / 2)

    Label {
        text: root.label
        width: Math.max(implicitWidth, valueRow.width)
    }
    Row {
        id: valueRow
        spacing: Theme.px(3)
        Text {
            textFormat: Text.PlainText
            text: root.value
            color: root.status === "" || root.status === "nominal" ? Theme.text : Theme.stateColor(root.status)
            font.family: Theme.mono
            font.pixelSize: root.valueSize
            font.weight: Font.Medium
        }
        Text {
            textFormat: Text.PlainText
            visible: root.unit !== "" && root.value !== "N/A"
            text: root.unit
            color: Theme.textDim
            font.family: Theme.mono
            font.pixelSize: Theme.fontSm
            anchors.baseline: parent.children[0].baseline
        }
    }
}
