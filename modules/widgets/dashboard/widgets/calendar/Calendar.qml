import QtQuick
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config
import "layout.js" as CalendarLayout

Item {
    id: root

    property int monthShift: 0
    property date currentDate: new Date()
    property var viewingDate: CalendarLayout.getDateInXMonthsTime(monthShift, currentDate)
    property var calendarLayoutData: CalendarLayout.getCalendarLayout(viewingDate, monthShift === 0)
    property var calendarLayout: calendarLayoutData.calendar
    property int currentWeekRow: calendarLayoutData.currentWeekRow
    property int currentDayOfWeek: {
        if (monthShift !== 0)
            return -1;
        return (currentDate.getDay() + 6) % 7;
    }

    property int selectedDay: -1
    property int selectedMonth: -1
    property int selectedYear: -1

    property var selectedDateInfo: {
        if (selectedDay === -1)
            return null;
        for (var r = 0; r < 6; r++) {
            for (var c = 0; c < 7; c++) {
                var cell = calendarLayout[r][c];
                if (cell.cellDay === selectedDay && cell.cellMonth === selectedMonth && cell.cellYear === selectedYear) {
                    return cell;
                }
            }
        }
        return null;
    }

    function clearSelection() {
        selectedDay = -1;
        selectedMonth = -1;
        selectedYear = -1;
    }

    property bool transitionsEnabled: true

    onMonthShiftChanged: {
        root.transitionsEnabled = false;
        Qt.callLater(() => {
            root.transitionsEnabled = true;
        });
    }

    readonly property int cellHeight: Config.theme.enableLunarCalendar ? 36 : 28
    readonly property int gridHeight: 28 + 2 + 6 * cellHeight
    readonly property int gridContainerHeight: gridHeight + 24
    readonly property int paneLayoutHeight: 38 + 6 + gridContainerHeight
    readonly property int totalHeight: paneLayoutHeight + 16

    implicitHeight: totalHeight
    height: totalHeight

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.currentDate = new Date()
    }

    // Helper function to get localized day abbreviation
    function getDayAbbrev(dayIndex) {
        // Create a date for a known Monday (e.g., 2024-01-01 was a Monday)
        var d = new Date(2024, 0, 1 + dayIndex);
        var dayName = d.toLocaleDateString(Qt.locale(), "ddd");
        // Capitalize first letter and limit to 2 chars
        return (dayName.charAt(0).toUpperCase() + dayName.slice(1, 2)).replace(".", "");
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        spacing: 0

        StyledRect {
            id: calendarPane
            variant: "pane"
            Layout.fillWidth: true
            Layout.preferredHeight: root.totalHeight
            implicitHeight: root.totalHeight
            radius: Styling.radius(4)
            clip: true

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (event.angleDelta.y > 0) {
                        monthShift--;
                        root.clearSelection();
                    } else if (event.angleDelta.y < 0) {
                        monthShift++;
                        root.clearSelection();
                    }
                }
            }

            ColumnLayout {
                id: paneLayout
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    Layout.maximumHeight: 38
                    spacing: 2

                    StyledRect {
                        id: titleRect
                        variant: "internalbg"
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Styling.radius(0)

                        Text {
                            anchors.centerIn: parent
                            text: viewingDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                            font.family: Config.defaultFont
                            font.pixelSize: Config.theme.fontSize
                            font.weight: Font.Bold
                            color: titleRect.item
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    StyledRect {
                        id: leftButton
                        variant: leftMouseArea.pressed ? "primary" : (leftMouseArea.containsMouse ? "focus" : "internalbg")
                        Layout.preferredWidth: 36
                        Layout.fillHeight: true
                        radius: Styling.radius(0)

                        readonly property color buttonItem: leftMouseArea.pressed ? itemColor : Styling.srItem("overprimary")

                        Text {
                            anchors.centerIn: parent
                            text: Icons.caretLeft
                            font.family: Icons.font
                            font.pixelSize: 16
                            color: leftButton.buttonItem
                        }

                        MouseArea {
                            id: leftMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                monthShift--;
                                root.clearSelection();
                            }
                            cursorShape: Qt.PointingHandCursor
                        }
                    }

                    StyledRect {
                        id: rightButton
                        variant: rightMouseArea.pressed ? "primary" : (rightMouseArea.containsMouse ? "focus" : "internalbg")
                        Layout.preferredWidth: 38
                        Layout.fillHeight: true
                        radius: Styling.radius(0)

                        readonly property color buttonItem: rightMouseArea.pressed ? itemColor : Styling.srItem("overprimary")

                        Text {
                            anchors.centerIn: parent
                            text: Icons.caretRight
                            font.family: Icons.font
                            font.pixelSize: 16
                            color: rightButton.buttonItem
                        }

                        MouseArea {
                            id: rightMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                monthShift++;
                                root.clearSelection();
                            }
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }

                StyledRect {
                    id: gridContainer
                    variant: "internalbg"
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.gridContainerHeight
                    implicitHeight: Layout.preferredHeight
                    radius: Styling.radius(0)

                    ColumnLayout {
                        id: gridLayout
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredHeight: 28
                            implicitHeight: 28

                            Repeater {
                                model: 7
                                delegate: CalendarDayButton {
                                    required property int index
                                    day: root.getDayAbbrev(index)
                                    isToday: 0
                                    bold: true
                                    isCurrentDayOfWeek: index === root.currentDayOfWeek
                                    transitionsEnabled: root.transitionsEnabled
                                }
                            }
                        }

                        Separator {
                            Layout.fillWidth: true
                            Layout.leftMargin: 8
                            Layout.rightMargin: 8
                            Layout.preferredHeight: 2
                            vert: false
                        }

                        Repeater {
                            model: 6
                            delegate: StyledRect {
                                id: rowRect
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredHeight: root.cellHeight
                                implicitHeight: Layout.preferredHeight
                                variant: (rowIndex === root.currentWeekRow) ? "pane" : "transparent"
                                radius: Styling.radius(-4)

                                required property int index
                                property int rowIndex: index

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0

                                    Repeater {
                                        model: 7
                                        delegate: CalendarDayButton {
                                            required property int index
                                            day: calendarLayout[rowIndex][index].day
                                            isToday: calendarLayout[rowIndex][index].today
                                            lunarText: Config.theme.enableLunarCalendar ? (calendarLayout[rowIndex][index].lunarText || "") : ""
                                            transitionsEnabled: root.transitionsEnabled
                                            onClicked: {
                                                var cell = calendarLayout[rowIndex][index];
                                                if (cell.today === -1) {
                                                    var diff = (cell.cellYear - viewingDate.getFullYear()) * 12 + (cell.cellMonth - (viewingDate.getMonth() + 1));
                                                    root.selectedDay = cell.cellDay;
                                                    root.selectedMonth = cell.cellMonth;
                                                    root.selectedYear = cell.cellYear;
                                                    root.monthShift += diff;
                                                } else {
                                                    root.selectedDay = cell.cellDay;
                                                    root.selectedMonth = cell.cellMonth;
                                                    root.selectedYear = cell.cellYear;
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

            // Selected Day Details Slide-up Overlay
            StyledRect {
                id: detailsOverlay
                variant: "popup"
                anchors.left: parent.left
                anchors.right: parent.right
                radius: Styling.radius(4)
                clip: true

                // Active / Open state when selectedDateInfo is not null
                readonly property bool isOpen: root.selectedDateInfo !== null

                // Covers bottom part of calendar
                height: parent.height * 0.45

                // Position off-screen when closed
                y: isOpen ? parent.height - height - 2 : parent.height

                Behavior on y {
                    enabled: Config.animDuration > 0
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    // Header with Close Button
                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Chi tiết ngày"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
                            font.bold: true
                            color: Colors.overBackground
                            Layout.fillWidth: true
                        }

                        // Close button (X)
                        StyledRect {
                            variant: closeMouse.containsMouse ? "focus" : "transparent"
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            radius: Styling.radius(-2)

                            Text {
                                anchors.centerIn: parent
                                text: Icons.x || "✕"
                                font.family: Icons.font
                                font.pixelSize: 12
                                color: Colors.overBackground
                            }

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.clearSelection()
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }

                    // Date display content
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 8
                        visible: root.selectedDateInfo !== null

                        // Solar Date Info
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: Icons.clock
                                font.family: Icons.font
                                font.pixelSize: 14
                                color: Colors.primary
                            }

                            Text {
                                text: {
                                    if (!root.selectedDateInfo) return "";
                                    var d = new Date(root.selectedDateInfo.cellYear, root.selectedDateInfo.cellMonth - 1, root.selectedDateInfo.cellDay);
                                    return d.toLocaleDateString(Qt.locale(), "dddd, d MMMM yyyy");
                                }
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                color: Colors.overBackground
                                Layout.fillWidth: true
                            }
                        }

                        // Lunar Date Info
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: Icons.moon
                                font.family: Icons.font
                                font.pixelSize: 14
                                color: Colors.primary
                            }

                            Text {
                                text: {
                                    if (!root.selectedDateInfo) return "";
                                    var info = root.selectedDateInfo;
                                    var yearCanChi = CalendarLayout.getYearCanChi(info.lunarYear);
                                    var leapStr = info.lunarLeap ? " (Nhuận)" : "";
                                    return "Lịch âm: Ngày " + info.lunarDay + " tháng " + info.lunarMonth + leapStr + ", năm " + yearCanChi;
                                }
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-1)
                                color: Colors.overBackground
                                Layout.fillWidth: true
                            }
                        }
                    }

                    // Sync / Event Action Button
                    StyledRect {
                        id: syncButton
                        variant: syncMouse.pressed ? "primary" : (syncMouse.containsMouse ? "focus" : "internalbg")
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: Styling.radius(-2)

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: Icons.google
                                font.family: Icons.font
                                font.pixelSize: 14
                                color: syncMouse.pressed ? Styling.srItem("primary") : Colors.overBackground
                            }

                            Text {
                                text: "Đặt lịch / Sync Google Calendar"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                font.bold: true
                                color: syncMouse.pressed ? Styling.srItem("primary") : Colors.overBackground
                            }
                        }

                        MouseArea {
                            id: syncMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.selectedDateInfo) {
                                    var info = root.selectedDateInfo;
                                    var yStr = info.cellYear.toString();
                                    var mStr = info.cellMonth < 10 ? "0" + info.cellMonth : info.cellMonth.toString();
                                    var dStr = info.cellDay < 10 ? "0" + info.cellDay : info.cellDay.toString();
                                    var dateParam = yStr + mStr + dStr;
                                    var url = "https://calendar.google.com/calendar/render?action=TEMPLATE&dates=" + dateParam + "/" + dateParam + "&text=S%E1%BB%B1+ki%E1%BB%87n+m%E1%BB%9Bi";
                                    Qt.openUrlExternally(url);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
