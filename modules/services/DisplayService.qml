pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.modules.globals
import qs.modules.services

QtObject {
	id: root

	// Monitor config changes reactively
	property Connections configConnections: Connections {
		target: Config.system.display
		ignoreUnknownSignals: true
		function onModeChanged() {
			root.applyDisplayMode();
		}
	}

	// Monitor sleep/wake events to re-apply monitor config
	property Connections suspendConnections: Connections {
		target: SuspendManager
		ignoreUnknownSignals: true
		function onWakingUp() {
			console.log("DisplayService: System woke up, scheduling display mode restoration...");
			wakeRestoreTimer.start();
		}
	}

	// Delay restoration slightly to allow the compositor/GPU to detect monitors first
	property Timer wakeRestoreTimer: Timer {
		id: wakeRestoreTimer
		interval: 1500
		repeat: false
		onTriggered: {
			console.log("DisplayService: Restoring display mode after wake...");
			root.applyDisplayMode();
		}
	}

	property Process displayProc: Process {
		id: displayProc
		running: false
		onExited: exitCode => {
			if (exitCode !== 0) {
				console.warn("DisplayService: display_mode.sh exited with code " + exitCode);
			}
		}
	}

	function applyDisplayMode() {
		if (!Config.systemReady) {
			console.log("DisplayService: Config not ready yet, skipping...");
			return;
		}

		let mode = Config.system.display ? Config.system.display.mode : "extend";
		if (!mode) mode = "extend";

		console.log("DisplayService: Applying display mode: " + mode);
		let scriptPath = Quickshell.shellDir + "/scripts/display_mode.sh";

		displayProc.command = ["bash", scriptPath, mode];
		displayProc.running = true;
	}

	Component.onCompleted: {
		// Apply display mode on startup
		Qt.callLater(() => {
			if (Config.systemReady) {
				root.applyDisplayMode();
			}
		});
	}

	// Watch systemReady changes to run on startup
	property Connections systemReadyConnections: Connections {
		target: Config
		ignoreUnknownSignals: true
		function onSystemReadyChanged() {
			if (Config.systemReady) {
				root.applyDisplayMode();
			}
		}
	}
}
