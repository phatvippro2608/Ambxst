pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property Process bingProc: Process {
        id: bingProc
        running: false
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("[BingWallpaperService] Script exited with code: " + exitCode);
            } else {
                console.log("[BingWallpaperService] Wallpaper updated successfully");
            }
        }
    }

    function runBingWallpaper() {
        if (!Config.theme.bingWallpaperEnabled) return;
        
        let scriptPath = Quickshell.env("HOME") + "/.config/hypr/scripts/bing-wallpaper.sh";
        let args = [];
        if (Config.theme.bingWallpaperMode === "random") {
            args.push("--random");
        }
        
        console.log("[BingWallpaperService] Running bing-wallpaper.sh with args: " + JSON.stringify(args));
        bingProc.command = ["bash", scriptPath].concat(args);
        bingProc.running = true;
    }

    // Delay run on startup
    Timer {
        id: startupTimer
        interval: 3000
        running: true
        repeat: false
        onTriggered: {
            runBingWallpaper();
        }
    }

    // Check periodically (every 12 hours)
    Timer {
        id: periodicTimer
        interval: 12 * 3600 * 1000
        running: true
        repeat: true
        onTriggered: {
            runBingWallpaper();
        }
    }

    // Watch config changes
    Connections {
        target: Config.theme
        ignoreUnknownSignals: true
        function onBingWallpaperEnabledChanged() {
            if (Config.theme.bingWallpaperEnabled) {
                runBingWallpaper();
            }
        }
        function onBingWallpaperModeChanged() {
            if (Config.theme.bingWallpaperEnabled) {
                runBingWallpaper();
            }
        }
    }
}
