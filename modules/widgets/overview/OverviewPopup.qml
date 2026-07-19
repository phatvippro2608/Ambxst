import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.modules.globals
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config
import "."

PanelWindow {
    id: overviewPopup

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ambxst:overview"
    WlrLayershell.keyboardFocus: overviewOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Get this screen's visibility state
    readonly property var screenVisibilities: Visibilities.getForScreen(screen.name)
    readonly property bool overviewOpen: screenVisibilities ? screenVisibilities.overview : false

    visible: overviewOpen
    exclusionMode: ExclusionMode.Ignore

    // Mask to capture input on the entire window
    mask: Region {
        item: backdrop
    }

    FocusGrab {
        id: focusGrab
        windows: [overviewPopup]
        active: overviewOpen
    }

    Keys.onPressed: event => {
        if (!overviewOpen) return;

        // Check if user is actively searching with letter/text query
        const hasTextQuery = searchInput && searchInput.text.trim() !== "" && /[a-zA-Z]/.test(searchInput.text);
        if (hasTextQuery) {
            if (event.key === Qt.Key_Escape) {
                event.accepted = true;
                Visibilities.setActiveModule("");
            }
            return;
        }

        // Number keys 1..9 -> Workspaces 1..9, 0 -> Workspace 10
        let targetWs = -1;
        if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            targetWs = event.key - Qt.Key_1 + 1;
        } else if (event.key >= Qt.Key_KP_1 && event.key <= Qt.Key_KP_9) {
            targetWs = event.key - Qt.Key_KP_1 + 1;
        } else if (event.key === Qt.Key_0 || event.key === Qt.Key_KP_0) {
            targetWs = 10;
        }

        if (targetWs !== -1) {
            event.accepted = true;
            if (searchInput) searchInput.text = "";
            Visibilities.setActiveModule("", true);
            Qt.callLater(() => {
                AxctlService.dispatch(`workspace ${targetWs}`);
            });
            return;
        }

        if (event.key === Qt.Key_Escape) {
            event.accepted = true;
            Visibilities.setActiveModule("");
        }
    }

    // Semi-transparent backdrop
    Rectangle {
        id: backdrop
        anchors.fill: parent
        color: Colors.scrim
        opacity: overviewOpen ? 0.5 : 0

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuart
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                Visibilities.setActiveModule("");
            }
        }
    }

    // Main content column (search + overview)
    Item {
        id: mainContainer
        anchors.centerIn: parent
        width: Math.max(searchContainer.width, overviewContainer.width)
        height: searchContainer.height + 8 + overviewContainer.height

        opacity: overviewOpen ? 1 : 0
        scale: overviewOpen ? 1 : 0.9

        Behavior on opacity {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuart
            }
        }

        Behavior on scale {
            enabled: Config.animDuration > 0
            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutBack
                easing.overshoot: 1.2
            }
        }

        // Search input container
        StyledRect {
            id: searchContainer
            variant: "bg"
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(400, overviewContainer.width)
            height: 80
            radius: Styling.radius(24)

            layer.enabled: true
            layer.effect: Shadow {}

            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8

                // Icon container
                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    Layout.alignment: Qt.AlignVCenter
                    color: "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: Icons.overview
                        font.family: Icons.font
                        font.pixelSize: 24
                        color: Styling.srItem("overprimary")
                    }
                }

                // Search input
                SearchInput {
                    id: searchInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    Layout.alignment: Qt.AlignVCenter

                    variant: "common"
                    placeholderText: qsTr("Search windows...")
                    handleTabNavigation: true
                    clearOnEscape: false
                    interceptNumbers: true

                    onNumberPressed: number => {
                        text = "";
                        AxctlService.dispatch(`workspace ${number}`);
                        Visibilities.setActiveModule("");
                    }

                    // Match counter suffix
                    Text {
                        id: matchCounter
                        visible: overviewLoader.item && overviewLoader.item.searchQuery.length > 0
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (!overviewLoader.item)
                                return "0";
                            const matches = overviewLoader.item.matchingWindows.length;
                            if (matches > 0) {
                                return `${overviewLoader.item.selectedMatchIndex + 1}/${matches}`;
                            }
                            return "0";
                        }
                        font.family: Config.theme.font
                        font.pixelSize: Config.theme.fontSize - 2
                        color: (overviewLoader.item && overviewLoader.item.matchingWindows.length > 0) ? Styling.srItem("overprimary") : Colors.error
                        opacity: 0.8
                    }

                    onSearchTextChanged: text => {
                        if (overviewLoader.item) {
                            overviewLoader.item.searchQuery = text;
                        }
                    }

                    onAccepted: {
                        if (searchInput.text.length > 0 && overviewLoader.item) {
                            overviewLoader.item.navigateToSelectedWindow();
                        } else if (GlobalStates.hoveredWorkspaceId !== -1) {
                            Visibilities.setActiveModule("");
                            Qt.callLater(() => {
                                AxctlService.dispatch(`workspace ${GlobalStates.hoveredWorkspaceId}`);
                            });
                        }
                    }

                    onTabPressed: {
                        if (searchInput.text.length === 0) {
                            const current = AxctlService.focusedWorkspace?.id || 1;
                            const next = current + 1;
                            if (next > Config.workspaces.shown) {
                                AxctlService.dispatch("workspace 1");
                            } else {
                                AxctlService.dispatch("workspace r+1");
                            }
                        } else if (overviewLoader.item) {
                            overviewLoader.item.selectNextMatch();
                        }
                    }
                    
                    onShiftTabPressed: {
                        if (searchInput.text.length === 0) {
                            const current = AxctlService.focusedWorkspace?.id || 1;
                            const prev = current - 1;
                            if (prev < 1) {
                                AxctlService.dispatch("workspace " + Config.workspaces.shown);
                            } else {
                                AxctlService.dispatch("workspace r-1");
                            }
                        } else if (overviewLoader.item) {
                            overviewLoader.item.selectPrevMatch();
                        }
                    }

                    onDownPressed: {
                        if (overviewLoader.item) {
                            overviewLoader.item.selectNextMatch();
                        }
                    }

                    onUpPressed: {
                        if (overviewLoader.item) {
                            overviewLoader.item.selectPrevMatch();
                        }
                    }

                    onEscapePressed: {
                        if (searchInput.text.length > 0) {
                            searchInput.clear();
                            if (overviewLoader.item) {
                                overviewLoader.item.searchQuery = "";
                            }
                        } else {
                            Visibilities.setActiveModule("");
                        }
                    }

                    onLeftPressed: {
                        if (searchInput.text.length === 0) {
                            const current = AxctlService.focusedWorkspace?.id || 1;
                            const prev = current - 1;
                            if (prev < 1) {
                                AxctlService.dispatch("workspace " + Config.workspaces.shown);
                            } else {
                                AxctlService.dispatch("workspace r-1");
                            }
                        } else if (overviewLoader.item) {
                            overviewLoader.item.selectPrevMatch();
                        }
                    }

                    onRightPressed: {
                        if (searchInput.text.length === 0) {
                            const current = AxctlService.focusedWorkspace?.id || 1;
                            const next = current + 1;
                            if (next > Config.workspaces.shown) {
                                AxctlService.dispatch("workspace 1");
                            } else {
                                AxctlService.dispatch("workspace r+1");
                            }
                        } else if (overviewLoader.item) {
                            overviewLoader.item.selectNextMatch();
                        }
                    }

                    onKeyReleased: event => {
                        if (event.key === Qt.Key_Super || event.key === Qt.Key_Meta || event.key === Qt.Key_Alt) {
                            if (GlobalStates.hoveredWorkspaceId !== -1) {
                                Visibilities.setActiveModule("");
                                Qt.callLater(() => {
                                    AxctlService.dispatch(`workspace ${GlobalStates.hoveredWorkspaceId}`);
                                });
                            }
                        }
                    }
                }
            }
        }

        // Overview container
        Item {
            id: overviewContainer
            anchors.top: searchContainer.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: overviewLoader.item ? overviewLoader.item.implicitWidth + 48 : 400
            height: overviewLoader.item ? overviewLoader.item.implicitHeight + 48 : 300

            // Background panel
            StyledRect {
                id: overviewBackground
                variant: "bg"
                anchors.fill: parent
                radius: Styling.radius(20)

                layer.enabled: true
                layer.effect: Shadow {}
            }

            // Loader for Overview to prevent issues during destruction
            Loader {
                id: overviewLoader
                anchors.centerIn: parent
                active: overviewOpen

                sourceComponent: OverviewView {
                    currentScreen: overviewPopup.screen
                }
            }
        }

        // External scrollbar for scrolling mode (to the right of overview)
        StyledRect {
            id: scrollbarContainer
            visible: overviewLoader.item && overviewLoader.item.needsScrollbar
            variant: "bg"
            anchors.left: overviewContainer.right
            anchors.leftMargin: 8
            anchors.verticalCenter: overviewContainer.verticalCenter
            width: 32
            height: Math.max(overviewContainer.height * 0.6, 200)
            radius: Styling.radius(0)

            layer.enabled: true
            layer.effect: Shadow {}

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    if (overviewLoader.item && overviewLoader.item.flickable) {
                        const flickable = overviewLoader.item.flickable;
                        const delta = wheel.angleDelta.y > 0 ? -150 : 150;
                        flickable.contentY = Math.max(0, Math.min(flickable.contentY + delta, flickable.contentHeight - flickable.height));
                    }
                }
            }

            ScrollBar {
                id: externalScrollBar
                anchors.centerIn: parent
                height: parent.height - 16
                width: 12
                orientation: Qt.Vertical
                policy: ScrollBar.AlwaysOn

                position: overviewLoader.item && overviewLoader.item.flickable ? overviewLoader.item.flickable.visibleArea.yPosition : 0
                size: overviewLoader.item && overviewLoader.item.flickable ? overviewLoader.item.flickable.visibleArea.heightRatio : 1

                // Notify flickable when manually scrolling to disable animation
                onActiveChanged: {
                    if (overviewLoader.item) {
                        overviewLoader.item.isManualScrolling = active;
                    }
                }

                onPositionChanged: {
                    if (active && overviewLoader.item && overviewLoader.item.flickable) {
                        overviewLoader.item.flickable.contentY = position * overviewLoader.item.flickable.contentHeight;
                    }
                }

                contentItem: Rectangle {
                    implicitWidth: 12
                    radius: Styling.radius(-10)
                    color: externalScrollBar.pressed ? Styling.srItem("overprimary") : (externalScrollBar.hovered ? Qt.lighter(Styling.srItem("overprimary"), 1.2) : Styling.srItem("overprimary"))

                    Behavior on color {
                        enabled: Config.animDuration > 0
                        ColorAnimation {
                            duration: Config.animDuration / 2
                        }
                    }
                }

                background: Rectangle {
                    implicitWidth: 12
                    radius: Styling.radius(-10)
                    color: Colors.surfaceContainer
                    opacity: 0.3
                }
            }
        }
    }

    // Ensure focus when overview opens
    onOverviewOpenChanged: {
        if (overviewOpen) {
            Qt.callLater(() => {
                searchInput.clear();
                if (overviewLoader.item) {
                    overviewLoader.item.resetSearch();
                }
                searchInput.focusInput();
            });
        }
    }
}
