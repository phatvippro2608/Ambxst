pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.modules.services

Singleton {
    id: root

    property bool cupsActive: false
    property var printers: []
    property var jobs: []
    property var completedJobs: []
    property bool isPrinting: false
    property bool discovering: false
    property var discoveredDevices: []
    property bool probing: false
    property var probedDevices: []
    property bool searchingDrivers: false
    property var searchedDrivers: []

    property var previousJobs: []

    property Process monitorProcess: Process {
        id: monitorProcess
        running: true
        command: ["python3", Quickshell.shellDir + "/scripts/printer_monitor.py", "3.0"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const stats = JSON.parse(data);
                    root.cupsActive = stats.cups_active;
                    root.printers = stats.printers || [];
                    root.updateJobs(stats.jobs || [], stats.completed_jobs || []);
                } catch (e) {
                    console.warn("PrinterService: Failed to parse monitor data: " + e);
                }
            }
        }
    }

    property Process cancelProcess: Process {
        id: cancelProcess
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("PrinterService: Failed to cancel job");
            }
        }
    }

    property Process defaultProcess: Process {
        id: defaultProcess
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("PrinterService: Failed to set default printer");
            } else {
                root.refresh();
            }
        }
    }

    property Process optionProcess: Process {
        id: optionProcess
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("PrinterService: Failed to set printer option");
            } else {
                root.refresh();
            }
        }
    }

    function refresh() {
        root.monitorProcess.running = false;
        Qt.callLater(() => { root.monitorProcess.running = true; });
    }

    function cancelJob(jobId) {
        cancelProcess.command = ["cancel", jobId];
        cancelProcess.running = true;
    }

    function setDefaultPrinter(printerName) {
        defaultProcess.command = ["lpoptions", "-d", printerName];
        defaultProcess.running = true;
    }

    function setPrinterOption(printerName, optionName, value) {
        optionProcess.command = ["lpoptions", "-p", printerName, "-o", optionName + "=" + value];
        optionProcess.running = true;
    }

    property Process discoverProcess: Process {
        id: discoverProcess
        command: ["python3", Quickshell.shellDir + "/scripts/printer_monitor.py", "--discover"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.discoveredDevices = JSON.parse(data);
                } catch (e) {
                    console.warn("PrinterService: Failed to parse discovery data: " + e);
                }
            }
        }
        onExited: exitCode => {
            root.discovering = false;
        }
    }

    property Process addPrinterProcess: Process {
        id: addPrinterProcess
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("PrinterService: Failed to add printer");
                root.sendPrinterNotification("Error Adding Printer", "Failed to add printer to CUPS.");
            } else {
                root.sendPrinterNotification("Printer Added", "Printer was successfully added.");
                root.refresh();
            }
        }
    }

    property Process deletePrinterProcess: Process {
        id: deletePrinterProcess
        onExited: exitCode => {
            if (exitCode !== 0) {
                console.warn("PrinterService: Failed to delete printer");
                root.sendPrinterNotification("Error Deleting Printer", "Failed to remove printer.");
            } else {
                root.sendPrinterNotification("Printer Removed", "Printer was successfully removed.");
                root.refresh();
            }
        }
    }

    function discoverPrinters() {
        if (root.discovering) return;
        root.discovering = true;
        root.discoveredDevices = [];
        discoverProcess.running = true;
    }

    function addPrinter(name, uri, driver) {
        // Run lpadmin, cupsenable, and cupsaccept in sequence
        addPrinterProcess.command = ["bash", "-c", "lpadmin -p '" + name + "' -v '" + uri + "' -E -m '" + driver + "' && cupsenable '" + name + "' && cupsaccept '" + name + "'"];
        addPrinterProcess.running = true;
    }

    // Overload for raw / no driver
    function addRawPrinter(name, uri) {
        addPrinterProcess.command = ["bash", "-c", "lpadmin -p '" + name + "' -v '" + uri + "' -E && cupsenable '" + name + "' && cupsaccept '" + name + "'"];
        addPrinterProcess.running = true;
    }

    // Overload with model PPD
    function addPrinterPPD(name, uri, ppd) {
        addPrinterProcess.command = ["bash", "-c", "lpadmin -p '" + name + "' -v '" + uri + "' -E -P '" + ppd + "' && cupsenable '" + name + "' && cupsaccept '" + name + "'"];
        addPrinterProcess.running = true;
    }

    function deletePrinter(name) {
        deletePrinterProcess.command = ["lpadmin", "-x", name];
        deletePrinterProcess.running = true;
    }

    function sendPrinterNotification(summary, body) {
        if (typeof Notifications !== "undefined") {
            Notifications.notifyInternal({
                "appName": "Printer",
                "summary": summary,
                "body": body,
                "urgency": NotificationUrgency.Normal,
                "popup": true,
                "expireTimeout": 4000
            });
        } else {
            Quickshell.execDetached(["notify-send", "-a", "Printer", summary, body]);
        }
    }

    function updateJobs(newJobs, newCompletedJobs) {
        // 1. Detect if any active job just completed or cancelled
        for (let i = 0; i < root.previousJobs.length; i++) {
            const prevJob = root.previousJobs[i];
            const stillActive = newJobs.some(j => j.id === prevJob.id);
            
            if (!stillActive) {
                const completed = newCompletedJobs.some(j => j.id === prevJob.id);
                if (completed) {
                    root.sendPrinterNotification("Print Job Completed", "Successfully printed '" + (prevJob.file || prevJob.id) + "' on printer " + prevJob.printer);
                } else {
                    root.sendPrinterNotification("Print Job Cancelled", "Job '" + (prevJob.file || prevJob.id) + "' on printer " + prevJob.printer + " was cancelled or failed");
                }
            }
        }
        
        // 2. Detect if any new job started printing
        for (let i = 0; i < newJobs.length; i++) {
            const newJob = newJobs[i];
            const wasActive = root.previousJobs.some(j => j.id === newJob.id);
            
            if (!wasActive) {
                root.sendPrinterNotification("Printing Document", "Printing '" + (newJob.file || newJob.id) + "' on printer " + newJob.printer);
            }
        }
        
        // Update properties
        root.jobs = newJobs;
        root.completedJobs = newCompletedJobs;
        root.previousJobs = newJobs;
        
        // Calculate isPrinting
        let printing = false;
        for (let i = 0; i < newJobs.length; i++) {
            if (newJobs[i].status === "processing") {
                printing = true;
                break;
            }
        }
        root.isPrinting = printing;
    }

    property Process probeProcess: Process {
        id: probeProcess
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.probedDevices = JSON.parse(data);
                } catch (e) {
                    console.warn("PrinterService: Failed to parse probe data: " + e);
                }
            }
        }
        onExited: exitCode => {
            root.probing = false;
        }
    }

    function probeIp(ipOrHost) {
        if (root.probing) {
            probeProcess.running = false;
        }
        root.probing = true;
        root.probedDevices = [];
        probeProcess.command = ["python3", Quickshell.shellDir + "/scripts/printer_monitor.py", "--probe", ipOrHost];
        probeProcess.running = true;
    }

    property Process driversProcess: Process {
        id: driversProcess
        stdout: SplitParser {
            onRead: data => {
                try {
                    root.searchedDrivers = JSON.parse(data);
                } catch (e) {
                    console.warn("PrinterService: Failed to parse drivers data: " + e);
                }
            }
        }
        onExited: exitCode => {
            root.searchingDrivers = false;
        }
    }

    function searchDrivers(query) {
        if (root.searchingDrivers) {
            driversProcess.running = false;
        }
        root.searchingDrivers = true;
        driversProcess.command = ["python3", Quickshell.shellDir + "/scripts/printer_monitor.py", "--drivers", query];
        driversProcess.running = true;
    }
}
