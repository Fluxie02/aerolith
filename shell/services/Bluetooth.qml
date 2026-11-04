pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth as BT
import qs.core
import "../lib/bluetooth.mjs" as Logic

Singleton {
    id: root

    readonly property var _adapter: BT.Bluetooth.defaultAdapter
    readonly property bool available: _adapter !== null
    readonly property bool powered: available && _adapter.enabled
    readonly property string adapterName: available ? _adapter.name : ""
    readonly property bool discovering: available && _adapter.discovering
    readonly property var _devices: available ? _adapter.devices.values : []
    readonly property var devices: Logic.sortDevices(_devices.map(d => ({
        address: d.address, name: d.name || d.deviceName || d.address, icon: d.icon,
        connected: d.connected, paired: d.paired, connecting: d.state === BT.BluetoothDeviceState.Connecting,
        battery: Logic.batteryPercent(d.batteryAvailable, d.battery)
    })))
    readonly property int connectedCount: Logic.connectedCount(devices)
    property int _discoveryDemand: 0

    function powerReason() {
        return !available ? "Bluetooth adapter unavailable"
            : _adapter.state === BT.BluetoothAdapterState.Blocked ? "Bluetooth is blocked by hardware" : true;
    }
    function setPowered(enabled) {
        const reason = powerReason();
        if (reason !== true) return Registry.fail(reason);
        _adapter.enabled = enabled;
        return Registry.ok("Bluetooth power change requested");
    }
    function find(address) {
        return _devices.filter(d => d.address === address)[0] || null;
    }
    function act(address, action) {
        const device = find(address);
        if (!device || !powered) return Registry.fail("Bluetooth device unavailable");
        device[action]();
        return Registry.ok("Bluetooth " + action + " requested");
    }
    function connect(address) { return act(address, "connect"); }
    function disconnect(address) { return act(address, "disconnect"); }
    function pair(address) { return act(address, "pair"); }
    function forget(address) { return act(address, "forget"); }
    function requestDiscovery() { _discoveryDemand++; }
    function releaseDiscovery() { _discoveryDemand = Math.max(0, _discoveryDemand - 1); }

    // One controller per adapter ensures old adapters release discovery too.
    Instantiator {
        model: root.available ? [root._adapter] : []
        delegate: QtObject {
            required property var modelData
            readonly property bool scanning: root._discoveryDemand > 0 && root.powered
            onScanningChanged: { if (modelData.discovering !== scanning) modelData.discovering = scanning; }
            Component.onCompleted: { if (modelData.discovering !== scanning) modelData.discovering = scanning; }
            Component.onDestruction: { if (modelData && modelData.discovering) modelData.discovering = false; }
        }
    }
    Component.onCompleted: Registry.register({ id: "bluetooth.toggle", title: "Turn Bluetooth on or off",
        category: "system", keywords: ["wireless", "radio"], available: () => root.powerReason(),
        run: () => root.setPowered(!root.powered) })
}
