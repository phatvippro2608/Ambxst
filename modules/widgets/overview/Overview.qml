import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.modules.globals
import qs.modules.theme
import qs.modules.components
import qs.modules.bar.workspaces
import qs.modules.services
import qs.config

Item {
    id: overviewRoot

    property var currentScreen: null
    readonly property string screenName: currentScreen ? (currentScreen.name || currentScreen) : ""
    readonly property var monitor: {
        if (screenName !== "") {
            const mons = CompositorData.monitors || [];
            for (let i = 0; i < mons.length; i++) {
                if (mons[i].name === screenName) return mons[i];
            }
        }
        return AxctlService.focusedMonitor;
    }
    readonly property int monitorId: monitor?.id ?? -1
    readonly property real monitorX: currentScreen ? (currentScreen.x || 0) : 0
    readonly property real monitorY: currentScreen ? (currentScreen.y || 0) : 0

    readonly property var windowList: CompositorData.windowList
    readonly property string barPosition: Config.bar.position
    readonly property var barPanel: monitor ? Visibilities.getBarPanelForScreen(monitor.name) : null
    readonly property bool isBarPinned: barPanel ? barPanel.pinned : (Config.bar.pinnedOnStartup ?? true)
    readonly property int barReserved: isBarPinned ? (Config.showBackground ? 44 : 40) : 0

    readonly property real workspaceSpacing: Config.overview.workspaceSpacing || 16
    readonly property real workspacePadding: 8
    readonly property color activeBorderColor: Styling.srItem("overprimary")

    readonly property int rows: Config.overview.rows || 2
    readonly property int columns: Config.overview.columns || 5
    readonly property int workspacesShown: rows * columns
    readonly property int workspaceGroup: Math.floor((monitor?.activeWorkspace?.id - 1 || 0) / workspacesShown)

    // Generate fixed array of workspaces for the current group
    readonly property var activeWorkspacesForMonitor: {
        let wsList = [];
        let startWs = workspaceGroup * workspacesShown + 1;
        for (let i = 0; i < workspacesShown; i++) {
            wsList.push({ id: startWs + i, name: (startWs + i).toString() });
        }
        return wsList;
    }
    
    readonly property int totalWorkspaces: workspacesShown

    // Dynamically calculate scale based on how many columns/rows to ensure it fits nicely
    // Cap the maximum scale so it doesn't become huge
    readonly property real scale: {
        let hScale = 0.8 / Math.max(1, columns);
        let vScale = 0.8 / Math.max(1, rows);
        let calculated = Math.min(hScale, vScale);
        return Math.min(Config.overview.scale || 0.15, calculated);
    }

    readonly property real workspaceImplicitWidth: {
        if (!monitor) return 200;
        const isRotated = (monitor.transform % 2 === 1);
        const monitorScale = monitor.scale || 1.0;
        const width = isRotated ? (monitor.height || 1920) : (monitor.width || 1920);
        return Math.max(0, Math.round((width / monitorScale) * scale));
    }

    readonly property real workspaceImplicitHeight: {
        if (!monitor) return 150;
        const isRotated = (monitor.transform % 2 === 1);
        const monitorScale = monitor.scale || 1.0;
        const height = isRotated ? (monitor.width || 1080) : (monitor.height || 1080);
        return Math.max(0, Math.round((height / monitorScale) * scale));
    }

    property string searchQuery: ""
    property var matchingWindows: []
    property int selectedMatchIndex: 0

    function resetSearch() {
        searchQuery = "";
        matchingWindows = [];
        selectedMatchIndex = 0;
    }

    onSearchQueryChanged: updateMatchingWindows()
    onWindowListChanged: updateMatchingWindows()

    function fuzzyMatch(query, target) {
        if (query.length === 0) return true;
        if (target.length === 0) return false;
        let queryIndex = 0;
        for (let i = 0; i < target.length && queryIndex < query.length; i++) {
            if (target[i] === query[queryIndex]) queryIndex++;
        }
        return queryIndex === query.length;
    }

    function fuzzyScore(query, target) {
        if (query.length === 0) return 0;
        if (target.length === 0) return -1;
        if (target.includes(query)) return 1000 + (100 - target.length);
        let queryIndex = 0, consecutiveMatches = 0, maxConsecutive = 0, score = 0;
        for (let i = 0; i < target.length && queryIndex < query.length; i++) {
            if (target[i] === query[queryIndex]) {
                queryIndex++; consecutiveMatches++;
                maxConsecutive = Math.max(maxConsecutive, consecutiveMatches);
                if (i === 0 || target[i - 1] === ' ' || target[i - 1] === '-' || target[i - 1] === '_') score += 10;
            } else { consecutiveMatches = 0; }
        }
        if (queryIndex !== query.length) return -1;
        return score + maxConsecutive * 5;
    }

    function updateMatchingWindows() {
        if (searchQuery.length === 0) {
            matchingWindows = []; selectedMatchIndex = 0; return;
        }
        const query = searchQuery.toLowerCase();
        const matches = windowList.filter(win => {
            if (!win) return false;
            const title = (win.title || "").toLowerCase();
            const windowClass = (win.class || "").toLowerCase();
            return fuzzyMatch(query, title) || fuzzyMatch(query, windowClass);
        }).map(win => ({
            window: win,
            score: Math.max(fuzzyScore(query, (win.title || "").toLowerCase()), fuzzyScore(query, (win.class || "").toLowerCase()))
        })).sort((a, b) => b.score - a.score).map(item => item.window);

        matchingWindows = matches;
        selectedMatchIndex = matches.length > 0 ? 0 : -1;
    }

    function navigateToSelectedWindow() {
        if (matchingWindows.length === 0 || selectedMatchIndex < 0) return;
        const win = matchingWindows[selectedMatchIndex];
        if (!win) return;
        Visibilities.setActiveModule("", true);
        Qt.callLater(() => { AxctlService.dispatch(`focuswindow address:${win.address}`); });
    }

    function selectNextMatch() {
        if (matchingWindows.length === 0) return;
        selectedMatchIndex = (selectedMatchIndex + 1) % matchingWindows.length;
    }

    function selectPrevMatch() {
        if (matchingWindows.length === 0) return;
        selectedMatchIndex = (selectedMatchIndex - 1 + matchingWindows.length) % matchingWindows.length;
    }

    function isWindowMatched(windowAddress) {
        if (searchQuery.length === 0) return false;
        return matchingWindows.some(win => win?.address === windowAddress);
    }

    function isWindowSelected(windowAddress) {
        if (matchingWindows.length === 0 || selectedMatchIndex < 0) return false;
        return matchingWindows[selectedMatchIndex]?.address === windowAddress;
    }

    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1

    implicitWidth: overviewBackground.implicitWidth
    implicitHeight: overviewBackground.implicitHeight

    Item {
        id: overviewBackground
        anchors.centerIn: parent
        implicitWidth: workspaceColumnLayout.implicitWidth
        implicitHeight: workspaceColumnLayout.implicitHeight

        GridLayout {
            id: workspaceColumnLayout
            anchors.centerIn: parent
            rowSpacing: workspaceSpacing
            columnSpacing: workspaceSpacing
            columns: overviewRoot.columns

            Repeater {
                model: overviewRoot.activeWorkspacesForMonitor
                delegate: Rectangle {
                    id: workspace
                    property var wsData: modelData
                    property int workspaceValue: wsData.id
                    property color defaultWorkspaceColor: Colors.background
                    property color hoveredWorkspaceColor: Colors.surfaceContainer
                    property color hoveredBorderColor: Colors.outline
                    property bool hoveredWhileDragging: false
                    property bool isHoveredMouse: false

                    implicitWidth: overviewRoot.workspaceImplicitWidth + workspacePadding
                    implicitHeight: overviewRoot.workspaceImplicitHeight + workspacePadding
                    color: isHoveredMouse && overviewRoot.draggingTargetWorkspace === -1 ? hoveredWorkspaceColor : "transparent"
                    radius: Styling.radius(2)
                    border.width: 2
                    border.color: hoveredWhileDragging || isHoveredMouse ? hoveredBorderColor : "transparent"
                    clip: true

                    TintedWallpaper {
                        id: workspaceWallpaper
                        anchors.fill: parent
                        radius: Styling.radius(2)
                        tintEnabled: GlobalStates.wallpaperManager ? GlobalStates.wallpaperManager.tintEnabled : false
                        property string lockscreenFramePath: {
                            if (!GlobalStates.wallpaperManager) return "";
                            return GlobalStates.wallpaperManager.getLockscreenFramePath(GlobalStates.wallpaperManager.currentWallpaper);
                        }
                        source: lockscreenFramePath ? "file://" + lockscreenFramePath : ""
                    }

                    // Workspace Number Badge
                    Rectangle {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 6
                        width: 28
                        height: 28
                        radius: 14
                        color: Colors.surfaceContainerHighest
                        border.color: Styling.srItem("overprimary")
                        border.width: 1.5
                        z: 50

                        Text {
                            anchors.centerIn: parent
                            text: workspaceValue.toString()
                            font.bold: true
                            font.pixelSize: 14
                            font.family: Config.theme.font
                            color: Colors.onSurface
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        hoverEnabled: true
                        onEntered: {
                            parent.isHoveredMouse = true;
                            GlobalStates.hoveredWorkspaceId = workspaceValue;
                        }
                        onExited: {
                            parent.isHoveredMouse = false;
                            if (GlobalStates.hoveredWorkspaceId === workspaceValue) {
                                GlobalStates.hoveredWorkspaceId = -1;
                            }
                        }
                        onClicked: {
                            if (overviewRoot.draggingTargetWorkspace === -1) {
                                Visibilities.setActiveModule("");
                                AxctlService.dispatch(`workspace ${workspaceValue}`);
                            }
                        }
                    }

                    DropArea {
                        anchors.fill: parent
                        onEntered: {
                            overviewRoot.draggingTargetWorkspace = workspaceValue;
                            parent.isHoveredDrag = true;
                        }
                        onExited: {
                            parent.isHoveredDrag = false;
                            if (overviewRoot.draggingTargetWorkspace == workspaceValue)
                                overviewRoot.draggingTargetWorkspace = -1;
                        }
                        onDropped: drop => {
                            parent.isHoveredDrag = false;
                            overviewRoot.draggingTargetWorkspace = -1;
                        }
                    }
                }
            }
        }

        Item {
            id: windowSpace
            anchors.centerIn: parent
            implicitWidth: workspaceColumnLayout.implicitWidth
            implicitHeight: workspaceColumnLayout.implicitHeight

            readonly property var filteredWindowData: {
                const monId = overviewRoot.monitorId;
                const toplevels = ToplevelManager.toplevels.values;
                return overviewRoot.windowList.filter(win => {
                    const wsId = win?.workspace?.id;
                    const wsMatch = overviewRoot.activeWorkspacesForMonitor.some(ws => ws.id === wsId);
                    return wsMatch && win.monitor === monId;
                }).map(win => ({
                    windowData: win,
                    toplevel: (() => {
                        const cls = win.class || "";
                        if (!cls) return null;
                        const candidates = toplevels.filter(t => t.appId === cls);
                        if (candidates.length <= 1) return candidates[0] || null;
                        return candidates.find(t => t.title === (win.title || "")) || candidates[0];
                    })()
                }));
            }

            Repeater {
                model: windowSpace.filteredWindowData

                delegate: OverviewWindow {
                    id: window
                    required property var modelData
                    windowData: modelData.windowData
                    toplevel: modelData.toplevel
                    scale: overviewRoot.scale
                    availableWorkspaceWidth: overviewRoot.workspaceImplicitWidth
                    availableWorkspaceHeight: overviewRoot.workspaceImplicitHeight
                    monitorData: overviewRoot.monitor
                    monitorX: overviewRoot.monitorX
                    monitorY: overviewRoot.monitorY
                    barPosition: overviewRoot.barPosition
                    barReserved: overviewRoot.barReserved

                    isSearchMatch: overviewRoot.isWindowMatched(windowData?.address)
                    isSearchSelected: overviewRoot.isWindowSelected(windowData?.address)

                    property int workspaceColIndex: Math.max(0, (windowData?.workspace.id - 1) % overviewRoot.columns)
                    property int workspaceRowIndex: Math.max(0, Math.floor((windowData?.workspace.id - 1) % overviewRoot.workspacesShown / overviewRoot.columns))

                    xOffset: Math.round((overviewRoot.workspaceImplicitWidth + workspacePadding + workspaceSpacing) * workspaceColIndex + workspacePadding / 2)
                    yOffset: Math.round((overviewRoot.workspaceImplicitHeight + workspacePadding + workspaceSpacing) * workspaceRowIndex + workspacePadding / 2)

                    onDragStarted: overviewRoot.draggingFromWorkspace = windowData?.workspace.id || -1
                    onDragFinished: targetWorkspace => {
                        overviewRoot.draggingFromWorkspace = -1;
                        if (targetWorkspace !== -1 && targetWorkspace !== windowData?.workspace.id) {
                            AxctlService.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${windowData?.address}`);
                        }
                    }
                    onWindowClicked: {
                        Visibilities.setActiveModule("", true);
                        Qt.callLater(() => {
                            AxctlService.dispatch(`focuswindow address:${windowData.address}`);
                        });
                    }
                    onWindowClosed: {
                        AxctlService.dispatch(`closewindow address:${windowData.address}`);
                    }
                }
            }

            Rectangle {
                id: focusedWorkspaceIndicator
                property int activeWsId: monitor?.activeWorkspace?.id || 1
                property int wsIndex: overviewRoot.activeWorkspacesForMonitor.findIndex(ws => ws.id === activeWsId)
                property int activeWorkspaceRowIndex: Math.max(0, Math.floor(wsIndex / overviewRoot.columns))
                property int activeWorkspaceColIndex: Math.max(0, wsIndex % overviewRoot.columns)

                visible: wsIndex !== -1
                x: Math.round((overviewRoot.workspaceImplicitWidth + workspacePadding + workspaceSpacing) * activeWorkspaceColIndex)
                y: Math.round((overviewRoot.workspaceImplicitHeight + workspacePadding + workspaceSpacing) * activeWorkspaceRowIndex)
                width: Math.round(overviewRoot.workspaceImplicitWidth + workspacePadding)
                height: Math.round(overviewRoot.workspaceImplicitHeight + workspacePadding)
                color: "transparent"
                radius: Styling.radius(2)
                border.width: 2
                border.color: overviewRoot.activeBorderColor

                Behavior on x { enabled: Config.animDuration > 0; NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart } }
                Behavior on y { enabled: Config.animDuration > 0; NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart } }
            }
        }
    }
}
