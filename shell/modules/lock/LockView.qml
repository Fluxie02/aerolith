// UI-007 / visual-only lock view; the host owns secure locking and PAM.
// Inputs: state (inherited Item.state): idle | checking | failed | locked-out;
// message: plain PAM prompt/error; user: plain display name; attempts: failed count.
// password aliases the masked TextInput. Prefer submitted(password); never log it.
// Output: submitted(string password). The buffer is cleared BEFORE emission and
// on checking/failed/locked-out/hide. Host must set checking synchronously.
// SystemClock supplies minute time. No desktop content or authentication code.
import QtQuick
import Quickshell
import qs.core
import qs.components

FocusScope {
    id: root
    state: "idle"
    property string message: ""
    property string user: ""
    property int attempts: 0
    property alias password: entry.text
    signal submitted(string password)
    readonly property bool editable: state === "idle" || state === "failed"
    readonly property bool compact: height < Theme.du(760)
    readonly property bool narrow: width < Theme.du(1100)
    readonly property color accent: state === "failed" ? Theme.critical : state === "locked-out" ? Theme.caution : Theme.signal
    function submit() {
        if (!editable || !entry.text.length) return;
        const secret = entry.text;
        entry.clear();
        submitted(secret);
    }
    onStateChanged: {
        entry.clear();
        if (editable) entry.forceActiveFocus();
    }
    onVisibleChanged: { entry.clear(); if (visible && editable) entry.forceActiveFocus(); }
    Component.onCompleted: entry.forceActiveFocus()
    SystemClock { id: clock; precision: SystemClock.Minutes }

    Rectangle { anchors.fill: parent; color: Theme.bg }
    Canvas {
        id: engraving
        anchors.fill: parent
        renderTarget: Canvas.Image
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onVisibleChanged: if (visible) requestPaint()
        onAvailableChanged: if (available) requestPaint()
        Connections { target: Theme; function onPaletteChanged() { engraving.requestPaint(); } function onUnitChanged() { engraving.requestPaint(); } function onInsaneChanged() { engraving.requestPaint(); } }
        onPaint: {
            const c = getContext("2d"); c.reset();
            const cx = root.narrow ? width / 2 : width * .28;
            const cy = root.narrow ? height * .27 : height * .49;
            const r = Math.min(width * .24, height * .32);
            c.strokeStyle = Theme.grid; c.lineWidth = 1;
            for (let j = 0; j < (Theme.insane ? 5 : 3); j++) {
                c.beginPath(); c.arc(cx, cy, r + Theme.du(j * 12), -.75, 4.6); c.stroke();
            }
            for (let i = 0; i < (Theme.insane ? 120 : 60); i++) {
                const a = i * Math.PI / (Theme.insane ? 60 : 30);
                const rr = r + Theme.du(Theme.insane ? 60 : 36);
                const len = Theme.du(i % 5 === 0 ? 12 : 4);
                c.beginPath(); c.moveTo(cx + Math.cos(a)*rr, cy + Math.sin(a)*rr);
                c.lineTo(cx + Math.cos(a)*(rr+len), cy + Math.sin(a)*(rr+len)); c.stroke();
            }
            c.strokeStyle = Theme.signal; c.lineWidth = Theme.bracketWeight;
            c.beginPath(); c.arc(cx, cy, r, -1.65, -1.24); c.stroke();
            if (Theme.insane) {
                c.strokeStyle = Theme.grid; c.lineWidth = 1;
                for (let y = Theme.du(100); y < height - Theme.du(60); y += Theme.du(32)) {
                    c.beginPath(); c.moveTo(Theme.du(28),y); c.lineTo(Theme.du(52),y); c.stroke();
                    c.beginPath(); c.moveTo(width-Theme.du(52),y); c.lineTo(width-Theme.du(28),y); c.stroke();
                }
            }
        }
    }
    Text {
        x: Theme.du(36); y: Theme.du(30)
        text: "AEROLITH   /   SESSION LOCK"
        textFormat: Text.PlainText; color: Theme.textDim
        font.family: Theme.mono; font.pixelSize: Theme.fontSm; font.letterSpacing: 2
    }
    Column {
        x: root.narrow ? (root.width-width)/2 : root.width*.28-width/2
        y: root.narrow ? Theme.du(root.compact ? 56 : 86) : root.height*.49-height/2
        width: root.narrow ? Math.min(root.width-Theme.du(48),Theme.du(440)) : root.width*.39
        spacing: Theme.du(12)
        Text {
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            textFormat: Text.PlainText; color: Theme.text
            font.family: Theme.displaySans; font.pixelSize: Theme.du(root.narrow ? (root.compact ? 48 : 68) : 104); font.weight: Font.Light
        }
        Text {
            width: parent.width; horizontalAlignment: Text.AlignHCenter
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM").toUpperCase()
            textFormat: Text.PlainText; color: Theme.textDim
            font.family: Theme.mono; font.pixelSize: Theme.fontSm; font.letterSpacing: 1
        }
    }
    Bezel {
        id: auth
        x: root.narrow ? (root.width-width)/2 : root.width*.54
        y: root.narrow ? (root.compact ? Theme.du(155) : Math.max(Theme.du(240), (root.height-height)*.68)) : (root.height-height)/2
        width: Math.min(Theme.du(520), root.narrow ? root.width-Theme.du(48) : root.width*.42)
        height: Math.min(Theme.du(480),root.height-(root.narrow ? Theme.du(root.compact ? 200 : 296) : Theme.du(100)))
        designation: "01"; title: "Unlock session"; accent: root.accent
        status: root.state === "checking" ? "VERIFYING" : "LOCKED"
        statusColor: root.accent
        // Force an opaque authentication plane even when effects are enabled.
        Rectangle { anchors.fill: parent; color: Theme.surface }
        Flickable {
            id: promptScroll
            anchors.fill: parent; anchors.bottomMargin: submitButton.height + Theme.du(16)
            contentHeight: form.height; clip: true
            boundsBehavior: Flickable.StopAtBounds
            Rectangle {
                x: promptScroll.width-Theme.du(3)
                y: promptScroll.visibleArea.yPosition*promptScroll.height
                width: Theme.du(3); height: promptScroll.visibleArea.heightRatio*promptScroll.height
                visible: promptScroll.contentHeight > promptScroll.height; color: Theme.textDim
            }
            Column {
                id: form; width: parent.width; spacing: Theme.du(root.compact ? 10 : 16)
                Text {
                    width: parent.width; text: root.user || "Your session"; elide: Text.ElideRight
                    textFormat: Text.PlainText; color: Theme.text
                    font.family: Theme.sans; font.pixelSize: Theme.du(root.compact ? 24 : 28); font.weight: Font.Medium
                }
                Text {
                    text: "PASSWORD"; textFormat: Text.PlainText; color: Theme.textDim
                    font.family: Theme.mono; font.pixelSize: Theme.fontSm; font.letterSpacing: 1
                }
                Rectangle {
                    width: parent.width; height: Theme.du(root.compact ? 48 : 60); color: Theme.bg
                    radius: Theme.radius
            border.width: Theme.border; border.color: root.editable ? root.accent : Theme.grid
                    TextInput {
                        id: entry
                        anchors.fill: parent; anchors.margins: Theme.du(16)
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password; passwordCharacter: "●"
                        color: Theme.text; selectionColor: Theme.signal; selectedTextColor: Theme.bg
                        font.family: Theme.sans; font.pixelSize: Theme.du(22)
                        enabled: root.editable; focus: true; clip: true
                        inputMethodHints: Qt.ImhHiddenText | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                        Accessible.name: "Password"
                        onAccepted: root.submit()
                    }
                    Text {
                        anchors.fill: parent; anchors.margins: Theme.du(16)
                        verticalAlignment: Text.AlignVCenter
                        visible: entry.text.length === 0
                        text: root.editable ? "Enter password" : root.state === "checking" ? "Checking credentials…" : "Try again when available"
                        textFormat: Text.PlainText; color: Theme.textDim
                        font.family: Theme.sans; font.pixelSize: Theme.fontLg; elide: Text.ElideRight
                    }
                }
                Text {
                    width: parent.width
                    text: (root.state === "failed" ? "Authentication failed. " : root.state === "locked-out" ? "Too many attempts. " : "")
                          + (root.message || (root.state === "checking" ? "Verifying your password…" : root.state === "failed" ? "Check your password and try again." : root.state === "locked-out" ? "Please wait for authentication to become available." : "Enter your password to continue."))
                    textFormat: Text.PlainText; wrapMode: Text.Wrap
                    color: root.state === "failed" || root.state === "locked-out" ? root.accent : Theme.textDim
                    font.family: Theme.sans; font.pixelSize: Theme.fontLg
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }
                Text {
                    visible: root.attempts > 0; text: root.attempts + (root.attempts === 1 ? " failed attempt" : " failed attempts")
                    textFormat: Text.PlainText; color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontSm
                }

            }
        }
        Rectangle {
            id: submitButton
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            height: Theme.du(root.compact ? 38 : 44)
            color: submitMouse.containsMouse && root.editable ? Theme.surface2 : Theme.surface
            radius: Theme.radius
            border.width: Theme.border; border.color: root.editable ? Theme.signal : Theme.grid
            Text {
                anchors.centerIn: parent
                text: root.state === "checking" ? "CHECKING…" : root.state === "locked-out" ? "PLEASE WAIT" : "UNLOCK    ↵"
                textFormat: Text.PlainText; color: root.editable ? Theme.signal : Theme.textDim
                font.family: Theme.mono; font.pixelSize: Theme.fontMd
            }
            MouseArea { id: submitMouse; anchors.fill: parent; hoverEnabled: true; enabled: root.editable; onClicked: root.submit() }
            Accessible.role: Accessible.Button; Accessible.name: "Unlock"; Accessible.onPressAction: root.submit()
        }
    }
    Text {
        anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: Theme.du(30)
        text: "SESSION LOCKED   /   AUTHENTICATION REQUIRED"
        textFormat: Text.PlainText; color: Theme.textDim; font.family: Theme.mono; font.pixelSize: Theme.fontXs
    }
}
