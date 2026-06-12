import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config

Rectangle {
    id: button

    required property string day
    required property int isToday
    property bool bold: false
    property bool isCurrentDayOfWeek: false
    property string lunarText: ""

    property bool transitionsEnabled: true

    signal clicked()

    implicitWidth: 28
    implicitHeight: (Config.theme.enableLunarCalendar && !bold) ? 36 : 28
    Layout.fillWidth: true
    Layout.fillHeight: false

    opacity: (isToday === -1) ? (clickArea.containsMouse ? 0.85 : 0.6) : 1.0

    Behavior on opacity {
        enabled: Config.animDuration > 0 && button.transitionsEnabled
        NumberAnimation {
            duration: 100
            easing.type: Easing.OutCubic
        }
    }

    color: "transparent"
    radius: Styling.radius(-2)

    StyledRect {
        anchors.fill: parent
        variant: (isToday === 1) ? "primary" : (clickArea.containsMouse ? "focus" : "transparent")
        radius: parent.radius

        Behavior on variant {
            enabled: Config.animDuration > 0 && button.transitionsEnabled
            PropertyAnimation {
                duration: 150
            }
        }

        // Single Centered Text (default layout when lunar calendar is off or header button)
        Text {
            id: singleText
            anchors.fill: parent
            visible: !(Config.theme.enableLunarCalendar && lunarText !== "")
            text: day
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.weight: Font.Bold
            font.pixelSize: Styling.fontSize(-2)
            font.family: Config.defaultFont
            color: {
                if (isToday === 1)
                    return Styling.srItem("primary");
                if (bold) {
                    return isCurrentDayOfWeek ? Colors.overBackground : Colors.outline;
                }
                if (isToday === 0 || clickArea.containsMouse)
                    return Colors.overSurface;
                return Colors.surfaceBright;
            }

            Behavior on color {
                enabled: Config.animDuration > 0 && button.transitionsEnabled
                ColorAnimation {
                    duration: 150
                }
            }
        }

        // Dual Text Layout (when lunar calendar is enabled and lunarText exists)
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 2
            spacing: 0
            visible: Config.theme.enableLunarCalendar && lunarText !== ""

            Text {
                text: day
                Layout.fillWidth: true
                Layout.fillHeight: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignBottom
                font.weight: Font.Bold
                font.pixelSize: Styling.fontSize(-2)
                font.family: Config.defaultFont
                color: {
                    if (isToday === 1)
                        return Styling.srItem("primary");
                    if (isToday === 0 || clickArea.containsMouse)
                        return Colors.overSurface;
                    return Colors.surfaceBright;
                }
            }

            Text {
                text: lunarText
                Layout.fillWidth: true
                Layout.fillHeight: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignTop
                font.pixelSize: Styling.fontSize(-4)
                font.family: Config.defaultFont
                color: {
                    if (isToday === 1)
                        return Styling.srItem("primary");
                    // Highlight first day of lunar month (contains /) with primary, others with outline/muted
                    if (lunarText.indexOf("/") !== -1)
                        return Colors.primary;
                    if (isToday === 0 || clickArea.containsMouse)
                        return Colors.outline;
                    return Colors.surfaceBright;
                }
                opacity: 0.8
            }
        }
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: !bold && day !== ""
        visible: !bold && day !== ""
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
