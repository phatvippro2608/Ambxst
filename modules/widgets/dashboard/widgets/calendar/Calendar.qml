import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.modules.components
import qs.config
import qs.modules.services
import "layout.js" as CalendarLayout

Item {
    id: root

    property int monthShift: 0
    property date currentDate: new Date()
    property var viewingDate: CalendarLayout.getDateInXMonthsTime(monthShift, currentDate)
    property var calendarLayoutData: CalendarLayout.getCalendarLayout(viewingDate, monthShift === 0)
    property var calendarLayout: calendarLayoutData ? calendarLayoutData.calendar : null
    property int currentWeekRow: calendarLayoutData ? calendarLayoutData.currentWeekRow : -1
    property int currentDayOfWeek: {
        if (monthShift !== 0)
            return -1;
        return (currentDate.getDay() + 6) % 7;
    }

    property int selectedDay: -1
    property int selectedMonth: -1
    property int selectedYear: -1

    property var selectedDateInfo: {
        if (selectedDay === -1 || !calendarLayout)
            return null;
        for (var r = 0; r < 6; r++) {
            if (!calendarLayout[r]) continue;
            for (var c = 0; c < 7; c++) {
                var cell = calendarLayout[r][c];
                if (cell && cell.cellDay === selectedDay && cell.cellMonth === selectedMonth && cell.cellYear === selectedYear) {
                    return cell;
                }
            }
        }
        return null;
    }

    function clearSelection() {
        console.log("Calendar: Selection cleared");
        selectedDay = -1;
        selectedMonth = -1;
        selectedYear = -1;
    }

    onSelectedDayChanged: console.log("Calendar: selectedDay changed to", selectedDay)
    onSelectedDateInfoChanged: console.log("Calendar: selectedDateInfo changed to", JSON.stringify(selectedDateInfo))

    property bool transitionsEnabled: true

    onMonthShiftChanged: {
        root.transitionsEnabled = false;
        Qt.callLater(() => {
            root.transitionsEnabled = true;
        });
    }

    onViewingDateChanged: {
        updateOccurrencesRange();
    }

    function updateOccurrencesRange() {
        if (!viewingDate) return;
        var year = viewingDate.getFullYear();
        var month = viewingDate.getMonth(); // 0-indexed
        
        var prevMonth = month === 0 ? 11 : month - 1;
        var prevYear = month === 0 ? year - 1 : year;
        var nextMonth = month === 11 ? 0 : month + 1;
        var nextYear = month === 11 ? year + 1 : year;
        
        var startStr = CalendarService.formatDateStr(prevYear, prevMonth + 1, 1);
        var endDay = new Date(nextYear, nextMonth + 1, 0).getDate();
        var endStrSafe = CalendarService.formatDateStr(nextYear, nextMonth + 1, endDay);
        
        CalendarService.loadOccurrences(startStr, endStrSafe);
    }

    Component.onCompleted: {
        updateOccurrencesRange();
    }

    readonly property int cellHeight: Config.theme.enableLunarCalendar ? 36 : 28
    readonly property int gridHeight: 28 + 2 + 6 * cellHeight
    readonly property int gridContainerHeight: gridHeight + 24
    readonly property int paneLayoutHeight: 52 + gridContainerHeight

    readonly property int totalHeight: paneLayoutHeight

    implicitHeight: totalHeight
    height: totalHeight

    Timer {
        interval: 60000
        running: root.visible
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
            Layout.preferredHeight: root.paneLayoutHeight
            implicitHeight: root.paneLayoutHeight
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
                            text: viewingDate ? viewingDate.toLocaleDateString(Qt.locale(), "MMMM yyyy") : ""
                            font.family: Config.defaultFont
                            font.pixelSize: Config.theme.fontSize
                            font.weight: Font.Bold
                            color: titleRect.itemColor
                            horizontalAlignment: Text.AlignHCenter
                        }

                        StyledRect {
                            id: todayButton
                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            height: 28
                            radius: Styling.radius(-2)
                            variant: todayMouseArea.pressed ? "primary" : (todayMouseArea.containsMouse ? "focus" : "transparent")

                            readonly property color buttonItem: todayMouseArea.pressed ? itemColor : Styling.srItem("overprimary")

                            visible: opacity > 0
                            opacity: root.monthShift !== 0 ? 1 : 0

                            Behavior on opacity {
                                enabled: Config.animDuration > 0
                                NumberAnimation {
                                    duration: Config.animDuration / 2
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: Icons.arrowCounterClockwise
                                font.family: Icons.font
                                font.pixelSize: 14
                                color: todayButton.buttonItem
                            }

                            MouseArea {
                                id: todayMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.monthShift = 0;
                                    root.clearSelection();
                                }
                                cursorShape: Qt.PointingHandCursor
                            }
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
                                variant: (rowRect.rowIndex === root.currentWeekRow) ? "pane" : "transparent"
                                radius: Styling.radius(-4)

                                required property int index
                                property int rowIndex: index

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0

                                    Repeater {
                                        model: 7
                                        delegate: CalendarDayButton {
                                            id: cellBtn
                                            required property int index
                                            day: (calendarLayout && calendarLayout[rowRect.rowIndex] && calendarLayout[rowRect.rowIndex][cellBtn.index]) ? calendarLayout[rowRect.rowIndex][cellBtn.index].day.toString() : ""
                                            isToday: (calendarLayout && calendarLayout[rowRect.rowIndex] && calendarLayout[rowRect.rowIndex][cellBtn.index]) ? calendarLayout[rowRect.rowIndex][cellBtn.index].today : 0
                                            lunarText: {
                                                if (!Config.theme || !Config.theme.enableLunarCalendar || !calendarLayout || !calendarLayout[rowRect.rowIndex] || !calendarLayout[rowRect.rowIndex][cellBtn.index])
                                                    return "";
                                                return calendarLayout[rowRect.rowIndex][cellBtn.index].lunarText || "";
                                            }
                                            transitionsEnabled: root.transitionsEnabled
                                            hasEvent: {
                                                if (!calendarLayout || !calendarLayout[rowRect.rowIndex] || !calendarLayout[rowRect.rowIndex][cellBtn.index])
                                                    return false;
                                                var cell = calendarLayout[rowRect.rowIndex][cellBtn.index];
                                                return CalendarService.occurrences.length >= 0 && CalendarService.hasEvents(cell.cellYear, cell.cellMonth, cell.cellDay);
                                            }
                                            isSelected: {
                                                if (!calendarLayout || !calendarLayout[rowRect.rowIndex] || !calendarLayout[rowRect.rowIndex][cellBtn.index])
                                                    return false;
                                                var cell = calendarLayout[rowRect.rowIndex][cellBtn.index];
                                                return cell.cellDay === root.selectedDay && cell.cellMonth === root.selectedMonth && cell.cellYear === root.selectedYear;
                                            }
                                            onClicked: {
                                                console.log("CalendarDayButton: onClicked triggered, rowRect.rowIndex:", rowRect.rowIndex, "colIndex:", cellBtn.index);
                                                if (!calendarLayout || !calendarLayout[rowRect.rowIndex] || !calendarLayout[rowRect.rowIndex][cellBtn.index]) {
                                                    console.log("CalendarDayButton: clicked, but calendarLayout cell is invalid!");
                                                    return;
                                                }
                                                var cell = calendarLayout[rowRect.rowIndex][cellBtn.index];
                                                console.log("CalendarDayButton: Clicked cell:", JSON.stringify(cell));
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
        }
    }
}
