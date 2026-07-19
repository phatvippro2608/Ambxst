pragma Singleton

import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.globals

Singleton {
    id: root

    // General Idle Settings
    property string lockCmd: Config.system.idle.general.lock_cmd ?? "ambxst lock"
    property string beforeSleepCmd: Config.system.idle.general.before_sleep_cmd ?? "loginctl lock-session"
    property string afterSleepCmd: Config.system.idle.general.after_sleep_cmd ?? "ambxst screen on"
    property bool triggeredLockScreenOff: false

    // Login Lock Daemon
    // Helper script that listens to Lock signal and executes lockCmd from config
    property var loginLockProc: Process {
        id: loginLockProc
        running: true
        command: ["bash", Qt.resolvedUrl("../../scripts/loginlock.sh").toString().replace("file://", "")]
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("loginlock.sh exited with code " + exitCode + ". Restarting...");
                loginLockRestartTimer.start();
            }
        }
    }

    property var loginLockRestartTimer: Timer {
        id: loginLockRestartTimer
        interval: 1000
        repeat: false
        onTriggered: loginLockProc.running = true
    }

    // Sleep Monitor Daemon
    // Helper script that listens to PrepareForSleep signal and executes sleep commands from config
    property var sleepMonitorProc: Process {
        id: sleepMonitorProc
        running: true
        command: ["bash", Qt.resolvedUrl("../../scripts/sleep_monitor.sh").toString().replace("file://", "")]
        
        stdout: SplitParser {
            onRead: data => {
                const signal = data.trim();
                if (signal === "SUSPEND") {
                    root.lockBeforeSleep();
                    SuspendManager.onPrepareForSleep();
                } else if (signal === "WAKE") {
                    SuspendManager.onWakingUp();
                }
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("sleep_monitor.sh exited with code " + exitCode + ". Restarting...");
                sleepMonitorRestartTimer.start();
            }
        }
    }

    property var sleepMonitorRestartTimer: Timer {
        id: sleepMonitorRestartTimer
        interval: 1000
        repeat: false
        onTriggered: sleepMonitorProc.running = true
    }

    // Master Idle Logic
    property int elapsedIdleTime: 0
    property var triggeredListeners: [] // Keeps track of indices that have fired

    // Calculate dynamic listeners based on battery status and timeout configurations
    readonly property var dynamicListeners: {
        let list = [];

        // Check if battery service is available, default to plugged-in if not
        let isPlugged = Battery.available ? Battery.isPluggedIn : true;

        // Get configured timeouts (in seconds)
        let screenOff = isPlugged ? (Config.system.idle.screen_off_timeout_ac ?? 600) : (Config.system.idle.screen_off_timeout_battery ?? 180);
        let suspend = isPlugged ? (Config.system.idle.suspend_timeout_ac ?? 1800) : (Config.system.idle.suspend_timeout_battery ?? 600);

        // 1. Dim display: happens 30 seconds before screen off (min 10s timeout)
        let dimTimeout = Math.max(10, screenOff - 30);
        if (screenOff > 0) {
            list.push({
                "timeout": dimTimeout,
                "onTimeout": "ambxst brightness 10 -s",
                "onResume": "ambxst brightness -r"
            });

            // 2. Lock screen and turn off display
            list.push({
                "timeout": screenOff,
                "onTimeout": "loginctl lock-session && ambxst screen off",
                "onResume": "ambxst screen on"
            });
        }

        // 3. Suspend system
        if (suspend > 0) {
            list.push({
                "timeout": suspend,
                "onTimeout": "ambxst suspend",
                "onResume": ""
            });
        }

        // Append any custom listeners from system.json if present
        if (Config.system.idle.listeners) {
            for (let i = 0; i < Config.system.idle.listeners.length; i++) {
                let l = Config.system.idle.listeners[i];
                let cmd = l.onTimeout || "";
                // Filter out standard ones to avoid double execution
                if (!cmd.includes("ambxst suspend") && !cmd.includes("screen off") && !cmd.includes("brightness 10 -s") && !cmd.includes("loginctl lock-session")) {
                    list.push(l);
                }
            }
        }

        return list;
    }

    // Reset idle state when dynamicListeners change (e.g. power source changed or settings adjusted)
    onDynamicListenersChanged: {
        root.resetIdleState();
    }

    // Master Monitor: Detects "absence of activity" almost immediately
    property var masterMonitor: IdleMonitor {
        id: masterMonitor
        timeout: 1 // 1 second threshold to consider the session "idle"
        respectInhibitors: true

        onIsIdleChanged: {
            if (isIdle) {
                idleTimer.start();
            } else {
                idleTimer.stop();
                root.resetIdleState();
            }
        }
    }

    property var idleTimer: Timer {
        id: idleTimer
        interval: 1000 // 1 second tick
        repeat: true
        onTriggered: {
            root.elapsedIdleTime += 1;
            
            // If locked, turn screen off after 10 seconds of idle
            if (GlobalStates.lockscreenVisible && root.elapsedIdleTime >= 10 && !root.triggeredLockScreenOff) {
                console.log("IdleService: Lockscreen is visible, turning screen off after 10s idle.");
                root.executeCommand("ambxst screen off");
                root.triggeredLockScreenOff = true;
            }
            
            root.checkListeners();
        }
    }

    function executeCommand(cmd) {
        if (!cmd) return;
        
        // Escape backslashes and quotes for the QML string
        let escapedCmd = cmd.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
        
        try {
            let proc = Qt.createQmlObject(`
                import Quickshell.Io
                Process {
                    command: ["sh", "-c", "${escapedCmd}"]
                    running: true
                    onExited: destroy()
                }
            `, root, "dynamicProc");
        } catch (e) {
            console.error("Failed to create process for command:", cmd, e);
        }
    }

    function shouldUseInternalSleepLock() {
        const cmd = (root.beforeSleepCmd || "").trim();
        return cmd === "loginctl lock-session"
            || cmd === "loginctl lock-sessions"
            || cmd === "ambxst lock";
    }

    function lockBeforeSleep() {
        if (root.shouldUseInternalSleepLock()) {
            LockscreenService.lock();
        }
    }

    function checkListeners() {
        let listeners = root.dynamicListeners;
        for (let i = 0; i < listeners.length; i++) {
            let listener = listeners[i];
            let tVal = listener.timeout || 60;

            // If time matches and hasn't been triggered yet
            if (root.elapsedIdleTime >= tVal && !root.triggeredListeners.includes(i)) {
                if (listener.onTimeout) {
                    console.log("Idle timer " + tVal + "s reached: " + listener.onTimeout);
                    root.executeCommand(listener.onTimeout);
                }
                root.triggeredListeners.push(i);
            }
        }
    }

    function resetIdleState() {
        // If we turned off the screen due to lockscreen idle, turn it back on
        if (root.triggeredLockScreenOff) {
            console.log("IdleService: Lockscreen activity detected, turning screen on.");
            root.executeCommand("ambxst screen on");
            root.triggeredLockScreenOff = false;
        }

        let listeners = root.dynamicListeners;

        // Execute resume commands for all triggered listeners
        // We iterate backwards to undo latest states first (optional preference)
        for (let i = root.triggeredListeners.length - 1; i >= 0; i--) {
            let idx = root.triggeredListeners[i];
            let listener = listeners[idx];

            if (listener && listener.onResume) {
                console.log("Idle resuming (undoing " + (listener.timeout || 0) + "s): " + listener.onResume);
                root.executeCommand(listener.onResume);
            }
        }

        // Reset counters
        root.elapsedIdleTime = 0;
        root.triggeredListeners = [];
    }
}
