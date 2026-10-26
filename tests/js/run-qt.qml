// Run the shared JS suites inside Qt's V4 engine, the engine Quickshell uses:
//   QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 qml tests/js/run-qt.qml
// Exits with status 1 if any test fails.
import QtQuick
import "index.mjs" as Index
import "harness.mjs" as Harness

QtObject {
    Component.onCompleted: {
        Harness.runAll(Index.suites, line => console.warn(line)).then(summary => {
            Qt.exit(summary.failed > 0 ? 1 : 0);
        }, error => {
            console.warn("runner error: " + error);
            Qt.exit(2);
        });
    }
}
