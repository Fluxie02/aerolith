pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking as NM
import qs.core
import "../lib/network.mjs" as Logic

Singleton {
    id: root

    readonly property var _devices: NM.Networking.devices.values
    // backend is a startup snapshot in 0.3.2, not live NM presence.
    // A usable backend must also expose a device (including a disabled radio).
    readonly property bool available: NM.Networking.backend !== NM.NetworkBackendType.None && _devices.length > 0
    readonly property var _wifi: _devices.filter(d => d.type === NM.DeviceType.Wifi)
    readonly property bool wifiAvailable: available && _wifi.length > 0
    readonly property bool wifiEnabled: available && NM.Networking.wifiEnabled
    readonly property var _networks: {
        let rows = [];
        for (const d of _wifi)
            rows = rows.concat(d.networks.values);
        return rows;
    }
    property var _failures: []
    readonly property var networks: Logic.sortNetworks(_networks.map(n => networkRow(n)))
    readonly property var _summary: Logic.summary(available, _devices.filter(d => d.type === NM.DeviceType.Wifi || d.type === NM.DeviceType.Wired).map(d => {
        const wifi = d.type === NM.DeviceType.Wifi;
        const n = wifi ? d.networks.values.filter(n => n.connected || n.state === NM.ConnectionState.Connecting)[0] : d.network;
        return { kind: wifi ? "wifi" : "ethernet", state: connectionState(d.state),
            // 0.3.2 names wired networks after the interface. A single
            // settings profile gives its connection label; multiple profiles
            // have no exposed active-profile identity, so keep the interface.
            name: n ? (!wifi && n.nmSettings.length === 1 ? n.nmSettings[0].id : n.name) : "", signal: wifi ? (n ? Logic.percent(n.signalStrength) : 0) : -1 };
    }))
    readonly property string kind: _summary.kind
    readonly property string state: _summary.state
    readonly property string connectionName: _summary.connectionName
    readonly property int signal: _summary.signal
    readonly property bool online: available && (NM.Networking.canCheckConnectivity
        ? NM.Networking.connectivity === NM.NetworkConnectivity.Full : state === "connected")
    property int _scanDemand: 0

    function connectionState(value) {
        return value === NM.ConnectionState.Connected ? "connected"
            : value === NM.ConnectionState.Connecting ? "connecting" : "disconnected";
    }
    function networkRow(n) {
        const failure = _failures.filter(f => f.network === n)[0];
        return { name: n.name, signal: Logic.percent(n.signalStrength),
            // OWE is encrypted but needs no password. Only personal WPA types
            // take a password; enterprise (EAP) and WEP need a full profile.
            secured: n.security !== NM.WifiSecurityType.Open && n.security !== NM.WifiSecurityType.Owe,
            takesPassword: n.security === NM.WifiSecurityType.WpaPsk || n.security === NM.WifiSecurityType.Wpa2Psk
                || n.security === NM.WifiSecurityType.Sae,
            enterprise: n.security === NM.WifiSecurityType.Wpa2Eap || n.security === NM.WifiSecurityType.WpaEap
                || n.security === NM.WifiSecurityType.Wpa3SuiteB192 || n.security === NM.WifiSecurityType.Leap
                || n.security === NM.WifiSecurityType.DynamicWep,
            known: n.known,
            connected: n.connected, connecting: n.state === NM.ConnectionState.Connecting,
            failed: !!failure, failReason: failure ? failure.reason : "" };
    }
    function clearFailure(n) {
        _failures = _failures.filter(f => f.network !== n);
    }
    function find(name) {
        const matches = _networks.filter(n => n.name === name);
        matches.sort((a, b) => Logic.compareNetworks(networkRow(a), networkRow(b)));
        return matches.length ? matches[0] : null;
    }
    function wifiReason() {
        return !available ? "Network backend unavailable" : !wifiAvailable ? "No Wi-Fi device"
            : !NM.Networking.wifiHardwareEnabled ? "Wi-Fi is blocked by hardware" : true;
    }
    function setWifiEnabled(enabled) {
        const reason = wifiReason();
        if (reason !== true) return Registry.fail(reason);
        NM.Networking.wifiEnabled = enabled;
        return Registry.ok("Wi-Fi power change requested");
    }
    function connect(name) {
        const n = find(name);
        if (!wifiEnabled || !n) return Registry.fail("Wi-Fi network unavailable");
        const row = networkRow(n);
        if (!n.known && row.secured)
            return Registry.fail(row.takesPassword ? "A password is required"
                : row.enterprise ? "This network needs an enterprise sign-in" : "This sign-in method needs your network settings");
        clearFailure(n);
        n.connect();
        return Registry.ok("Network connection requested");
    }
    function connectWithPsk(name, psk) {
        const n = find(name);
        if (!wifiEnabled || !n) return Registry.fail("Wi-Fi network unavailable");
        if (!networkRow(n).takesPassword) return Registry.fail("This sign-in method needs your network settings");
        clearFailure(n);
        n.connectWithPsk(psk);
        // The secret is never retained in service state, Registry or logs.
        psk = "";
        return Registry.ok("Network connection requested");
    }
    function disconnect() {
        const active = _devices.filter(d => connectionState(d.state) === "connected"
            || connectionState(d.state) === "connecting");
        if (!available || !active.length) return Registry.fail("No active network connection");
        for (const d of active) d.disconnect();
        return Registry.ok("Network disconnection requested");
    }
    function forget(name) {
        const matches = _networks.filter(n => n.name === name && n.known);
        if (!matches.length) return Registry.fail("No saved network with that name");
        for (const n of matches) n.forget();
        return Registry.ok("Forget network requested");
    }
    function requestScan() { _scanDemand++; }
    function releaseScan() { _scanDemand = Math.max(0, _scanDemand - 1); }

    Instantiator {
        model: root._wifi
        delegate: QtObject {
            required property var modelData
            readonly property bool scanning: root._scanDemand > 0 && root.wifiEnabled
            onScanningChanged: modelData.scannerEnabled = scanning
            Component.onCompleted: modelData.scannerEnabled = scanning
            Component.onDestruction: { if (modelData) modelData.scannerEnabled = false; }
        }
    }
    Instantiator {
        model: root._networks
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectionFailed(reason) {
                root._failures = root._failures.filter(f => f.network !== modelData)
                    .concat([{ network: modelData, reason: NM.ConnectionFailReason.toString(reason) }]);
            }
            function onStateChanged() {
                if (modelData.connected || modelData.state === NM.ConnectionState.Connecting)
                    root.clearFailure(modelData);
            }
        }
    }
    on_NetworksChanged: _failures = _failures.filter(f => _networks.indexOf(f.network) !== -1)

    Component.onCompleted: {
        Registry.register({ id: "network.wifi.toggle", title: "Turn Wi-Fi on or off", category: "system",
            keywords: ["wifi", "wireless", "radio"], available: () => root.wifiReason(),
            run: () => root.setWifiEnabled(!root.wifiEnabled) });
        Registry.register({ id: "network.disconnect", title: "Disconnect network", category: "system",
            available: () => !root.available ? "Network backend unavailable"
                : root.state === "connected" || root.state === "connecting" ? true : "No active network connection",
            run: () => root.disconnect() });
    }
}
