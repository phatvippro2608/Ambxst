pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    property bool active: false
    property var lastAccessed: ({
    })
    property Process getProcess

    getProcess: Process {
        command: ["gsettings", "get", "org.gnome.system.location", "enabled"]
        running: false

        stdout: SplitParser {
            onRead: (data) => {
                if (data) {
                    var clean = data.trim();
                    root.active = (clean === "true");
                }
            }
        }

    }

    property Process setProcess

    setProcess: Process {
        running: false
    }

    function toggle() {
        var newValue = !active;
        setProcess.command = ["gsettings", "set", "org.gnome.system.location", "enabled", newValue ? "true" : "false"];
        setProcess.running = true;
        active = newValue;
    }

    function syncState() {
        if (!getProcess.running)
            getProcess.running = true;

    }

    function reportAccess(appName) {
        var now = new Date();
        var timeStr = now.toLocaleTimeString(Qt.locale(), "hh:mm:ss AP");
        var copy = Object.assign({
        }, lastAccessed);
        copy[appName] = timeStr;
        lastAccessed = copy;
    }

    // Initialize and keep in sync
    Timer {
        id: syncTimer

        interval: 100
        running: true
        repeat: true
        onTriggered: {
            root.syncState();
            if (interval === 100)
                interval = 5000;

        }
    }

}
