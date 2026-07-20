import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.modules.globals
import qs.config

Item {
    id: workspacesWidget
    required property var bar
    required property string orientation
    readonly property var monitor: AxctlService.monitorFor(bar.screen)
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel

    readonly property int workspaceGroup: Math.floor(((monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) - 1 || 0) / Config.workspaces.shown)
    property var workspaceOccupied: []
    property var dynamicWorkspaceIds: []
    property int effectiveWorkspaceCount: Config.workspaces.dynamic ? dynamicWorkspaceIds.length : Config.workspaces.shown
    property int widgetPadding: 4
    property real radius: Styling.radius(0)
    property real startRadius: radius
    property real endRadius: radius
    
    property int baseSize: 36
    property int workspaceButtonSize: baseSize - widgetPadding * 2
    property int workspaceButtonWidth: workspaceButtonSize
    property int buttonSpacing: 6
    property real workspaceIconSize: Math.round(workspaceButtonWidth * 0.6)
    property real workspaceIconSizeShrinked: Math.round(workspaceButtonWidth * 0.5)
    property real workspaceIconOpacityShrinked: 1
    property real workspaceIconMarginShrinked: -4
    property int workspaceIndexInGroup: Config.workspaces.dynamic ? dynamicWorkspaceIds.indexOf((monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) || 1) : ((monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) - 1 || 0) % Config.workspaces.shown
    property var occupiedRanges: []
    property var otherActiveWorkspaces: []

    function getAppIconSource(win) {
        if (!win) return "";
        const entry = DesktopEntries.heuristicLookup(win.class);
        if (entry && entry.icon) {
            return Quickshell.iconPath(entry.icon, "image-missing");
        }
        return Quickshell.iconPath(AppSearch.getCachedIcon(win.class), "image-missing");
    }

    function updateWorkspaceOccupied() {
        if (Config.workspaces.dynamic) {
            // Get occupied workspace IDs using the precomputed occupation map, sorted and limited by 'shown'
            const occupiedIds = AxctlService.workspaces.values.filter(ws => CompositorData.workspaceOccupationMap[ws.id]).map(ws => ws.id).sort((a, b) => a - b).slice(0, Config.workspaces.shown);

            // Always include active workspace, even if empty
            const activeId = (monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) || 1;
            if (!occupiedIds.includes(activeId)) {
                occupiedIds.push(activeId);
                occupiedIds.sort((a, b) => a - b);
                if (occupiedIds.length > Config.workspaces.shown) {
                    occupiedIds.pop();
                }
            }

            dynamicWorkspaceIds = occupiedIds;
            workspaceOccupied = Array.from({
                length: dynamicWorkspaceIds.length
            }, (_, i) => CompositorData.workspaceOccupationMap[dynamicWorkspaceIds[i]]);
        } else {
            workspaceOccupied = Array.from({
                length: Config.workspaces.shown
            }, (_, i) => {
                const wsId = workspaceGroup * Config.workspaces.shown + i + 1;
                return CompositorData.workspaceOccupationMap[wsId];
            });
        }
        updateOccupiedRanges();

        const otherList = [];
        const currentMonitorName = monitor ? monitor.name : "";
        const allMonitors = CompositorData.monitors || [];
        for (let i = 0; i < allMonitors.length; i++) {
            const m = allMonitors[i];
            if (m && m.name !== currentMonitorName && m.activeWorkspace) {
                otherList.push(m.activeWorkspace.id);
            }
        }
        otherActiveWorkspaces = otherList;
    }

    function updateOccupiedRanges() {
        const ranges = [];
        let rangeStart = -1;

        for (let i = 0; i < effectiveWorkspaceCount; i++) {
            const isOccupied = workspaceOccupied[i];

            if (isOccupied) {
                if (rangeStart === -1) {
                    rangeStart = i;
                }
            } else {
                if (rangeStart !== -1) {
                    ranges.push({
                        start: rangeStart,
                        end: i - 1
                    });
                    rangeStart = -1;
                }
            }
        }

        if (rangeStart !== -1) {
            ranges.push({
                start: rangeStart,
                end: effectiveWorkspaceCount - 1
            });
        }

        occupiedRanges = ranges;
    }

    function workspaceLabelFontSize(value) {
        const label = String(value);
        const baseSize = Styling.fontSize(-2);
        const shrink = label.length > 1 ? 1 : 0;
        return Math.max(8, baseSize - shrink);
    }

    function getWorkspaceId(index) {
        if (Config.workspaces.dynamic) {
            return dynamicWorkspaceIds[index] || 1;
        }
        return workspaceGroup * Config.workspaces.shown + index + 1;
    }

    Timer {
        id: updateTimer
        interval: 100
        repeat: false
        onTriggered: workspacesWidget.updateWorkspaceOccupied()
    }

    // Initial update
    Component.onCompleted: updateTimer.restart()

    Connections {
        target: AxctlService.workspaces
        function onValuesChanged() {
            updateTimer.restart();
        }
    }

    Connections {
        target: AxctlService.monitors
        function onValuesChanged() {
            updateTimer.restart();
        }
    }

    Connections {
        target: activeWindow
        function onActivatedChanged() {
            updateTimer.restart();
        }
    }

    Connections {
        target: CompositorData
        function onWindowListChanged() {
            updateTimer.restart();
        }
    }

    onWorkspaceGroupChanged: {
        updateTimer.restart();
    }

    implicitWidth: orientation === "vertical" ? baseSize : (workspaceButtonSize + buttonSpacing) * effectiveWorkspaceCount - buttonSpacing + widgetPadding * 2
    implicitHeight: orientation === "vertical" ? (workspaceButtonSize + buttonSpacing) * effectiveWorkspaceCount - buttonSpacing + widgetPadding * 2 : baseSize

    readonly property bool effectiveContainBar: Config.bar.containBar && ((Config.bar.frameEnabled !== undefined ? Config.bar.frameEnabled : false))

    StyledRect {
        id: bgRect
        variant: "bg"
        anchors.fill: parent
        enableShadow: Config.showBackground && (!effectiveContainBar || Config.bar.keepBarShadow)
        
        topLeftRadius: orientation === "vertical" ? workspacesWidget.startRadius : workspacesWidget.startRadius
        topRightRadius: orientation === "vertical" ? workspacesWidget.startRadius : workspacesWidget.endRadius
        bottomLeftRadius: orientation === "vertical" ? workspacesWidget.endRadius : workspacesWidget.startRadius
        bottomRightRadius: orientation === "vertical" ? workspacesWidget.endRadius : workspacesWidget.endRadius
    }

    WheelHandler {
        onWheel: event => {
            if (event.angleDelta.y < 0)
                AxctlService.dispatch(`workspace r+1`);
            else if (event.angleDelta.y > 0)
                AxctlService.dispatch(`workspace r-1`);
        }
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.BackButton
        onPressed: event => {
            if (event.button === Qt.BackButton) {
                AxctlService.dispatch(`togglespecialworkspace`);
            }
        }
    }

    Item {
        id: rowLayout
        visible: orientation === "horizontal"
        z: 1

        anchors.fill: parent
        anchors.margins: widgetPadding

        Repeater {
            model: occupiedRanges

            StyledRect {
                variant: "focus"
                required property int index
                required property var modelData
                z: 1
                width: (modelData.end - modelData.start + 1) * workspaceButtonWidth + (modelData.end - modelData.start) * workspacesWidget.buttonSpacing
                height: workspaceButtonWidth

                radius: workspacesWidget.startRadius > 0 ? Math.max(workspacesWidget.startRadius - widgetPadding, 0) : 0

                opacity: Config.theme.srFocus.opacity

                x: modelData.start * (workspaceButtonWidth + workspacesWidget.buttonSpacing)
                y: 0

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Math.max(0, Config.animDuration - 100)
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on x {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Math.max(0, Config.animDuration - 100)
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on width {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Math.max(0, Config.animDuration - 100)
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }
    }

    Item {
        id: columnLayout
        visible: orientation === "vertical"
        z: 1

        anchors.fill: parent
        anchors.margins: widgetPadding

        Repeater {
            model: occupiedRanges

            StyledRect {
                variant: "focus"
                required property int index
                required property var modelData
                z: 1
                width: workspaceButtonWidth
                height: (modelData.end - modelData.start + 1) * workspaceButtonWidth + (modelData.end - modelData.start) * workspacesWidget.buttonSpacing

                radius: workspacesWidget.startRadius > 0 ? Math.max(workspacesWidget.startRadius - widgetPadding, 0) : 0

                opacity: Config.theme.srFocus.opacity

                x: 0
                y: modelData.start * (workspaceButtonWidth + workspacesWidget.buttonSpacing)

                Behavior on opacity {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Math.max(0, Config.animDuration - 100)
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on y {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Math.max(0, Config.animDuration - 100)
                        easing.type: Easing.OutQuad
                    }
                }
                Behavior on height {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: Math.max(0, Config.animDuration - 100)
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }
    }

    // Horizontal active workspace highlight
    StyledRect {
        id: activeHighlightH
        variant: "primary"
        visible: orientation === "horizontal"
        z: 2
        property real activeWorkspaceMargin: 4
        // Two animated indices to create a stretchy transition effect
        property real idx1: workspaceIndexInGroup
        property real idx2: workspaceIndexInGroup

        implicitWidth: Math.abs(idx1 - idx2) * (workspaceButtonWidth + workspacesWidget.buttonSpacing) + workspaceButtonWidth - activeWorkspaceMargin * 2
        implicitHeight: workspaceButtonWidth - activeWorkspaceMargin * 2
        width: implicitWidth
        height: implicitHeight

        radius: {
            const activeWorkspaceId = (monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) || 1;
            const currentWorkspaceHasWindows = CompositorData.workspaceOccupationMap[activeWorkspaceId];
            if (workspacesWidget.radius === 0)
                return 0;
            return currentWorkspaceHasWindows ? workspacesWidget.radius > 0 ? Math.max(workspacesWidget.radius - parent.widgetPadding - activeWorkspaceMargin, 0) : 0 : implicitHeight / 2;
        }

        anchors.verticalCenter: parent.verticalCenter

        x: Math.min(idx1, idx2) * (workspaceButtonWidth + workspacesWidget.buttonSpacing) + activeWorkspaceMargin + widgetPadding
        y: parent.height / 2 - implicitHeight / 2

        Behavior on activeWorkspaceMargin {

            enabled: Config.animDuration > 0

            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutQuad
            }
        }
        Behavior on idx1 {

            enabled: Config.animDuration > 0

            NumberAnimation {
                duration: Config.animDuration / 3
                easing.type: Easing.OutSine
            }
        }
        Behavior on idx2 {

            enabled: Config.animDuration > 0

            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutSine
            }
        }
    }

    // Vertical active workspace highlight
    StyledRect {
        id: activeHighlightV
        variant: "primary"
        visible: orientation === "vertical"
        z: 2
        property real activeWorkspaceMargin: 4
        // Two animated indices to create a stretchy transition effect
        property real idx1: workspaceIndexInGroup
        property real idx2: workspaceIndexInGroup

        implicitWidth: workspaceButtonWidth - activeWorkspaceMargin * 2
        implicitHeight: Math.abs(idx1 - idx2) * (workspaceButtonWidth + workspacesWidget.buttonSpacing) + workspaceButtonWidth - activeWorkspaceMargin * 2
        width: implicitWidth
        height: implicitHeight

        radius: {
            const activeWorkspaceId = (monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) || 1;
            const currentWorkspaceHasWindows = CompositorData.workspaceOccupationMap[activeWorkspaceId];
            if (workspacesWidget.radius === 0)
                return 0;
            return currentWorkspaceHasWindows ? workspacesWidget.radius > 0 ? Math.max(workspacesWidget.radius - parent.widgetPadding - activeWorkspaceMargin, 0) : 0 : implicitWidth / 2;
        }

        anchors.horizontalCenter: parent.horizontalCenter

        x: parent.width / 2 - implicitWidth / 2
        y: Math.min(idx1, idx2) * (workspaceButtonWidth + workspacesWidget.buttonSpacing) + activeWorkspaceMargin + widgetPadding

        Behavior on activeWorkspaceMargin {

            enabled: Config.animDuration > 0

            NumberAnimation {
                duration: Config.animDuration / 2
                easing.type: Easing.OutQuad
            }
        }
        Behavior on idx1 {

            enabled: Config.animDuration > 0

            NumberAnimation {
                duration: Config.animDuration / 3
                easing.type: Easing.OutSine
            }
        }
        Behavior on idx2 {

            enabled: Config.animDuration > 0

            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutSine
            }
        }
    }

    RowLayout {
        id: rowLayoutNumbers
        visible: orientation === "horizontal"
        z: 3

        spacing: workspacesWidget.buttonSpacing
        anchors.fill: parent
        anchors.margins: widgetPadding
        implicitHeight: workspaceButtonWidth

        Repeater {
            model: effectiveWorkspaceCount

            Button {
                id: button
                property int workspaceValue: getWorkspaceId(index)
                Layout.fillHeight: true
                padding: 0
                onPressed: AxctlService.dispatch(`workspace ${workspaceValue}`)
                width: workspaceButtonWidth

                background: Item {
                    id: workspaceButtonBackground
                    implicitWidth: workspaceButtonWidth
                    implicitHeight: workspaceButtonWidth
                    property var focusedWindow: {
                        const windowsInThisWorkspace = CompositorData.workspaceWindowsMap[button.workspaceValue] || [];
                        if (windowsInThisWorkspace.length === 0)
                            return null;
                        // Get the window with the lowest focusHistoryID (most recently focused)
                        return windowsInThisWorkspace.reduce((best, win) => {
                            const bestFocus = (best && best.focusHistoryID !== undefined ? best.focusHistoryID : Infinity);
                            const winFocus = (win && win.focusHistoryID !== undefined ? win.focusHistoryID : Infinity);
                            return winFocus < bestFocus ? win : best;
                        }, null);
                    }
                    property var sortedWindows: {
                        const wins = CompositorData.workspaceWindowsMap[button.workspaceValue] || [];
                        return wins.slice().sort((a, b) => {
                            const aFocus = a.focusHistoryID !== undefined ? a.focusHistoryID : Infinity;
                            const bFocus = b.focusHistoryID !== undefined ? b.focusHistoryID : Infinity;
                            return aFocus - bFocus;
                        });
                    }
                    property var stackModel: {
                        const wins = sortedWindows;
                        const modelList = [];
                        if (wins.length === 0) return modelList;
                        if (wins.length <= 3) {
                            for (let i = 0; i < wins.length; i++) {
                                modelList.push({ type: "icon", win: wins[i] });
                            }
                        } else {
                            for (let i = 0; i < 3; i++) {
                                modelList.push({ type: "icon", win: wins[i] });
                            }
                            modelList.push({ type: "badge", count: wins.length - 3 });
                        }
                        return modelList;
                    }

                    readonly property bool isActiveOnOtherMonitor: workspacesWidget.otherActiveWorkspaces.includes(button.workspaceValue)

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.width / 2
                        color: "transparent"
                        border.color: Colors.primary || "#ffb3ae"
                        border.width: 1.5
                        opacity: workspaceButtonBackground.isActiveOnOtherMonitor ? 0.6 : 0
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }
                    }

                    Text {
                        opacity: Config.workspaces.alwaysShowNumbers || ((Config.workspaces.showNumbers && (!Config.workspaces.showAppIcons || !workspaceButtonBackground.focusedWindow || Config.workspaces.alwaysShowNumbers)) || (Config.workspaces.alwaysShowNumbers && !Config.workspaces.showAppIcons)) ? 1 : 0
                        z: 3

                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 1
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: Config.theme.font
                        font.pixelSize: workspaceLabelFontSize(text)
                        text: `${button.workspaceValue}`
                        elide: Text.ElideRight
                        color: ((monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) == button.workspaceValue) ? Styling.srItem("primary") : (workspaceOccupied[index] ? Colors.overBackground : Colors.overSecondaryFixedVariant)

                        Behavior on opacity {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                    Rectangle {
                        opacity: (Config.workspaces.showNumbers || Config.workspaces.alwaysShowNumbers || (Config.workspaces.showAppIcons && workspaceButtonBackground.focusedWindow)) ? 0 : (((monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) == button.workspaceValue) || workspaceOccupied[index] ? 1 : 0.5)
                        visible: opacity > 0
                        anchors.centerIn: parent
                        width: workspaceButtonWidth * 0.2
                        height: width
                        radius: width / 2
                        color: ((monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) == button.workspaceValue) ? Styling.srItem("primary") : Colors.overBackground

                        Behavior on opacity {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                    Item {
                        id: appIconContainer
                        anchors.fill: parent
                        opacity: !Config.workspaces.showAppIcons ? 0 : (workspaceButtonBackground.focusedWindow && !Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? 1 : workspaceButtonBackground.focusedWindow ? workspaceIconOpacityShrinked : 0
                        visible: opacity > 0

                        Row {
                            id: stackRow
                            spacing: -Math.round(itemSize * 0.35)

                            readonly property bool isCentered: !Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons
                            readonly property int itemSize: isCentered ? workspaceIconSize : workspaceIconSizeShrinked

                            anchors.centerIn: isCentered ? parent : undefined
                            anchors.bottom: isCentered ? undefined : parent.bottom
                            anchors.right: isCentered ? undefined : parent.right
                            anchors.bottomMargin: isCentered ? 0 : workspaceIconMarginShrinked
                            anchors.rightMargin: isCentered ? 0 : workspaceIconMarginShrinked

                            Repeater {
                                model: workspaceButtonBackground.stackModel

                                delegate: Item {
                                    id: stackDelegate
                                    required property var modelData
                                    required property int index

                                    z: index
                                    width: stackRow.itemSize
                                    height: stackRow.itemSize

                                    Rectangle {
                                        width: stackRow.itemSize
                                        height: stackRow.itemSize
                                        radius: width / 2
                                        color: modelData.type === "badge" ? (Colors.primary || "#ffb3ae") : (Colors.surfaceContainerLow || "#231919")
                                        border.color: Colors.background || "#1a1111"
                                        border.width: 1

                                        IconImage {
                                            id: appIcon
                                            visible: modelData.type === "icon"
                                            anchors.centerIn: parent
                                            source: modelData.type === "icon" ? workspacesWidget.getAppIconSource(modelData.win) : ""
                                            implicitSize: Math.round(parent.width * 0.7)
                                        }

                                        Tinted {
                                            visible: modelData.type === "icon"
                                            sourceItem: appIcon
                                            anchors.fill: appIcon
                                        }

                                        Text {
                                            visible: modelData.type === "badge"
                                            anchors.centerIn: parent
                                            text: modelData.type === "badge" ? "+" + modelData.count : ""
                                            font.family: Config.theme.font
                                            font.pixelSize: Math.round(parent.width * 0.5)
                                            font.bold: true
                                            color: Colors.overPrimary || "#571d1c"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        id: columnLayoutNumbers
        visible: orientation === "vertical"
        z: 3

        spacing: workspacesWidget.buttonSpacing
        anchors.fill: parent
        anchors.margins: widgetPadding
        implicitWidth: workspaceButtonWidth

        Repeater {
            model: effectiveWorkspaceCount

            Button {
                id: buttonVert
                property int workspaceValue: getWorkspaceId(index)
                Layout.fillWidth: true
                padding: 0
                onPressed: AxctlService.dispatch(`workspace ${workspaceValue}`)
                height: workspaceButtonWidth

                background: Item {
                    id: workspaceButtonBackgroundVert
                    implicitWidth: workspaceButtonWidth
                    implicitHeight: workspaceButtonWidth
                    property var focusedWindow: {
                        const windowsInThisWorkspace = CompositorData.workspaceWindowsMap[buttonVert.workspaceValue] || [];
                        if (windowsInThisWorkspace.length === 0)
                            return null;
                        // Get the window with the lowest focusHistoryID (most recently focused)
                        return windowsInThisWorkspace.reduce((best, win) => {
                            const bestFocus = (best && best.focusHistoryID !== undefined ? best.focusHistoryID : Infinity);
                            const winFocus = (win && win.focusHistoryID !== undefined ? win.focusHistoryID : Infinity);
                            return winFocus < bestFocus ? win : best;
                        }, null);
                    }
                    property var sortedWindows: {
                        const wins = CompositorData.workspaceWindowsMap[buttonVert.workspaceValue] || [];
                        return wins.slice().sort((a, b) => {
                            const aFocus = a.focusHistoryID !== undefined ? a.focusHistoryID : Infinity;
                            const bFocus = b.focusHistoryID !== undefined ? b.focusHistoryID : Infinity;
                            return aFocus - bFocus;
                        });
                    }
                    property var stackModel: {
                        const wins = sortedWindows;
                        const modelList = [];
                        if (wins.length === 0) return modelList;
                        if (wins.length <= 3) {
                            for (let i = 0; i < wins.length; i++) {
                                modelList.push({ type: "icon", win: wins[i] });
                            }
                        } else {
                            for (let i = 0; i < 3; i++) {
                                modelList.push({ type: "icon", win: wins[i] });
                            }
                            modelList.push({ type: "badge", count: wins.length - 3 });
                        }
                        return modelList;
                    }

                    readonly property bool isActiveOnOtherMonitor: workspacesWidget.otherActiveWorkspaces.includes(buttonVert.workspaceValue)

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.width / 2
                        color: "transparent"
                        border.color: Colors.primary || "#ffb3ae"
                        border.width: 1.5
                        opacity: workspaceButtonBackgroundVert.isActiveOnOtherMonitor ? 0.6 : 0
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }
                    }

                    Text {
                        opacity: Config.workspaces.alwaysShowNumbers || ((Config.workspaces.showNumbers && (!Config.workspaces.showAppIcons || !workspaceButtonBackgroundVert.focusedWindow || Config.workspaces.alwaysShowNumbers)) || (Config.workspaces.alwaysShowNumbers && !Config.workspaces.showAppIcons)) ? 1 : 0
                        z: 3

                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: 1
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: Config.theme.font
                        font.pixelSize: workspaceLabelFontSize(text)
                        text: `${buttonVert.workspaceValue}`
                        elide: Text.ElideRight
                        color: ((monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) == buttonVert.workspaceValue) ? Styling.srItem("primary") : (workspaceOccupied[index] ? Colors.overBackground : Colors.overSecondaryFixedVariant)

                        Behavior on opacity {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                    Rectangle {
                        opacity: (Config.workspaces.showNumbers || Config.workspaces.alwaysShowNumbers || (Config.workspaces.showAppIcons && workspaceButtonBackgroundVert.focusedWindow)) ? 0 : (((monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) == buttonVert.workspaceValue) || workspaceOccupied[index] ? 1 : 0.5)
                        visible: opacity > 0
                        anchors.centerIn: parent
                        width: workspaceButtonWidth * 0.2
                        height: width
                        radius: width / 2
                        color: ((monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : undefined) == buttonVert.workspaceValue) ? Styling.srItem("primary") : Colors.overBackground

                        Behavior on opacity {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                    Item {
                        id: appIconContainerVert
                        anchors.fill: parent
                        opacity: !Config.workspaces.showAppIcons ? 0 : (workspaceButtonBackgroundVert.focusedWindow && !Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons) ? 1 : workspaceButtonBackgroundVert.focusedWindow ? workspaceIconOpacityShrinked : 0
                        visible: opacity > 0

                        Row {
                            id: stackRowVert
                            spacing: -Math.round(itemSize * 0.35)

                            readonly property bool isCentered: !Config.workspaces.alwaysShowNumbers && Config.workspaces.showAppIcons
                            readonly property int itemSize: isCentered ? workspaceIconSize : workspaceIconSizeShrinked

                            anchors.centerIn: isCentered ? parent : undefined
                            anchors.bottom: isCentered ? undefined : parent.bottom
                            anchors.right: isCentered ? undefined : parent.right
                            anchors.bottomMargin: isCentered ? 0 : workspaceIconMarginShrinked
                            anchors.rightMargin: isCentered ? 0 : workspaceIconMarginShrinked

                            Repeater {
                                model: workspaceButtonBackgroundVert.stackModel

                                delegate: Item {
                                    id: stackDelegateVert
                                    required property var modelData
                                    required property int index

                                    z: index
                                    width: stackRowVert.itemSize
                                    height: stackRowVert.itemSize

                                     Rectangle {
                                        width: stackRowVert.itemSize
                                        height: stackRowVert.itemSize
                                        radius: width / 2
                                        color: modelData.type === "badge" ? (Colors.primary || "#ffb3ae") : (Colors.surfaceContainerLow || "#231919")
                                        border.color: Colors.background || "#1a1111"
                                        border.width: 1

                                        IconImage {
                                            id: appIconVert
                                            visible: modelData.type === "icon"
                                            anchors.centerIn: parent
                                            source: modelData.type === "icon" ? workspacesWidget.getAppIconSource(modelData.win) : ""
                                            implicitSize: Math.round(parent.width * 0.7)
                                        }

                                        Tinted {
                                            visible: modelData.type === "icon"
                                            sourceItem: appIconVert
                                            anchors.fill: appIconVert
                                        }

                                        Text {
                                            visible: modelData.type === "badge"
                                            anchors.centerIn: parent
                                            text: modelData.type === "badge" ? "+" + modelData.count : ""
                                            font.family: Config.theme.font
                                            font.pixelSize: Math.round(parent.width * 0.5)
                                            font.bold: true
                                            color: Colors.overPrimary || "#571d1c"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
