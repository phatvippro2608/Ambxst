pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.modules.services
import qs.modules.components
import qs.modules.theme
import qs.config

Item {
    id: root

    required property var bar

    property bool vertical: bar.orientation === "vertical"
    property bool isHovered: false
    property bool layerEnabled: true

    property real radius: 0
    property real startRadius: radius
    property real endRadius: radius

    // Only visible when there are active print jobs in the queue
    visible: PrinterService.jobs.length > 0

    // Layout dimensions reactive to visibility to prevent taking space when hidden
    Layout.preferredWidth: visible ? 36 : 0
    Layout.preferredHeight: visible ? 36 : 0
    Layout.fillWidth: visible && vertical
    Layout.fillHeight: visible && !vertical

    HoverHandler {
        onHoveredChanged: root.isHovered = hovered
    }

    StyledRect {
        id: buttonBg
        variant: printerPopup.isOpen ? "primary" : "bg"
        anchors.fill: parent
        enableShadow: root.layerEnabled

        topLeftRadius: root.vertical ? root.startRadius : root.startRadius
        topRightRadius: root.vertical ? root.startRadius : root.endRadius
        bottomLeftRadius: root.vertical ? root.endRadius : root.startRadius
        bottomRightRadius: root.vertical ? root.endRadius : root.endRadius

        Rectangle {
            anchors.fill: parent
            color: Styling.srItem("overprimary")
            opacity: printerPopup.isOpen ? 0 : (root.isHovered ? 0.25 : 0)
            radius: buttonBg.radius

            Behavior on opacity {
                enabled: Config.animDuration > 0
                NumberAnimation {
                    duration: Config.animDuration / 2
                }
            }
        }

        // Printer Icon
        Text {
            id: printerIcon
            anchors.centerIn: parent
            text: Icons.printer
            font.family: Icons.font
            font.pixelSize: 16
            color: printerPopup.isOpen ? buttonBg.item : (PrinterService.isPrinting ? Colors.blue : Colors.overBackground)

            Behavior on color {
                enabled: Config.animDuration > 0
                ColorAnimation {
                    duration: Config.animDuration / 2
                }
            }

            SequentialAnimation on opacity {
                running: PrinterService.isPrinting
                loops: Animation.Infinite
                alwaysRunToEnd: false
                
                NumberAnimation {
                    from: 1.0
                    to: 0.4
                    duration: 1000
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    from: 0.4
                    to: 1.0
                    duration: 1000
                    easing.type: Easing.InOutQuad
                }
            }

            onOpacityChanged: {
                if (!PrinterService.isPrinting) {
                    opacity = 1.0;
                }
            }
        }

        // Job count badge (shown when there is more than 1 job in queue)
        StyledRect {
            id: badge
            visible: PrinterService.jobs.length > 1
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 4
            width: 14
            height: 14
            radius: 7
            variant: "primary"
            enableShadow: false

            Text {
                anchors.centerIn: parent
                text: PrinterService.jobs.length
                font.family: Config.theme.font
                font.pixelSize: 8
                font.bold: true
                color: Styling.srItem("overprimary")
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: printerPopup.toggle()
        }

        StyledToolTip {
            visible: root.isHovered && !printerPopup.isOpen
            tooltipText: "Active print jobs: " + PrinterService.jobs.length
        }
    }

    // Quick Action Popup
    BarPopup {
        id: printerPopup
        anchorItem: buttonBg
        bar: root.bar

        contentWidth: 300
        contentHeight: Math.min(250, (PrinterService.jobs.length * 54) + (printerPopup.popupPadding * 2) + 28)

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            Text {
                text: "Active Print Jobs"
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-1)
                font.bold: true
                color: Colors.overBackground
                Layout.leftMargin: 4
            }

            ListView {
                id: jobsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 4
                model: PrinterService.jobs

                delegate: StyledRect {
                    id: jobItem
                    required property var modelData
                    required property int index

                    width: jobsList.width
                    height: 48
                    variant: "common"
                    enableShadow: false
                    radius: Styling.radius(-4)

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 8

                        Text {
                            text: Icons.file
                            font.family: Icons.font
                            font.pixelSize: 14
                            color: Colors.overBackground
                            Layout.alignment: Qt.AlignVCenter
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                text: jobItem.modelData.file || jobItem.modelData.id
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.bold: true
                                color: Colors.overBackground
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Text {
                                text: jobItem.modelData.printer + " • " + jobItem.modelData.size
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-3)
                                color: Colors.overSurfaceVariant
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Button {
                            flat: true
                            implicitWidth: 26
                            implicitHeight: 26
                            
                            background: StyledRect {
                                variant: parent.hovered ? "focus" : "internalbg"
                                radius: Styling.radius(-6)
                            }
                            
                            contentItem: Text {
                                text: Icons.trash
                                font.family: Icons.font
                                font.pixelSize: 12
                                color: Colors.red
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            
                            onClicked: PrinterService.cancelJob(jobItem.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
