import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import qs.modules.theme
import qs.modules.services
import qs.modules.notifications
import qs.modules.components
import qs.config

Row {
    id: root
    spacing: 6
    visible: notificationsByApp.length > 0

    property var notificationsByApp: {
        var map = {};
        var list = [];
        var notifs = Notifications.list || [];
        for (var i = 0; i < notifs.length; i++) {
            var notif = notifs[i];
            var app = notif.appName || "System";
            if (!map[app]) {
                map[app] = {
                    appName: app,
                    appIcon: notif.appIcon || "",
                    image: notif.image || "",
                    urgency: notif.urgency || "normal",
                    count: 0,
                    notifications: []
                };
                list.push(map[app]);
            }
            map[app].count++;
            map[app].notifications.push(notif);
            if (notif.urgency === "critical") {
                map[app].urgency = "critical";
            }
        }
        return list;
    }

    Repeater {
        model: root.notificationsByApp

        Item {
            width: 24
            height: 24

            NotificationAppIcon {
                id: icon
                anchors.centerIn: parent
                size: 24
                scale: 1.0
                appName: modelData.appName
                appIcon: modelData.appIcon
                image: modelData.image
                urgency: modelData.urgency === "critical" ? NotificationUrgency.Critical : NotificationUrgency.Normal
            }

            // Count badge
            Rectangle {
                width: 14
                height: 14
                radius: 7
                color: modelData.urgency === "critical" ? Colors.criticalRed : Colors.error
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: -4
                anchors.rightMargin: -4
                visible: modelData.count > 0

                Text {
                    anchors.centerIn: parent
                    text: modelData.count
                    font.family: Config.theme.font
                    font.pixelSize: 8
                    font.weight: Font.Bold
                    color: "white"
                }
            }

            MouseArea {
                id: itemMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                
                onClicked: {
                    if (modelData.notifications && modelData.notifications.length > 0) {
                        var latestNotif = modelData.notifications[modelData.notifications.length - 1];
                        Notifications.attemptInvokeAction(latestNotif.id, "default", true);
                    }
                }
            }

            StyledToolTip {
                visible: itemMouseArea.containsMouse
                tooltipText: modelData.appName + " (" + modelData.count + ")"
            }
        }
    }
}
