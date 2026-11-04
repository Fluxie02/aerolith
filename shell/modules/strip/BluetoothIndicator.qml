import QtQuick
import qs.core
import qs.components
import qs.services

Annunciator {
    objectName: "bluetoothIndicator"
    code: "BLUETOOTH"
    value: !Bluetooth.powered ? "OFF" : Bluetooth.connectedCount ? String(Bluetooth.connectedCount) + " CONNECTED" : "ON"
    valueLimit: Theme.px(compact ? 80 : 120)
    status: Bluetooth.connectedCount > 0 ? "active" : "nominal"
    Accessible.role: Accessible.Button
    Accessible.name: "Bluetooth, " + value + ", choose a device"
    Accessible.onPressAction: clicked(null)
}
