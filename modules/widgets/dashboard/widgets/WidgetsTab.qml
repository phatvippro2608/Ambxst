import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.theme
import qs.modules.components
import qs.modules.globals
import qs.modules.services
import qs.config
import "calendar"

Rectangle {
    id: widgetsTabRoot
    color: "transparent"
    implicitWidth: 600
    implicitHeight: 400
    height: parent ? parent.height : 400

    property int leftPanelWidth: 0
    property var editingEvent: null

    onEditingEventChanged: {
        if (typeof startDateInput === "undefined") return;
        if (editingEvent) {
            titleInput.text = editingEvent.summary || "";
            descInput.text = editingEvent.description || "";
            
            var startD = editingEvent.start_time.indexOf("T") !== -1 ? editingEvent.start_time.split("T")[0] : "";
            var startT = editingEvent.start_time.indexOf("T") !== -1 ? editingEvent.start_time.split("T")[1].substring(0, 5) : "08:00";
            var endD = editingEvent.end_time.indexOf("T") !== -1 ? editingEvent.end_time.split("T")[0] : "";
            var endT = editingEvent.end_time.indexOf("T") !== -1 ? editingEvent.end_time.split("T")[1].substring(0, 5) : "09:00";
            
            startDateInput.text = startD;
            startTimeInput.text = startT;
            endDateInput.text = endD;
            endTimeInput.text = endT;
            
            var recIdx = recurrenceBtn.values.indexOf(editingEvent.recurrence);
            recurrenceBtn.currentIndex = recIdx !== -1 ? recIdx : 0;
        } else {
            titleInput.text = "";
            descInput.text = "";
            
            var defDate = "";
            if (calendarWidget && calendarWidget.selectedDateInfo) {
                defDate = CalendarService.formatDateStr(calendarWidget.selectedDateInfo.cellYear, calendarWidget.selectedDateInfo.cellMonth, calendarWidget.selectedDateInfo.cellDay);
            }
            
            startDateInput.text = defDate;
            startTimeInput.text = "08:00";
            endDateInput.text = defDate;
            endTimeInput.text = "09:00";
            recurrenceBtn.currentIndex = 0;
        }
    }

    Connections {
        target: calendarWidget
        function onSelectedDateInfoChanged() {
            if (calendarWidget.selectedDateInfo === null) {
                widgetsTabRoot.editingEvent = null;
            } else if (!widgetsTabRoot.editingEvent && typeof startDateInput !== "undefined") {
                var defDate = CalendarService.formatDateStr(calendarWidget.selectedDateInfo.cellYear, calendarWidget.selectedDateInfo.cellMonth, calendarWidget.selectedDateInfo.cellDay);
                startDateInput.text = defDate;
                endDateInput.text = defDate;
            }
        }
    }

    Component.onCompleted: {
        onEditingEventChanged();
    }

    // Expose details height to the parent Dashboard
    readonly property real detailsHeight: calendarWidget.selectedDateInfo !== null ? 310 : 0

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            FullPlayer {
                Layout.preferredWidth: 216
                Layout.fillHeight: true
            }

            // Widgets column
            ClippingRectangle {
                id: widgetsContainer
                Layout.preferredWidth: controlButtonsContainer.implicitWidth
                Layout.fillHeight: true
                radius: Styling.radius(4)
                color: "transparent"

                property bool circularControlDragging: false

                Flickable {
                    id: widgetsFlickable
                    anchors.fill: parent
                    contentWidth: width
                    contentHeight: columnLayout.implicitHeight
                    clip: true
                    interactive: !widgetsContainer.circularControlDragging

                    ColumnLayout {
                        id: columnLayout
                        width: parent.width
                        spacing: 8

                        // Control buttons - 5 buttons wrapped in StyledRect pane > internalbg
                        QuickControls {
                            id: controlButtonsContainer
                        }

                        Calendar {
                            id: calendarWidget
                            Layout.fillWidth: true
                            Layout.preferredHeight: implicitHeight
                        }
                    }
                }
            }

            // Notification History
            NotificationHistory {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            // Circular controls column
            ColumnLayout {
                Layout.fillHeight: true
                spacing: 8

                property bool circularControlDragging: false

                // Brightness slider - vertical
                ColumnLayout {
                    id: brightnessContainer
                    Layout.fillHeight: true
                    Layout.minimumHeight: 100
                    spacing: 8

                    // Icon container with sync animation
                    Item {
                        id: iconContainer
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        Layout.alignment: Qt.AlignHCenter

                        property bool showingSyncFeedback: false

                        StyledRect {
                            id: iconRect
                            radius: Styling.radius(4)
                            variant: {
                                if (iconMouseArea.containsMouse && Brightness.syncBrightness)
                                    return "primaryfocus";
                                if (Brightness.syncBrightness)
                                    return "primary";
                                if (iconMouseArea.containsMouse)
                                    return "focus";
                                return "pane";
                            }
                            anchors.fill: parent

                            Behavior on variant {
                                enabled: Config.animDuration > 0
                            }

                            Text {
                                id: brightnessIcon
                                anchors.centerIn: parent
                                text: iconContainer.showingSyncFeedback ? Icons.sync : Icons.sun
                                font.family: Icons.font
                                font.pixelSize: 18
                                color: Brightness.syncBrightness ? Styling.srItem("primary") : Colors.overBackground
                                rotation: iconContainer.showingSyncFeedback ? syncIconRotation : brightnessIconRotation
                                scale: iconContainer.showingSyncFeedback ? 1 : brightnessIconScale
                                opacity: iconOpacity

                                property real brightnessIconRotation: 0
                                property real brightnessIconScale: 1
                                property real iconOpacity: 1
                                property real syncIconRotation: 0

                                Behavior on text {
                                    enabled: Config.animDuration > 0
                                }

                                Behavior on color {
                                    enabled: Config.animDuration > 0
                                    ColorAnimation {
                                        duration: Config.animDuration / 2
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Behavior on opacity {
                                    enabled: Config.animDuration > 0
                                    NumberAnimation {
                                        duration: 150
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Behavior on rotation {
                                    enabled: Config.animDuration > 0
                                    NumberAnimation {
                                        duration: 400
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Behavior on scale {
                                    enabled: Config.animDuration > 0
                                    NumberAnimation {
                                        duration: 400
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            MouseArea {
                                id: iconMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    let wasActive = Brightness.syncBrightness;
                                    Brightness.syncBrightness = !Brightness.syncBrightness;

                                    // Only show sync feedback animation when activating
                                    if (Brightness.syncBrightness) {
                                        // Show sync icon instantly and start rotation
                                        iconContainer.showingSyncFeedback = true;
                                        brightnessIcon.iconOpacity = 1;
                                        brightnessIcon.syncIconRotation = 0;
                                        brightnessIcon.syncIconRotation = 360;

                                        // Hold sync icon
                                        syncHoldTimer.start();
                                    }
                                }
                                onWheel: wheel => {
                                    if (wheel.angleDelta.y > 0) {
                                        brightnessSlider.value = Math.min(1, brightnessSlider.value + 0.1);
                                    } else {
                                        brightnessSlider.value = Math.max(0, brightnessSlider.value - 0.1);
                                    }
                                }
                            }

                            Timer {
                                id: syncHoldTimer
                                interval: 600
                                onTriggered: {
                                    brightnessIcon.iconOpacity = 0;
                                    syncFadeOutTimer.start();
                                }
                            }

                            Timer {
                                id: syncFadeOutTimer
                                interval: 150
                                onTriggered: {
                                    iconContainer.showingSyncFeedback = false;
                                    brightnessIcon.iconOpacity = 1;
                                    brightnessIcon.syncIconRotation = 0; // Reset rotation
                                }
                            }
                        }
                    }

                    // Slider
                    Item {
                        Layout.preferredWidth: 48
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignHCenter

                        StyledSlider {
                            id: brightnessSlider
                            anchors.fill: parent
                            anchors.margins: 0
                            vertical: true
                            smoothDrag: true
                            value: brightnessValue
                            resizeParent: false
                            wavy: false
                            scroll: true
                            iconClickable: false
                            sliderVisible: true
                            iconPos: "start"
                            icon: ""
                            progressColor: Styling.srItem("overprimary")

                            property real brightnessValue: 0
                            property var currentMonitor: {
                                if (Brightness.monitors.length > 0) {
                                    let focusedName = AxctlService.focusedMonitor?.name ?? "";
                                    let found = null;
                                    for (let i = 0; i < Brightness.monitors.length; i++) {
                                        let mon = Brightness.monitors[i];
                                        if (mon && mon.screen && mon.screen.name === focusedName) {
                                            found = mon;
                                            break;
                                        }
                                    }
                                    return found || Brightness.monitors[0];
                                }
                                return null;
                            }

                            Component.onCompleted: {
                                if (currentMonitor && currentMonitor.ready) {
                                    brightnessValue = currentMonitor.brightness;
                                    brightnessIcon.brightnessIconRotation = (brightnessValue / 1.0) * 180;
                                    brightnessIcon.brightnessIconScale = 0.8 + (brightnessValue / 1.0) * 0.2;
                                }
                            }

                            onValueChanged: {
                                brightnessValue = value;
                                brightnessIcon.brightnessIconRotation = (value / 1.0) * 180;
                                brightnessIcon.brightnessIconScale = 0.8 + (value / 1.0) * 0.2;

                                if (Brightness.syncBrightness) {
                                    // Sync all monitors
                                    for (let i = 0; i < Brightness.monitors.length; i++) {
                                        let mon = Brightness.monitors[i];
                                        if (mon && mon.ready) {
                                            mon.setBrightness(value);
                                        }
                                    }
                                } else {
                                    // Only current monitor
                                    if (currentMonitor && currentMonitor.ready) {
                                        currentMonitor.setBrightness(value);
                                    }
                                }
                            }

                            onIsDraggingChanged: {
                                brightnessContainer.parent.circularControlDragging = isDragging;
                            }

                            Connections {
                                target: brightnessSlider.currentMonitor
                                ignoreUnknownSignals: true
                                function onBrightnessChanged() {
                                    if (brightnessSlider.currentMonitor && brightnessSlider.currentMonitor.ready && !brightnessSlider.isDragging) {
                                        brightnessSlider.brightnessValue = brightnessSlider.currentMonitor.brightness;
                                        brightnessIcon.brightnessIconRotation = (brightnessSlider.brightnessValue / 1.0) * 180;
                                        brightnessIcon.brightnessIconScale = 0.8 + (brightnessSlider.brightnessValue / 1.0) * 0.2;
                                    }
                                }
                                function onReadyChanged() {
                                    if (brightnessSlider.currentMonitor && brightnessSlider.currentMonitor.ready) {
                                        brightnessSlider.brightnessValue = brightnessSlider.currentMonitor.brightness;
                                        brightnessIcon.brightnessIconRotation = (brightnessSlider.brightnessValue / 1.0) * 180;
                                        brightnessIcon.brightnessIconScale = 0.8 + (brightnessSlider.brightnessValue / 1.0) * 0.2;
                                    }
                                }
                            }
                        }
                    }
                }

                CircularControl {
                    id: volumeControl
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    icon: {
                        if (Audio.sink?.audio?.muted)
                            return Icons.speakerSlash;
                        const vol = Audio.sink?.audio?.volume ?? 0;
                        if (vol < 0.01)
                            return Icons.speakerX;
                        if (vol < 0.19)
                            return Icons.speakerNone;
                        if (vol < 0.49)
                            return Icons.speakerLow;
                        return Icons.speakerHigh;
                    }
                    value: Audio.sink?.audio?.volume ?? 0
                    accentColor: Audio.sink?.audio?.muted ? Colors.outline : Styling.srItem("overprimary")
                    isToggleable: true
                    isToggled: !(Audio.sink?.audio?.muted ?? false)

                    onControlValueChanged: newValue => {
                        if (Audio.sink?.audio) {
                            Audio.sink.audio.volume = newValue;
                        }
                    }

                    onDraggingChanged: isDragging => {
                        parent.circularControlDragging = isDragging;
                    }

                    onToggled: {
                        if (Audio.sink?.audio) {
                            Audio.sink.audio.muted = !Audio.sink.audio.muted;
                        }
                    }
                }

                CircularControl {
                    id: micControl
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    icon: Audio.source?.audio?.muted ? Icons.micSlash : Icons.mic
                    value: Audio.source?.audio?.volume ?? 0
                    accentColor: Audio.source?.audio?.muted ? Colors.outline : Styling.srItem("overprimary")
                    isToggleable: true
                    isToggled: !(Audio.source?.audio?.muted ?? false)

                    onControlValueChanged: newValue => {
                        if (Audio.source?.audio) {
                            Audio.source.audio.volume = newValue;
                        }
                    }

                    onDraggingChanged: isDragging => {
                        parent.circularControlDragging = isDragging;
                    }

                    onToggled: {
                        if (Audio.source?.audio) {
                            Audio.source.audio.muted = !Audio.source.audio.muted;
                        }
                    }
                }
            }
        }

        // Details Panel at the bottom (stretching across the entire tab layout)
        StyledRect {
            id: calendarDetailsWidget
            variant: "pane"
            Layout.fillWidth: true
            Layout.preferredHeight: widgetsTabRoot.detailsHeight
            implicitHeight: widgetsTabRoot.detailsHeight
            radius: Styling.radius(4)
            clip: true
            visible: widgetsTabRoot.detailsHeight > 0
            opacity: widgetsTabRoot.detailsHeight / 310

            readonly property var dayEvents: {
                var _ = CalendarService.occurrences;
                return calendarWidget.selectedDateInfo ? CalendarService.getEventsForDay(calendarWidget.selectedDateInfo.cellYear, calendarWidget.selectedDateInfo.cellMonth, calendarWidget.selectedDateInfo.cellDay) : [];
            }

            // Close button (X) positioned absolutely in top right
            StyledRect {
                id: closeButton
                variant: closeMouse.containsMouse ? "focus" : "transparent"
                width: 20
                height: 20
                radius: Styling.radius(-2)
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 10
                anchors.rightMargin: 10
                z: 10

                Text {
                    anchors.centerIn: parent
                    text: Icons.x || "✕"
                    font.family: Icons.font
                    font.pixelSize: 10
                    color: Colors.overBackground
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: calendarWidget.clearSelection()
                    cursorShape: Qt.PointingHandCursor
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                // RowLayout to split into Left Column (Events list) and Right Column (Add/Edit Form)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    // LEFT COLUMN: Events list
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        spacing: 4

                        Text {
                            text: {
                                if (!calendarWidget.selectedDateInfo) return "Chi tiết ngày:";
                                var d = new Date(calendarWidget.selectedDateInfo.cellYear, calendarWidget.selectedDateInfo.cellMonth - 1, calendarWidget.selectedDateInfo.cellDay);
                                return "Chi tiết ngày: " + d.toLocaleDateString(Qt.locale(), "dddd, d/M");
                            }
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            font.bold: true
                            color: Colors.overBackground
                            Layout.fillWidth: true
                        }

                        // Scrollable list of events
                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.topMargin: 8
                            contentWidth: width
                            contentHeight: eventListColumn.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: eventListColumn
                                width: parent.width
                                spacing: 2

                                Repeater {
                                    model: calendarDetailsWidget.dayEvents
                                    delegate: StyledRect {
                                        id: eventItemDelegate
                                        readonly property var eventItem: calendarDetailsWidget.dayEvents[index]
                                        variant: "internalbg"
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 30
                                        radius: Styling.radius(-6)

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            spacing: 6

                                            Text {
                                                text: {
                                                    if (typeof eventItem === "undefined" || !eventItem) return "Cả ngày";
                                                    var st = eventItem["start_time"] || eventItem.start_time || "";
                                                    if (!st) return "Cả ngày";
                                                    return st.indexOf("T") !== -1 ? st.split("T")[1].substring(0, 5) : "Cả ngày";
                                                }
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-2)
                                                font.bold: true
                                                color: Colors.primary
                                            }

                                            Text {
                                                text: {
                                                    if (typeof eventItem === "undefined" || !eventItem) return "";
                                                    return eventItem["summary"] || eventItem.summary || "";
                                                }
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-2)
                                                color: Colors.overBackground
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            // Delete event button
                                            StyledRect {
                                                variant: delMouse.containsMouse ? "focus" : "transparent"
                                                Layout.preferredWidth: 20
                                                Layout.preferredHeight: 20
                                                radius: Styling.radius(-6)

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: Icons.trash || "🗑"
                                                    font.family: Icons.font
                                                    font.pixelSize: 10
                                                    color: Colors.error
                                                }

                                                MouseArea {
                                                    id: delMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        var eventId = (eventItem && (eventItem["id"] || eventItem.id)) || "";
                                                        if (eventId) {
                                                            CalendarService.deleteEvent(eventId, function(success, msg) {
                                                                // Reload handled automatically
                                                            });
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        // Click event to edit
                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            propagateComposedEvents: true
                                            onClicked: mouse => {
                                                // If click is not on the delete button, edit the event
                                                if (mouse.x < parent.width - 24) {
                                                    widgetsTabRoot.editingEvent = eventItemDelegate.eventItem;
                                                }
                                            }
                                        }
                                    }
                                }

                                // Show "No events" if list is empty
                                Text {
                                    visible: calendarWidget.selectedDateInfo && calendarDetailsWidget.dayEvents.length === 0
                                    text: "Không có sự kiện"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    font.italic: true
                                    color: Colors.outline
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }

                    // Vertical Separator
                    Separator {
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        vert: true
                    }

                    // RIGHT COLUMN: Add / Edit Event Form
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        spacing: 4

                        Text {
                            text: widgetsTabRoot.editingEvent ? "Sửa sự kiện:" : "Thêm sự kiện mới:"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            font.bold: true
                            color: Colors.overBackground
                            Layout.fillWidth: true
                            Layout.rightMargin: 24
                        }

                        // Title input
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text {
                                text: "Tiêu đề:"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                color: Colors.overBackground
                                Layout.preferredWidth: 60
                            }
                            StyledRect {
                                variant: "internalbg"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                radius: Styling.radius(-6)
                                TextField {
                                    id: titleInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    color: Colors.overBackground
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    background: null
                                    placeholderText: "Tên sự kiện..."
                                    placeholderTextColor: Colors.outline
                                }
                            }
                        }

                        // Description input
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text {
                                text: "Nội dung:"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                color: Colors.overBackground
                                Layout.preferredWidth: 60
                            }
                            StyledRect {
                                variant: "internalbg"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                radius: Styling.radius(-6)
                                TextField {
                                    id: descInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    color: Colors.overBackground
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    background: null
                                    placeholderText: "Chi tiết sự kiện..."
                                    placeholderTextColor: Colors.outline
                                }
                            }
                        }

                        // Start Date & Time
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text {
                                text: "Bắt đầu:"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                color: Colors.overBackground
                                Layout.preferredWidth: 60
                            }
                            // Date field
                            StyledRect {
                                variant: "internalbg"
                                Layout.fillWidth: true
                                Layout.preferredWidth: 3
                                Layout.preferredHeight: 26
                                radius: Styling.radius(-6)
                                TextField {
                                    id: startDateInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    color: Colors.overBackground
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    background: null
                                    placeholderText: "YYYY-MM-DD"
                                    placeholderTextColor: Colors.outline
                                }
                            }
                            // Time field
                            StyledRect {
                                variant: "internalbg"
                                Layout.fillWidth: true
                                Layout.preferredWidth: 2
                                Layout.preferredHeight: 26
                                radius: Styling.radius(-6)
                                TextField {
                                    id: startTimeInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    color: Colors.overBackground
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    background: null
                                    text: "08:00"
                                    placeholderText: "HH:MM"
                                    placeholderTextColor: Colors.outline
                                }
                            }
                        }

                        // End Date & Time
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text {
                                text: "Kết thúc:"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                color: Colors.overBackground
                                Layout.preferredWidth: 60
                            }
                            // Date field
                            StyledRect {
                                variant: "internalbg"
                                Layout.fillWidth: true
                                Layout.preferredWidth: 3
                                Layout.preferredHeight: 26
                                radius: Styling.radius(-6)
                                TextField {
                                    id: endDateInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    color: Colors.overBackground
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    background: null
                                    placeholderText: "YYYY-MM-DD"
                                    placeholderTextColor: Colors.outline
                                }
                            }
                            // Time field
                            StyledRect {
                                variant: "internalbg"
                                Layout.fillWidth: true
                                Layout.preferredWidth: 2
                                Layout.preferredHeight: 26
                                radius: Styling.radius(-6)
                                TextField {
                                    id: endTimeInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    color: Colors.overBackground
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    background: null
                                    text: "09:00"
                                    placeholderText: "HH:MM"
                                    placeholderTextColor: Colors.outline
                                }
                            }
                        }

                        // Recurrence Selection
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text {
                                text: "Lặp lại:"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-2)
                                color: Colors.overBackground
                                Layout.preferredWidth: 60
                            }
                            SegmentedSwitch {
                                id: recurrenceBtn
                                Layout.fillWidth: true
                                buttonSize: 26
                                options: ["Không", "Hàng ngày", "Hàng tuần", "Hàng tháng"]
                                property var values: ["none", "daily", "weekly", "monthly"]
                                currentIndex: 0
                            }
                        }

                        // Save / Update Buttons Row
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            // Cancel button (only visible when editing)
                            StyledRect {
                                visible: widgetsTabRoot.editingEvent !== null
                                variant: cancelMouse.containsMouse ? "focus" : "internalbg"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 28
                                radius: Styling.radius(-4)

                                Text {
                                    anchors.centerIn: parent
                                    text: "Hủy"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    font.bold: true
                                    color: Colors.overBackground
                                }

                                MouseArea {
                                    id: cancelMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        widgetsTabRoot.editingEvent = null;
                                    }
                                }
                            }

                            // Save/Update button
                            StyledRect {
                                variant: addMouse.containsMouse ? "primaryfocus" : "primary"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 28
                                radius: Styling.radius(-4)

                                Text {
                                    anchors.centerIn: parent
                                    text: widgetsTabRoot.editingEvent ? "Cập nhật" : "Lưu Sự Kiện"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    font.bold: true
                                    color: Styling.srItem("primary")
                                }

                                MouseArea {
                                    id: addMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (titleInput.text.trim() === "" || !calendarWidget.selectedDateInfo) return;

                                        var selDateStr = CalendarService.formatDateStr(calendarWidget.selectedDateInfo.cellYear, calendarWidget.selectedDateInfo.cellMonth, calendarWidget.selectedDateInfo.cellDay);
                                        var startD = startDateInput.text.trim() || selDateStr;
                                        var endD = endDateInput.text.trim() || selDateStr;
                                        var startT = startTimeInput.text.trim() || "08:00";
                                        var endT = endTimeInput.text.trim() || "09:00";

                                        if (startT.length === 5) startT += ":00";
                                        if (endT.length === 5) endT += ":00";

                                        var startVal = startD + "T" + startT;
                                        var endVal = endD + "T" + endT;

                                        var newEvent = {
                                            "summary": titleInput.text.trim(),
                                            "description": descInput.text.trim(),
                                            "start_time": startVal,
                                            "end_time": endVal,
                                            "recurrence": recurrenceBtn.values[recurrenceBtn.currentIndex]
                                        };

                                        if (widgetsTabRoot.editingEvent) {
                                            newEvent["id"] = widgetsTabRoot.editingEvent.id || widgetsTabRoot.editingEvent.parent_id;
                                        }

                                        CalendarService.addEvent(newEvent, function(success, event) {
                                            if (success) {
                                                titleInput.text = "";
                                                descInput.text = "";
                                                recurrenceBtn.currentIndex = 0;
                                                widgetsTabRoot.editingEvent = null;
                                            }
                                        });
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
