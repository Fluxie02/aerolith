import QtQuick
import qs.core
import qs.services

// Existing samples only. This readout never raises telemetry/audio demand.
Item {
    id: tape
    property string label: ""
    property string reading: "N/A"
    property var values: []
    property int seq: Telemetry.sampleSeq
    property color ink: Theme.signal
    implicitHeight: Theme.du(90)
    Rectangle { width: parent.width; height: 1; color: Theme.grid }
    Text {
        y: Theme.du(10); text: tape.label; textFormat: Text.PlainText
        font.family: Theme.mono; font.pixelSize: Theme.fontSm; color: Theme.textDim
    }
    Text {
        y: Theme.du(28); text: tape.reading; textFormat: Text.PlainText
        font.family: Theme.displaySans; font.pixelSize: Theme.du(25); color: tape.ink
    }
    Trace {
        x: parent.width * .50; y: Theme.du(14)
        width: parent.width * .48; height: Theme.du(49)
        values: tape.values; seq: tape.seq; capacity: 36; color: tape.ink
    }
    Text {
        anchors.bottom: parent.bottom
        text: "HISTORY / " + Math.min(36, tape.values.length) + " SAMPLES"
        textFormat: Text.PlainText; color: Theme.textDim
        font.family: Theme.mono; font.pixelSize: Theme.fontXs
    }
}
