import QtQuick
import QtQml.Models
import qs.core

// Invisible observer inside the target's own layer surface. The registry owns
// no Items. Ancestor connections live/die with this observer, without polling.
Item {
    id: observer
    required property string name
    property bool active: true
    property point surfaceOrigin: Qt.point(0, 0)
    readonly property var surfaceRoot: Window.window ? Window.window.contentItem : null
    readonly property string output: Screen.name
    property string leasedOutput: ""
    property string leasedName: ""
    property int token: 0
    property bool ready: false
    property int layoutRevision: 0
    readonly property var ancestors: {
        const chain = [];
        for (let item = observer; item; item = item.parent) chain.push(item);
        return chain;
    }
    readonly property bool exposed: {
        const revision = layoutRevision;
        if (!active || !surfaceRoot || !Window.window.visible) return false;
        for (const item of ancestors) if (!item.visible || item.opacity <= 0) return false;
        return true;
    }
    readonly property rect mapped: {
        const revision = layoutRevision;
        return surfaceRoot ? mapToItem(surfaceRoot, 0, 0, width, height) : Qt.rect(0, 0, 0, 0);
    }
    function publish() {
        if (!ready) return;
        if (!active || !output || !name) {
            if (token) Anchors.release(leasedOutput, leasedName, token);
            token = 0;
            return;
        }
        if (leasedOutput !== output || leasedName !== name || !token) {
            if (token) Anchors.release(leasedOutput, leasedName, token);
            leasedOutput = output;
            leasedName = name;
            token = Anchors.claim(output, name);
        }
        Anchors.update(leasedOutput, leasedName, token, exposed ? mapped : null, surfaceOrigin);
    }
    onActiveChanged: publish()
    onMappedChanged: publish()
    onExposedChanged: publish()
    onSurfaceOriginChanged: publish()
    onOutputChanged: publish()
    onNameChanged: publish()
    Component.onCompleted: { ready = true; publish(); }
    Component.onDestruction: { ready = false; if (token) Anchors.release(leasedOutput, leasedName, token); }
    Connections {
        target: observer.Window.window
        function onVisibleChanged() { observer.layoutRevision++; }
        function onWidthChanged() { observer.layoutRevision++; }
        function onHeightChanged() { observer.layoutRevision++; }
        function onScreenChanged() { observer.layoutRevision++; }
    }
    Instantiator {
        model: observer.ancestors
        delegate: Connections {
            required property var modelData
            target: modelData
            function onXChanged() { observer.layoutRevision++; }
            function onYChanged() { observer.layoutRevision++; }
            function onWidthChanged() { observer.layoutRevision++; }
            function onHeightChanged() { observer.layoutRevision++; }
            function onScaleChanged() { observer.layoutRevision++; }
            function onRotationChanged() { observer.layoutRevision++; }
            function onTransformOriginChanged() { observer.layoutRevision++; }
            function onVisibleChanged() { observer.layoutRevision++; }
            function onOpacityChanged() { observer.layoutRevision++; }
        }
    }
}
