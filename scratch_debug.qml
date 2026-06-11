import QtQuick
import Quickshell
import qs.modules.services
import qs.modules.bar.workspaces

PanelWindow {
    width: 200
    height: 200
    Component.onCompleted: {
        let text = "Monitors: " + JSON.stringify(AxctlService.monitors.values);
        console.log("DEBUG_MONITORS:", text);
        Qt.quit();
    }
}
