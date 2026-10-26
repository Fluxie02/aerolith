import QtQuick
import Quickshell
import qs.core

// Clock with minute precision by default, so the strip redraws once a
// minute instead of every second.
Item {
    id: root
    property bool compact: false
    implicitWidth: row.implicitWidth + Theme.pad

    SystemClock {
        id: clock
        precision: Config.strip.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    readonly property string timeText: {
        const d = clock.date;
        if (Config.strip.clock === "12h") {
            const h = d.getHours() % 12 === 0 ? 12 : d.getHours() % 12;
            return h + ":" + pad(d.getMinutes()) + (Config.strip.showSeconds ? ":" + pad(d.getSeconds()) : "") + (d.getHours() < 12 ? " AM" : " PM");
        }
        return pad(d.getHours()) + ":" + pad(d.getMinutes()) + (Config.strip.showSeconds ? ":" + pad(d.getSeconds()) : "");
    }
    readonly property string dateText: {
        const d = clock.date;
        const days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
        const months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
        return days[d.getDay()] + " " + pad(d.getDate()) + " " + months[d.getMonth()];
    }

    function pad(n) {
        return n < 10 ? "0" + n : String(n);
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.gap
        Text {
            textFormat: Text.PlainText
            visible: Config.strip.showDate && !root.compact
            text: root.dateText
            color: Theme.textDim
            font.family: Theme.mono
            font.pixelSize: Theme.fontXs
            font.letterSpacing: 0.8
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            textFormat: Text.PlainText
            text: root.timeText
            color: Theme.text
            font.family: Theme.mono
            font.pixelSize: Theme.fontMd
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
