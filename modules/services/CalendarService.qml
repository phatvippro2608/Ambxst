pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.services

Singleton {
    id: root

    property string scriptPath: Quickshell.shellDir + "/scripts/calendar_sync.py"
    
    // Cached occurrences for the current view
    property var occurrences: []

    // Map of notified event instance keys (occId + "_" + startTime) to avoid duplicates
    property var notifiedEvents: ({})
    
    // Auth status
    property bool isAuthenticated: false
    property string oauthClientId: ""
    property string oauthClientSecret: ""
    property bool isCheckingAuth: false
    
    // Sync status
    property bool isSyncing: false
    property string syncStatusMessage: ""
    
    // Loading occurrences status
    property bool isLoadingOccurrences: false

    // Date range of currently loaded occurrences
    property string loadedStart: ""
    property string loadedEnd: ""
    property bool hasTriggeredInitialSync: false

    signal occurrencesUpdated()
    signal authStatusChanged()
    signal syncCompleted(bool success, string message)

    function checkAuthStatus() {
        if (isCheckingAuth) return;
        isCheckingAuth = true;
        console.log("CalendarService: Checking auth status...");
        statusProcess.running = false;
        statusProcess.command = ["python3", scriptPath, "--status"];
        statusProcess.running = true;
    }

    function startAuth(clientId, clientSecret) {
        console.log("CalendarService: Starting OAuth flow...");
        syncStatusMessage = "Đang bắt đầu liên kết Google Calendar...";
        authProcess.running = false;
        authProcess.command = ["python3", scriptPath, "--auth", "--client-id", clientId, "--client-secret", clientSecret];
        authProcess.running = true;
    }

    function sync() {
        if (isSyncing) return;
        isSyncing = true;
        syncStatusMessage = "Đang đồng bộ với Google Calendar...";
        console.log("CalendarService: Starting sync...");
        syncProcess.running = false;
        syncProcess.command = ["python3", scriptPath, "--sync"];
        syncProcess.running = true;
    }

    function loadOccurrences(start, end) {
        if (!start || !end) return;
        loadedStart = start;
        loadedEnd = end;
        isLoadingOccurrences = true;
        listProcess.running = false;
        listProcess.command = ["python3", scriptPath, "--list", "--start", start, "--end", end];
        listProcess.running = true;
    }

    function addEvent(eventObj, callback) {
        addProcess.callback = callback;
        addProcess.running = false;
        addProcess.command = ["python3", scriptPath, "--add", JSON.stringify(eventObj)];
        addProcess.running = true;
    }

    function deleteEvent(id, callback) {
        deleteProcess.callback = callback;
        deleteProcess.running = false;
        deleteProcess.command = ["python3", scriptPath, "--delete", id];
        deleteProcess.running = true;
    }

    function reloadCurrentRange() {
        if (loadedStart !== "" && loadedEnd !== "") {
            loadOccurrences(loadedStart, loadedEnd);
        }
    }

    // Check if a day has events
    function hasEvents(year, month, day) {
        var dateStr = formatDateStr(year, month, day);
        for (var i = 0; i < occurrences.length; i++) {
            if (occurrences[i].date === dateStr) {
                return true;
            }
        }
        return false;
    }

    // Get list of events for a day
    function getEventsForDay(year, month, day) {
        var dateStr = formatDateStr(year, month, day);
        var list = [];
        for (var i = 0; i < occurrences.length; i++) {
            if (occurrences[i].date === dateStr) {
                list.push(occurrences[i]);
            }
        }
        return list;
    }

    // Utility: Format date to YYYY-MM-DD
    function formatDateStr(year, month, day) {
        var mStr = month < 10 ? "0" + month : month.toString();
        var dStr = day < 10 ? "0" + day : day.toString();
        return year.toString() + "-" + mStr + "-" + dStr;
    }

    // -------------------------------------------------------------
    // PROCESSES
    // -------------------------------------------------------------

    Process {
        id: statusProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.isCheckingAuth = false;
                try {
                    var data = JSON.parse(text.trim());
                    root.oauthClientId = data.client_id || "";
                    root.oauthClientSecret = data.client_secret || "";
                    if (data.status === "authenticated") {
                        root.isAuthenticated = true;
                        if (!root.hasTriggeredInitialSync) {
                            root.hasTriggeredInitialSync = true;
                            startupSyncTimer.start();
                        }
                    } else {
                        root.isAuthenticated = false;
                    }
                    root.authStatusChanged();
                    console.log("CalendarService: Auth status checked. Authenticated:", root.isAuthenticated);
                } catch (e) {
                    console.warn("CalendarService: Failed to parse auth status:", e);
                }
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (text.trim().length > 0) {
                    console.warn("CalendarService statusProcess stderr:", text);
                }
            }
        }
    }

    Process {
        id: authProcess
        stdout: SplitParser {
            onRead: text => {
                console.log("CalendarService auth Process stdout:", text.trim());
                try {
                    var data = JSON.parse(text.trim());
                    if (data.auth_url) {
                        console.log("CalendarService: Opening OAuth URL:", data.auth_url);
                        root.syncStatusMessage = "Vui lòng hoàn tất xác thực trong trình duyệt...";
                        Qt.openUrlExternally(data.auth_url);
                        if (typeof Notifications !== "undefined") {
                            Notifications.notifyInternal({
                                summary: "Đồng bộ Lịch",
                                body: "Vui lòng đăng nhập tài khoản Google trên trình duyệt để liên kết.",
                                urgency: 1 // Normal
                            });
                        }
                    } else if (data.status === "success") {
                        console.log("CalendarService: OAuth success!");
                        root.syncStatusMessage = "Liên kết thành công!";
                        if (typeof Notifications !== "undefined") {
                            Notifications.notifyInternal({
                                summary: "Đồng bộ Lịch",
                                body: "Liên kết tài khoản Google thành công!",
                                urgency: 1
                            });
                        }
                        root.checkAuthStatus();
                        root.sync();
                    } else if (data.status === "error") {
                        console.warn("CalendarService auth error details:", data.message);
                        root.syncStatusMessage = "Lỗi: " + data.message;
                        if (typeof Notifications !== "undefined") {
                            Notifications.notifyInternal({
                                summary: "Đồng bộ Lịch",
                                body: "Lỗi liên kết: " + data.message,
                                urgency: 2 // Critical/High
                            });
                        }
                    }
                } catch (e) {
                    // Ignore non-json or server logs
                }
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (text.trim().length > 0) {
                    console.error("CalendarService authProcess stderr:", text);
                    root.syncStatusMessage = "Lỗi khởi chạy xác thực!";
                }
            }
        }
        onExited: (code, status) => {
            console.log("CalendarService authProcess exited with code:", code, "status:", status);
            root.checkAuthStatus();
        }
    }

    Process {
        id: syncProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.isSyncing = false;
                try {
                    var data = JSON.parse(text.trim());
                    if (data.status === "success") {
                        root.syncStatusMessage = "Đồng bộ hoàn tất.";
                        root.syncCompleted(true, data.message);
                        root.reloadCurrentRange();
                    } else {
                        root.syncStatusMessage = data.message || "Đồng bộ thất bại.";
                        // Commented out to prevent annoying notifications during background syncs
                        /*
                        if (typeof Notifications !== "undefined") {
                            Notifications.notifyInternal({
                                summary: "Đồng bộ Lịch",
                                body: "Đồng bộ thất bại: " + root.syncStatusMessage,
                                urgency: 2
                            });
                        }
                        */
                        root.syncCompleted(false, root.syncStatusMessage);
                    }
                } catch (e) {
                    root.syncStatusMessage = "Đồng bộ hoàn tất.";
                    root.syncCompleted(true, "Finished sync.");
                    root.reloadCurrentRange();
                }
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (text.trim().length > 0) {
                    console.error("CalendarService syncProcess stderr:", text);
                }
            }
        }
        onExited: (code, status) => {
            root.isSyncing = false;
        }
    }

    Process {
        id: listProcess
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.isLoadingOccurrences = false;
                try {
                    var trimmed = text.trim();
                    console.log("CalendarService listProcess output length:", trimmed.length);
                    if (trimmed.length > 0) {
                        console.log("CalendarService listProcess output sample:", trimmed.substring(0, 500));
                        root.occurrences = JSON.parse(trimmed);
                        root.occurrencesUpdated();
                    }
                } catch (e) {
                    console.warn("CalendarService list parse error:", e);
                }
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (text.trim().length > 0) {
                    console.error("CalendarService listProcess stderr:", text);
                }
            }
        }
        onExited: (code, status) => {
            root.isLoadingOccurrences = false;
        }
    }

    Process {
        id: addProcess
        property var callback: null
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var data = JSON.parse(text.trim());
                    if (data.status === "success") {
                        if (addProcess.callback) {
                            addProcess.callback(true, data.event);
                        }
                        if (typeof Notifications !== "undefined") {
                            Notifications.notifyInternal({
                                summary: "Lịch biểu",
                                body: "Đã thêm sự kiện \"" + data.event.summary + "\" thành công!",
                                urgency: 1
                            });
                        }
                        if (root.isAuthenticated) {
                            root.sync();
                        }
                    } else if (addProcess.callback) {
                        addProcess.callback(false, data.message || "Failed");
                    }
                } catch (e) {
                    if (addProcess.callback) addProcess.callback(false, "Parse error");
                }
                root.reloadCurrentRange();
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (text.trim().length > 0) {
                    console.error("CalendarService addProcess stderr:", text);
                }
            }
        }
    }

    Process {
        id: deleteProcess
        property var callback: null
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var data = JSON.parse(text.trim());
                    if (data.status === "success") {
                        if (deleteProcess.callback) {
                            deleteProcess.callback(true, data.message);
                        }
                        if (typeof Notifications !== "undefined") {
                            Notifications.notifyInternal({
                                summary: "Lịch biểu",
                                body: "Đã xóa sự kiện thành công!",
                                urgency: 1
                            });
                        }
                        if (root.isAuthenticated) {
                            root.sync();
                        }
                    } else if (deleteProcess.callback) {
                        deleteProcess.callback(false, data.message || "Failed");
                    }
                } catch (e) {
                    if (deleteProcess.callback) deleteProcess.callback(false, "Parse error");
                }
                root.reloadCurrentRange();
            }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                if (text.trim().length > 0) {
                    console.error("CalendarService deleteProcess stderr:", text);
                }
            }
        }
    }

    // Automatically sync periodically (every 15 minutes = 900000ms)
    Timer {
        id: autoSyncTimer
        interval: 900000
        running: root.isAuthenticated
        repeat: true
        onTriggered: {
            console.log("CalendarService: Triggering periodic background sync...");
            root.sync();
        }
    }

    // Trigger sync once after startup delay (5 seconds)
    Timer {
        id: startupSyncTimer
        interval: 5000
        running: false
        repeat: false
        onTriggered: {
            if (root.isAuthenticated) {
                console.log("CalendarService: Triggering initial startup sync...");
                root.sync();
            }
        }
    }

    Timer {
        id: alertTimer
        interval: 30000 // 30 seconds
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            var now = new Date();
            var year = now.getFullYear();
            var month = now.getMonth() + 1;
            var day = now.getDate();
            var hours = now.getHours();
            var minutes = now.getMinutes();
            
            var pad = function(n) { return n < 10 ? "0" + n : n.toString(); };
            var todayStr = year + "-" + pad(month) + "-" + pad(day);
            var nowMinStr = todayStr + "T" + pad(hours) + ":" + pad(minutes);
            
            for (var i = 0; i < occurrences.length; i++) {
                var occ = occurrences[i];
                var startTime = occ.start_time || "";
                if (!startTime) continue;
                
                var occId = occ.id;
                var key = occId + "_" + startTime;
                if (root.notifiedEvents[key]) continue;
                
                if (startTime.indexOf("T") !== -1) {
                    // Timed event, e.g. "2026-06-15T10:00:00"
                    var eventMinStr = startTime.substring(0, 16);
                    try {
                        var eventDate = new Date(startTime);
                        var diffMs = eventDate - now;
                        // Notify if event starts within the next 2 minutes, or started up to 1 minute ago
                        if (diffMs >= -60000 && diffMs <= 120000) {
                            root.notifyEvent(occ);
                        }
                    } catch (e) {
                        if (eventMinStr === nowMinStr) {
                            root.notifyEvent(occ);
                        }
                    }
                } else {
                    // All day event, e.g. "2026-06-15"
                    if (startTime === todayStr && hours === 8 && minutes === 0) {
                        root.notifyEvent(occ);
                    }
                }
            }
        }
    }

    function notifyEvent(occ) {
        var startTime = occ.start_time || "";
        var key = occ.id + "_" + startTime;
        root.notifiedEvents[key] = true;
        
        console.log("CalendarService: Notifying event:", occ.summary);
        
        var timeStr = "Cả ngày";
        if (occ.start_time && occ.start_time.indexOf("T") !== -1) {
            var parts = occ.start_time.split("T");
            timeStr = parts[1].substring(0, 5);
        }
        
        if (typeof Notifications !== "undefined") {
            Notifications.notifyInternal({
                summary: "Nhắc nhở lịch biểu (" + timeStr + ")",
                body: occ.summary + (occ.description ? "\n" + occ.description : ""),
                urgency: 1
            });
        }
    }

    Component.onCompleted: {
        console.log("CalendarService: Initialized, checking status...");
        checkAuthStatus();

        // Pre-load current month occurrences on startup so notification alerts are active
        var now = new Date();
        var year = now.getFullYear();
        var month = now.getMonth(); // 0-indexed
        
        var prevMonth = month === 0 ? 11 : month - 1;
        var prevYear = month === 0 ? year - 1 : year;
        var nextMonth = month === 11 ? 0 : month + 1;
        var nextYear = month === 11 ? year + 1 : year;
        
        var startStr = formatDateStr(prevYear, prevMonth + 1, 1);
        var endDay = new Date(nextYear, nextMonth + 1, 0).getDate();
        var endStr = formatDateStr(nextYear, nextMonth + 1, endDay);
        
        console.log("CalendarService: Pre-loading range for alerts:", startStr, "to", endStr);
        loadOccurrences(startStr, endStr);
    }
}

