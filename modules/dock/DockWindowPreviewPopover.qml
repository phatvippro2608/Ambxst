import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import qs.modules.theme
import qs.modules.services
import qs.modules.components
import qs.config

Item {
    id: popoverRoot

    required property var appToplevel
    required property string dockPosition
    property bool active: false
    property Item targetButton: null
    
    // Bind hovered state using native HoverHandler to avoid child MouseArea interference
    readonly property bool hovered: mainHoverHandler.hovered

    readonly property bool isBottom: dockPosition === "bottom"
    readonly property bool isLeft: dockPosition === "left"
    readonly property bool isRight: dockPosition === "right"
    readonly property bool isTop: dockPosition === "top"
    readonly property bool isVertical: isLeft || isRight

    readonly property int cardWidth: 180
    readonly property int cardHeight: 120
    readonly property int itemSpacing: 3
    readonly property int paddingSize: 3
    readonly property int gapSize: 12

    // Content dimensions (excluding the gap)
    readonly property int contentWidth: {
        const count = appToplevel?.toplevelCount ?? 0;
        if (count === 0) return 0;
        if (isVertical) {
            return cardWidth + paddingSize * 2;
        } else {
            return count * cardWidth + (count - 1) * itemSpacing + paddingSize * 2;
        }
    }

    readonly property int contentHeight: {
        const count = appToplevel?.toplevelCount ?? 0;
        if (count === 0) return 0;
        if (isVertical) {
            return count * cardHeight + (count - 1) * itemSpacing + paddingSize * 2;
        } else {
            return cardHeight + paddingSize * 2;
        }
    }

    // Total popover dimensions (including the gap for Wayland input mask coverage)
    width: isVertical ? contentWidth + gapSize : contentWidth
    height: isVertical ? contentHeight : contentHeight + gapSize

    // Position relative to targetButton mapped to parent window (UnifiedShellPanel)
    x: {
        if (!targetButton) return 0;
        const globalPos = targetButton.mapToItem(parent, 0, 0);
        if (isBottom || isTop) {
            return globalPos.x + (targetButton.width - width) / 2;
        } else if (isLeft) {
            return globalPos.x + targetButton.width;
        } else { // isRight
            return globalPos.x - width;
        }
    }

    y: {
        if (!targetButton) return 0;
        const globalPos = targetButton.mapToItem(parent, 0, 0);
        if (isBottom) {
            return globalPos.y - height;
        } else if (isTop) {
            return globalPos.y + targetButton.height;
        } else { // vertical
            return globalPos.y + (targetButton.height - height) / 2;
        }
    }

    visible: opacity > 0
    opacity: active && (appToplevel?.toplevelCount ?? 0) > 0 ? 1 : 0
    scale: active && (appToplevel?.toplevelCount ?? 0) > 0 ? 1 : 0.98

    Behavior on opacity {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        NumberAnimation { duration: 120; easing.type: Easing.OutBack }
    }

    // Native HoverHandler covering the entire area (including gap and all children)
    HoverHandler {
        id: mainHoverHandler
    }

    // Popover Background Container (offset to leave the gap transparent)
    StyledRect {
        id: bgRect
        x: isRight ? gapSize : 0
        y: isTop ? gapSize : 0
        width: popoverRoot.contentWidth
        height: popoverRoot.contentHeight
        variant: "surfaceContainer"
        radius: Styling.radius(2)
        enableShadow: true
        enableBorder: true
    }

    // List of previews
    Grid {
        anchors.fill: bgRect
        anchors.margins: popoverRoot.paddingSize
        spacing: popoverRoot.itemSpacing
        columns: popoverRoot.isVertical ? 1 : -1
        rows: popoverRoot.isVertical ? -1 : 1

        Repeater {
            model: appToplevel?.toplevels ?? []

            delegate: Item {
                id: card
                width: popoverRoot.cardWidth
                height: popoverRoot.cardHeight

                required property int index
                required property var modelData // Wayland Toplevel

                readonly property bool isWindowActive: modelData.activated

                // MouseArea for card interaction
                MouseArea {
                    id: cardMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        modelData.activate();
                        if (popoverRoot.targetButton) {
                            popoverRoot.targetButton.showPopup = false;
                        }
                    }
                }

                // Card background
                StyledRect {
                    anchors.fill: parent
                    variant: cardMouse.containsMouse ? "focus" : (card.isWindowActive ? "surfaceContainerHigh" : "surfaceContainerLow")
                    radius: Styling.radius(1)
                    enableBorder: !card.isWindowActive && !cardMouse.containsMouse
                }

                // Custom border outline
                Rectangle {
                    anchors.fill: parent
                    radius: Styling.radius(1)
                    color: "transparent"
                    border.color: Colors.primary
                    border.width: card.isWindowActive ? 1.5 : 1
                    opacity: card.isWindowActive ? 1 : (cardMouse.containsMouse ? 0.4 : 0)
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: 100 }
                    }
                }

                // Title Text (with dedicated space to avoid overlap with Close button)
                Text {
                    id: titleText
                    anchors.top: parent.top
                    anchors.topMargin: 4
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.right: closeBtn.left
                    anchors.rightMargin: 4

                    text: card.modelData.title || card.modelData.appId || "Window"
                    font.family: Config.theme.font
                    font.pixelSize: 10
                    font.bold: card.isWindowActive
                    color: card.isWindowActive ? Colors.primary : Colors.overBackground
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignLeft
                }

                // Close Button in top right (circular & clean)
                Button {
                    id: closeBtn
                    width: 16
                    height: 16
                    anchors.top: parent.top
                    anchors.topMargin: 3
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    z: 10

                    background: Rectangle {
                        radius: width / 2
                        color: closeBtn.pressed ? Colors.error : (closeBtn.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                    }

                    contentItem: Text {
                        text: "✕"
                        font.pixelSize: 8
                        font.bold: true
                        color: closeBtn.hovered ? (closeBtn.pressed ? "white" : Colors.error) : Colors.overBackground
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        opacity: closeBtn.hovered ? 1.0 : 0.6
                    }

                    onClicked: {
                        const client = AxctlService.clients.values.find(c => c.title === card.modelData.title && c.class.toLowerCase() === card.modelData.appId.toLowerCase());
                        if (client) {
                            AxctlService.dispatch("closewindow address:" + client.address);
                        } else {
                            AxctlService.dispatch("closewindow class:" + card.modelData.appId);
                        }
                    }
                }

                // Window Visual Placeholder / Live Screencopy View (Rounded corners clipping)
                ClippingRectangle {
                    id: previewContainer
                    anchors.top: titleText.bottom
                    anchors.topMargin: 3
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    radius: Styling.radius(-2)
                    color: cardMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.04)
                    border.color: card.isWindowActive ? Colors.primary : Qt.rgba(Colors.overBackground.r, Colors.overBackground.g, Colors.overBackground.b, 0.1)
                    border.width: 1

                    // Real-time window preview
                    ScreencopyView {
                        id: windowPreview
                        anchors.fill: parent
                        captureSource: popoverRoot.active ? card.modelData : null
                        live: popoverRoot.active
                        visible: hasContent
                    }

                    // Fallback app icon (shown if preview is not loaded/available)
                    Image {
                        id: previewIcon
                        anchors.centerIn: parent
                        width: 32
                        height: 32
                        source: {
                            const entry = DesktopEntries.heuristicLookup(card.modelData.appId);
                            const iconName = entry ? entry.icon : AppSearch.guessIcon(card.modelData.appId);
                            return "image://icon/" + iconName;
                        }
                        fillMode: Image.PreserveAspectFit
                        mipmap: true
                        opacity: 0.85
                        visible: !windowPreview.hasContent
                    }

                    Tinted {
                        sourceItem: previewIcon
                        anchors.fill: previewIcon
                        visible: !windowPreview.hasContent
                    }
                }
            }
        }
    }
}
