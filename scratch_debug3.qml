import QtQuick
import Quickshell
import qs.modules.services

PanelWindow {
    width: 200
    height: 200
    Component.onCompleted: {
        let s = this.screen;
        console.log("DEBUG_SCREEN:", s.name, s.x, s.y, s.geometry ? s.geometry.x : "no_geometry");
        Qt.quit();
    }
}
