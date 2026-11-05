import QtQuick
import qs.core
import qs.components
import qs.services

Annunciator {
    objectName: "networkIndicator"
    code: Network.kind === "ethernet" ? "ETHERNET" : Network.wifiAvailable ? "WI-FI" : "NETWORK"
    valueLimit: Theme.px(compact ? 80 : 120)
    value: Network.state === "connecting" ? "CONNECTING"
        : Network.kind === "wifi" ? Network.signal + "%"
        : Network.kind === "ethernet" ? "CONNECTED"
        : Network.wifiAvailable && !Network.wifiEnabled ? "OFF" : "OFFLINE"
    status: Network.state === "connected" ? "active" : "nominal"
    Accessible.role: Accessible.Button
    Accessible.name: "Network, " + (Network.connectionName || value) + ", choose a connection"
    Accessible.onPressAction: clicked(null)
}
