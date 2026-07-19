import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.modules.theme

PanelWindow {
    id: displaySelectPopup

    readonly property var screenVisibilities: Visibilities.getForScreen(screen.name)
    readonly property bool displaySelectOpen: screenVisibilities ? screenVisibilities.displaySelect : false
    property int highlightedIndex: 0

    function cycleHighlight() {
        highlightedIndex = (highlightedIndex + 1) % 4;
        applyTimer.restart();
    }

    function applyAndClose() {
        applyTimer.stop();
        if (highlightedIndex >= 0 && highlightedIndex < 4) {
            const mode = optionRepeater.model[highlightedIndex].id;
            if (Config.system.display) {
                Config.system.display.mode = mode;
                GlobalStates.markShellChanged();
            }
        }
        Visibilities.setActiveModule("");
    }

    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ambxst:displayselect"
    WlrLayershell.keyboardFocus: displaySelectOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    visible: displaySelectOpen
    exclusionMode: ExclusionMode.Ignore
    // Focus handling to receive keypresses
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            applyTimer.stop();
            Visibilities.setActiveModule("");
            event.accepted = true;
        } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
            applyTimer.stop();
            highlightedIndex = (highlightedIndex - 1 + 4) % 4;
            event.accepted = true;
        } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
            applyTimer.stop();
            highlightedIndex = (highlightedIndex + 1) % 4;
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            displaySelectPopup.applyAndClose();
            event.accepted = true;
        }
    }
    onDisplaySelectOpenChanged: {
        if (displaySelectOpen) {
            // Find current active mode to highlight it initially
            let currentMode = Config.system.display ? Config.system.display.mode : "extend";
            let foundIdx = 0;
            const modes = ["extend", "mirror", "internal", "external"];
            let idx = modes.indexOf(currentMode);
            if (idx !== -1)
                foundIdx = idx;

            highlightedIndex = foundIdx;
            // Focus this item to receive key events
            displaySelectPopup.forceActiveFocus();
        } else {
            applyTimer.stop();
        }
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Item {
        id: fullMask

        anchors.fill: parent
    }

    Item {
        id: emptyMask

        width: 0
        height: 0
    }

    FocusGrab {
        id: focusGrab

        windows: [displaySelectPopup]
        active: displaySelectOpen
        onCleared: {
            Qt.callLater(() => {
                if (displaySelectOpen)
                    Visibilities.setActiveModule("");

            });
        }
    }

    // Semi-transparent backdrop
    Rectangle {
        id: backdrop

        anchors.fill: parent
        color: Colors.scrim
        opacity: displaySelectOpen ? 0.4 : 0

        MouseArea {
            anchors.fill: parent
            onClicked: {
                Visibilities.setActiveModule("");
            }
        }

        Behavior on opacity {
            enabled: Config.animDuration > 0

            NumberAnimation {
                duration: Config.animDuration
                easing.type: Easing.OutQuart
            }

        }

    }

    // Main content panel (centered horizontal dialog style)
    StyledRect {
        id: mainContainer

        variant: "bg"
        anchors.centerIn: parent
        width: contentColumn.implicitWidth + 48
        height: contentColumn.implicitHeight + 48
        radius: Styling.radius(24)
        layer.enabled: true
        opacity: displaySelectOpen ? 1 : 0
        scale: displaySelectOpen ? 1 : 0.9

        ColumnLayout {
            id: contentColumn

            anchors.centerIn: parent
            spacing: 20

            Text {
                text: "Display Layout"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(3)
                font.bold: true
                color: Colors.overBackground
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Select multi-monitor display mode"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                color: Colors.overSurfaceVariant
                opacity: 0.8
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 8
            }

            // Options list (horizontal row)
            RowLayout {
                id: optionsRow

                spacing: 16
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    id: optionRepeater

                    model: [{
                        "id": "extend",
                        "label": "Extend",
                        "desc": "Join Displays",
                        "icon": Icons.arrowsOut
                    }, {
                        "id": "mirror",
                        "label": "Mirror",
                        "desc": "Clone Screen",
                        "icon": Icons.copy
                    }, {
                        "id": "internal",
                        "label": "Internal Only",
                        "desc": "Laptop Screen",
                        "icon": Icons.terminalWindow
                    }, {
                        "id": "external",
                        "label": "External Only",
                        "desc": "External Monitor",
                        "icon": Icons.arrowSquareOut
                    }]

                    delegate: StyledRect {
                        id: optionItem

                        required property var modelData
                        required property int index
                        readonly property bool isCurrentMode: Config.system.display ? (Config.system.display.mode === modelData.id) : (modelData.id === "extend")
                        readonly property bool isHighlighted: index === displaySelectPopup.highlightedIndex
                        property bool isHovered: false

                        variant: isHighlighted ? "primary" : (isHovered ? "focus" : "common")
                        width: 140
                        height: 140
                        radius: Styling.radius(16)

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 8

                            // Checkmark badge in corner if active mode
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 14

                                Text {
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    text: Icons.accept
                                    font.family: Icons.font
                                    font.pixelSize: 12
                                    color: optionItem.item
                                    visible: optionItem.isCurrentMode
                                }

                            }

                            // Large Icon in the center
                            Text {
                                text: optionItem.modelData.icon
                                font.family: Icons.font
                                font.pixelSize: 32
                                color: optionItem.item
                                Layout.alignment: Qt.AlignHCenter
                            }

                            // Spacer to push labels down
                            Item {
                                Layout.fillHeight: true
                            }

                            Text {
                                text: optionItem.modelData.label
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(0)
                                font.bold: optionItem.isCurrentMode || optionItem.isHighlighted
                                color: optionItem.item
                                Layout.alignment: Qt.AlignHCenter
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                            }

                            Text {
                                text: optionItem.modelData.desc
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-3)
                                color: optionItem.item
                                opacity: 0.7
                                Layout.alignment: Qt.AlignHCenter
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                            }

                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: optionItem.isHovered = true
                            onExited: optionItem.isHovered = false
                            onClicked: {
                                displaySelectPopup.highlightedIndex = index;
                                displaySelectPopup.applyAndClose();
                            }
                        }

                    }

                }

            }

        }

        layer.effect: Shadow {
        }

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

    }

    // Auto-apply after 1.5 seconds of inactivity when cycling
    Timer {
        id: applyTimer

        interval: 1500
        repeat: false
        onTriggered: {
            displaySelectPopup.applyAndClose();
        }
    }

    Connections {
        function onCycleDisplaySelectRequested() {
            displaySelectPopup.cycleHighlight();
        }

        target: GlobalShortcuts
    }

    mask: Region {
        item: displaySelectOpen ? fullMask : emptyMask
    }

}
