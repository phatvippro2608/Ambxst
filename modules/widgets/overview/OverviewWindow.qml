pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.modules.globals
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config

Item {
    id: root

    property var windowData
    property var toplevel
    property var monitorData: null
    property real monitorX: 0
    property real monitorY: 0
    property real scale
    property real availableWorkspaceWidth
    property real availableWorkspaceHeight
    property real xOffset: 0
    property real yOffset: 0

    property bool hovered: false
    property bool pressed: false
    property bool atInitPosition: (initX == x && initY == y)

    property string barPosition: "top"
    property int barReserved: 0

    property bool isSearchMatch: false
    property bool isSearchSelected: false

    property real overrideX: -1
    property real overrideY: -1
    property bool useOverridePosition: false

    readonly property real initX: {
        if (useOverridePosition && overrideX >= 0) return overrideX;
        let base = (windowData?.at?.[0] || 0) - monitorX;
        return Math.round(Math.max(base * scale, 0) + xOffset);
    }
    readonly property real initY: {
        if (useOverridePosition && overrideY >= 0) return overrideY;
        let base = (windowData?.at?.[1] || 0) - monitorY;
        return Math.round(Math.max(base * scale, 0) + yOffset);
    }
    readonly property real targetWindowWidth: Math.round((windowData?.size[0] || 100) * scale)
    readonly property real targetWindowHeight: Math.round((windowData?.size[1] || 100) * scale)
    readonly property bool compactMode: targetWindowHeight < 60 || targetWindowWidth < 60
    readonly property string iconPath: AppSearch.guessIcon(windowData?.class || "")
    readonly property int calculatedRadius: Styling.radius(-2)

    signal dragStarted
    signal dragFinished(int targetWorkspace)
    signal windowClicked
    signal windowClosed

    x: initX
    y: initY
    width: targetWindowWidth
    height: targetWindowHeight
    z: atInitPosition ? 1 : 99999

    Drag.active: false
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2

    clip: true

    Timer {
        id: resetOverrideTimer
        interval: 200
        onTriggered: { root.useOverridePosition = false; }
    }

    onWindowDataChanged: {
        if (useOverridePosition) resetOverrideTimer.restart();
    }

    Behavior on x { enabled: Config.animDuration > 0 && !root.useOverridePosition; NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart } }
    Behavior on y { enabled: Config.animDuration > 0 && !root.useOverridePosition; NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart } }
    Behavior on width { enabled: Config.animDuration > 0; NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart } }
    Behavior on height { enabled: Config.animDuration > 0; NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutQuart } }

    ClippingRectangle {
        anchors.fill: parent
        radius: root.calculatedRadius
        antialiasing: true
        border.color: Colors.background
        border.width: 0

        ScreencopyView {
            id: windowPreview
            anchors.fill: parent
            captureSource: Config.performance.windowPreview && GlobalStates.overviewOpen ? root.toplevel : null
            live: GlobalStates.overviewOpen
            visible: Config.performance.windowPreview
        }
    }

    Rectangle {
        id: previewBackground
        anchors.fill: parent
        radius: root.calculatedRadius
        color: pressed ? Colors.surfaceBright : hovered ? Colors.surface : Colors.background
        border.color: root.isSearchSelected ? Colors.tertiary : root.isSearchMatch ? Styling.srItem("overprimary") : Styling.srItem("overprimary")
        border.width: root.isSearchSelected ? 3 : root.isSearchMatch ? 2 : (hovered ? 2 : 0)
        visible: !windowPreview.hasContent || !Config.performance.windowPreview
        Behavior on color { enabled: Config.animDuration > 0; ColorAnimation { duration: Config.animDuration / 2 } }
        Behavior on border.width { enabled: Config.animDuration > 0; NumberAnimation { duration: Config.animDuration / 2 } }
    }

    Image {
        mipmap: true
        id: windowIcon
        readonly property real iconSize: Math.round(Math.min(root.targetWindowWidth, root.targetWindowHeight) * (root.compactMode ? 0.6 : 0.35))
        anchors.centerIn: parent
        width: iconSize
        height: iconSize
        source: Quickshell.iconPath(root.iconPath, "image-missing")
        sourceSize: Qt.size(iconSize, iconSize)
        asynchronous: true
        visible: !windowPreview.hasContent || !Config.performance.windowPreview
        z: 10
    }

    Rectangle {
        id: previewOverlay
        anchors.fill: parent
        radius: root.calculatedRadius
        color: pressed ? Qt.rgba(Colors.surfaceContainerHighest.r, Colors.surfaceContainerHighest.g, Colors.surfaceContainerHighest.b, 0.5) : hovered ? Qt.rgba(Colors.surfaceContainer.r, Colors.surfaceContainer.g, Colors.surfaceContainer.b, 0.2) : "transparent"
        border.color: root.isSearchSelected ? Colors.tertiary : root.isSearchMatch ? Styling.srItem("overprimary") : Styling.srItem("overprimary")
        border.width: root.isSearchSelected ? 3 : root.isSearchMatch ? 2 : (hovered ? 2 : 0)
        visible: windowPreview.hasContent && Config.performance.windowPreview
        z: 5
        Behavior on border.width { enabled: Config.animDuration > 0; NumberAnimation { duration: Config.animDuration / 2 } }
    }

    Rectangle {
        visible: root.isSearchSelected && !root.Drag.active
        anchors.fill: parent
        anchors.margins: -4
        radius: root.calculatedRadius + 4
        color: "transparent"
        border.color: Colors.tertiary
        border.width: 2
        opacity: 0.6
        z: -1
    }

    Image {
        mipmap: true
        visible: windowPreview.hasContent && !root.compactMode && Config.performance.windowPreview
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 4
        width: 16
        height: 16
        source: Quickshell.iconPath(root.iconPath, "image-missing")
        sourceSize: Qt.size(16, 16)
        asynchronous: true
        opacity: 0.8
        z: 10
    }

    Rectangle {
        visible: root.windowData?.xwayland || false
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 2
        width: 6
        height: 6
        radius: 3
        color: Colors.error
        z: 10
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        drag.target: parent

        onEntered: { root.hovered = true; GlobalStates.hoveredWindowAddress = windowData?.address || ""; }
        onExited: { root.hovered = false; if (GlobalStates.hoveredWindowAddress === windowData?.address) GlobalStates.hoveredWindowAddress = ""; }

        onPressed: mouse => {
            root.pressed = true;
            root.Drag.active = true;
            root.Drag.source = root;
            root.dragStarted();
        }

        onReleased: mouse => {
            const overviewRoot = parent.parent.parent.parent;
            let targetWorkspace = overviewRoot.draggingTargetWorkspace;

            root.pressed = false;
            root.Drag.active = false;

            if (mouse.button === Qt.LeftButton) {
                if (targetWorkspace === -1) {
                    const absX = root.x + root.width / 2;
                    const absY = root.y + root.height / 2;
                    const workspaceColIndex = Math.floor(absX / (overviewRoot.workspaceImplicitWidth + overviewRoot.workspacePadding + overviewRoot.workspaceSpacing));
                    const workspaceRowIndex = Math.floor(absY / (overviewRoot.workspaceImplicitHeight + overviewRoot.workspacePadding + overviewRoot.workspaceSpacing));
                    
                    if (workspaceColIndex >= 0 && workspaceColIndex < overviewRoot.columns && 
                        workspaceRowIndex >= 0 && workspaceRowIndex < overviewRoot.rows) {
                        
                        const wsIndex = workspaceRowIndex * overviewRoot.columns + workspaceColIndex;
                        const activeWs = overviewRoot.activeWorkspacesForMonitor;
                        if (wsIndex >= 0 && wsIndex < activeWs.length) {
                            targetWorkspace = activeWs[wsIndex].id;
                        } else {
                            targetWorkspace = windowData?.workspace.id;
                        }
                    } else {
                        targetWorkspace = windowData?.workspace.id;
                    }
                }

                root.dragFinished(targetWorkspace);
                overviewRoot.draggingTargetWorkspace = -1;

                if (targetWorkspace !== -1 && targetWorkspace !== windowData?.workspace.id) {
                    if (windowData?.floating && (root.x !== root.initX || root.y !== root.initY)) {
                        const targetWsIndex = overviewRoot.activeWorkspacesForMonitor.findIndex(ws => ws.id === targetWorkspace);
                        const targetColIndex = Math.max(0, targetWsIndex % overviewRoot.columns);
                        const targetRowIndex = Math.max(0, Math.floor(targetWsIndex / overviewRoot.columns));
                        const targetXOffset = Math.round((overviewRoot.workspaceImplicitWidth + overviewRoot.workspacePadding + overviewRoot.workspaceSpacing) * targetColIndex + overviewRoot.workspacePadding / 2);
                        const targetYOffset = Math.round((overviewRoot.workspaceImplicitHeight + overviewRoot.workspacePadding + overviewRoot.workspaceSpacing) * targetRowIndex + overviewRoot.workspacePadding / 2);
                        
                        const relativeX = root.x - targetXOffset;
                        const relativeY = root.y - targetYOffset;
                        
                        const percentageX = Math.round((relativeX / root.availableWorkspaceWidth) * 100);
                        const percentageY = Math.round((relativeY / root.availableWorkspaceHeight) * 100);
                        
                        AxctlService.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${windowData?.address}`);
                        AxctlService.dispatch(`movewindowpixel exact ${percentageX}% ${percentageY}%, address:${windowData?.address}`);
                        CompositorData.updateWindowList();
                    } else {
                        AxctlService.dispatch(`movetoworkspacesilent ${targetWorkspace}, address:${windowData?.address}`);
                        CompositorData.updateWindowList();
                    }
                    root.x = root.initX;
                    root.y = root.initY;
                } else if (windowData?.floating && (root.x !== root.initX || root.y !== root.initY)) {
                    const relativeX = root.x - root.xOffset;
                    const relativeY = root.y - root.yOffset;
                    const percentageX = Math.round((relativeX / root.availableWorkspaceWidth) * 100);
                    const percentageY = Math.round((relativeY / root.availableWorkspaceHeight) * 100);
                    const draggedX = root.x;
                    const draggedY = root.y;
                    AxctlService.dispatch(`movewindowpixel exact ${percentageX}% ${percentageY}%, address:${windowData?.address}`);
                    CompositorData.updateWindowList();
                    root.overrideX = draggedX;
                    root.overrideY = draggedY;
                    root.useOverridePosition = true;
                    root.x = draggedX;
                    root.y = draggedY;
                    resetOverrideTimer.restart();
                } else {
                    root.x = root.initX;
                    root.y = root.initY;
                }
            }
        }

        onClicked: mouse => {
            if (!root.windowData) return;
            if (mouse.button === Qt.LeftButton) {
                root.windowClicked(); // This will close overview AND focus the window
            } else if (mouse.button === Qt.MiddleButton) {
                AxctlService.dispatch(`movetoworkspacesilent special:minimized, address:${windowData.address}`);
            }
        }

        onDoubleClicked: mouse => {
            // Unused since onClicked handles it, but keep for fallback
            if (!root.windowData) return;
            if (mouse.button === Qt.LeftButton) root.windowClicked();
        }
    }

    Rectangle {
        visible: dragArea.containsMouse && !root.Drag.active && root.windowData
        anchors.bottom: parent.top
        anchors.bottomMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        width: tooltipText.implicitWidth + 16
        height: tooltipText.implicitHeight + 8
        color: Colors.inverseSurface
        radius: Styling.radius(0) / 2
        opacity: 0.9
        z: 1000

        Text {
            id: tooltipText
            anchors.centerIn: parent
            text: `${root.windowData?.title || ""}\n[${root.windowData?.class || ""}]${root.windowData?.xwayland ? " [XWayland]" : ""}`
            font.family: Config.theme.font
            font.pixelSize: 10
            color: Colors.inverseOnSurface
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
