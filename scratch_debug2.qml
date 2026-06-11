import QtQuick
import Quickshell
import qs.modules.services
import qs.modules.bar.workspaces

PanelWindow {
    width: 200
    height: 200
    Connections {
        target: AxctlService.monitors
        function onValuesChanged() {
            let text = "Monitors: " + JSON.stringify(AxctlService.monitors.values);
            console.log("DEBUG_MONITORS2:", text);
            Qt.quit();
        }
    }
}
