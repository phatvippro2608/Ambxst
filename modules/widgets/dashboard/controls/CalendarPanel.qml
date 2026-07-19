pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.modules.theme
import qs.modules.components
import qs.modules.services
import qs.config

Item {
    id: root

    property int maxContentWidth: 480
    readonly property int contentWidth: Math.min(width, maxContentWidth)

    Component.onCompleted: {
        CalendarService.checkAuthStatus();
    }

    Flickable {
        id: flickable
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainColumn.implicitHeight + 32
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        ColumnLayout {
            id: mainColumn
            width: root.contentWidth
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16

            PanelTitlebar {
                title: "Đồng bộ Calendar"
                statusText: CalendarService.isAuthenticated ? "Đã liên kết" : "Chưa liên kết"
                statusColor: CalendarService.isAuthenticated ? Colors.green : Colors.warning
                actions: [
                    {
                        icon: Icons.sync,
                        tooltip: "Đồng bộ ngay",
                        loading: CalendarService.isSyncing,
                        onClicked: function () {
                            CalendarService.sync();
                        }
                    }
                ]
            }

            // Description card
            StyledRect {
                variant: "common"
                Layout.fillWidth: true
                implicitHeight: infoColumn.implicitHeight + 24
                radius: Styling.radius(4)
                
                ColumnLayout {
                    id: infoColumn
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    Text {
                        text: "Cách cấu hình Google Calendar Sync:"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(0)
                        font.bold: true
                        color: Colors.overBackground
                    }

                    Text {
                        text: "1. Truy cập Google Cloud Console và tạo dự án mới.\n2. Kích hoạt Google Calendar API cho dự án đó.\n3. Tạo thông tin xác thực OAuth Client ID (loại Desktop app).\n4. Thêm URI chuyển hướng (Redirect URI): http://localhost:8080\n5. Nhập Client ID và Client Secret bên dưới và click Liên kết."
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-2)
                        color: Colors.overBackground
                        opacity: 0.8
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // Setup credentials form
            StyledRect {
                variant: "common"
                Layout.fillWidth: true
                implicitHeight: formColumn.implicitHeight + 24
                radius: Styling.radius(4)

                ColumnLayout {
                    id: formColumn
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Text {
                        text: "Cấu hình Google OAuth Credentials"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(0)
                        font.bold: true
                        color: Colors.overBackground
                    }

                    // Client ID Input
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: "Client ID"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overBackground
                            font.bold: true
                        }
                        StyledRect {
                            variant: "internalbg"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: Styling.radius(-4)
                            TextField {
                                id: clientIdField
                                anchors.fill: parent
                                anchors.margins: 6
                                color: Colors.overBackground
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                background: null
                                text: CalendarService.oauthClientId
                                placeholderText: "Nhập Client ID của bạn..."
                                placeholderTextColor: Colors.outline
                                selectByMouse: true
                                onTextEdited: {
                                    CalendarService.oauthClientId = text;
                                }
                            }
                        }
                    }

                    // Client Secret Input
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: "Client Secret"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overBackground
                            font.bold: true
                        }
                        StyledRect {
                            variant: "internalbg"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            radius: Styling.radius(-4)
                            TextField {
                                id: clientSecretField
                                anchors.fill: parent
                                anchors.margins: 6
                                color: Colors.overBackground
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                background: null
                                text: CalendarService.oauthClientSecret
                                placeholderText: "Nhập Client Secret của bạn..."
                                placeholderTextColor: Colors.outline
                                selectByMouse: true
                                onTextEdited: {
                                    CalendarService.oauthClientSecret = text;
                                }
                            }
                        }
                    }

                    // Action buttons row
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Layout.topMargin: 4

                        // Connect Button
                        Button {
                            id: connectBtn
                            Layout.fillWidth: true
                            implicitHeight: 36
                            flat: true
                            background: StyledRect {
                                variant: connectBtn.pressed ? "primary" : (connectBtn.hovered ? "focus" : "internalbg")
                                radius: Styling.radius(-4)
                            }
                            contentItem: Text {
                                text: CalendarService.isAuthenticated ? "Liên kết lại" : "Liên kết tài khoản Google"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                font.bold: true
                                color: connectBtn.pressed ? Styling.srItem("primary") : Colors.overBackground
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: {
                                if (clientIdField.text.trim() === "" || clientSecretField.text.trim() === "") {
                                    CalendarService.syncStatusMessage = "Lỗi: Vui lòng điền đầy đủ Client ID và Client Secret!";
                                    return;
                                }
                                CalendarService.startAuth(clientIdField.text.trim(), clientSecretField.text.trim());
                            }
                        }
                    }
                }
            }

            // Sync Status Card
            StyledRect {
                variant: "common"
                Layout.fillWidth: true
                implicitHeight: statusColumn.implicitHeight + 24
                radius: Styling.radius(4)

                ColumnLayout {
                    id: statusColumn
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    Text {
                        text: "Trạng thái đồng bộ"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(0)
                        font.bold: true
                        color: Colors.overBackground
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Trạng thái:"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overBackground
                            opacity: 0.8
                            Layout.preferredWidth: 90
                        }

                        Text {
                            text: CalendarService.isSyncing ? "Đang đồng bộ..." : (CalendarService.syncStatusMessage !== "" ? CalendarService.syncStatusMessage : "Sẵn sàng")
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.bold: true
                            color: CalendarService.isSyncing ? Colors.primary : Colors.overBackground
                            Layout.fillWidth: true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Xác thực:"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            color: Colors.overBackground
                            opacity: 0.8
                            Layout.preferredWidth: 90
                        }

                        Text {
                            text: CalendarService.isAuthenticated ? "Đã xác thực" : "Chưa xác thực"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.bold: true
                            color: CalendarService.isAuthenticated ? Colors.green : Colors.red
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
