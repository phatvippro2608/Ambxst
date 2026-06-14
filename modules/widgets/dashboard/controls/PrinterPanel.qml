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
    property string expandedPrinter: ""
    property bool showAddForm: false
    property string newName: ""
    property string newAddress: ""
    property string newProtocol: "socket://"
    property string newDriver: "everywhere"
    property int currentTab: 0

    Component.onCompleted: {
        console.log("DEBUG: PrinterPanel currentTab onCompleted:", root.currentTab);
    }

    Timer {
        interval: 1500
        running: true
        repeat: false
        onTriggered: {
            console.log("DEBUG: Timer triggered. currentTab was:", root.currentTab);
            root.currentTab = 0;
            console.log("DEBUG: Timer triggered. currentTab is now:", root.currentTab);
        }
    }

    readonly property var panelActions: {
        let list = [];
        if (root.currentTab === 0) {
            list.push({
                icon: Icons.plus,
                tooltip: "Add Printer",
                loading: false,
                onClicked: function () {
                    root.showAddForm = !root.showAddForm;
                    if (root.showAddForm) {
                        PrinterService.discoverPrinters();
                    }
                }
            });
        }
        list.push({
            icon: Icons.sync,
            tooltip: "Refresh",
            loading: false,
            onClicked: function () {
                PrinterService.monitorProcess.running = false;
                Qt.callLater(() => { PrinterService.monitorProcess.running = true; });
            }
        });
        return list;
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

            // Section 1: Printers Titlebar
            PanelTitlebar {
                title: "Printers"
                statusText: !PrinterService.cupsActive ? "CUPS Offline" : ""
                statusColor: Colors.red
                actions: root.panelActions
            }

            // Tab switch
            SegmentedSwitch {
                id: tabSwitch
                Layout.fillWidth: true
                options: [
                    { label: "Printers", icon: Icons.printer },
                    { label: "Jobs & History", icon: Icons.list }
                ]
                currentIndex: root.currentTab
                onIndexChanged: index => {
                    root.currentTab = index;
                }
            }

            // Tab 0: Printers & Options
            ColumnLayout {
                visible: root.currentTab === 0
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: PrinterService.printers

                    delegate: StyledRect {
                        id: printerCard
                        required property var modelData
                        required property int index

                        readonly property bool expanded: root.expandedPrinter === modelData.name

                        Layout.fillWidth: true
                        height: expanded ? (72 + optionsColumn.implicitHeight + 16) : 72
                        Layout.preferredHeight: height
                        variant: modelData.is_default ? "focus" : "common"
                        enableShadow: false
                        radius: Styling.radius(0)

                        Behavior on height {
                            enabled: Config.animDuration > 0
                            NumberAnimation {
                                duration: Config.animDuration
                                easing.type: Easing.InOutQuad
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            // Main Printer Info Row
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Text {
                                    text: Icons.printer
                                    font.family: Icons.font
                                    font.pixelSize: 22
                                    color: printerCard.item
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Layout.alignment: Qt.AlignVCenter

                                    RowLayout {
                                        spacing: 8
                                        Text {
                                            text: printerCard.modelData.name
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(0)
                                            font.bold: true
                                            color: printerCard.item
                                            elide: Text.ElideRight
                                            Layout.maximumWidth: 220
                                        }

                                        // Default badge
                                        StyledRect {
                                            id: defaultBadge
                                            visible: printerCard.modelData.is_default
                                            variant: "primary"
                                            height: 18
                                            width: 54
                                            radius: Styling.radius(-6)
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: "Default"
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-3)
                                                font.bold: true
                                                color: defaultBadge.item
                                            }
                                        }
                                    }

                                    Text {
                                        text: printerCard.modelData.device || "No device URI"
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-2)
                                        color: printerCard.item
                                        opacity: 0.8
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }

                                RowLayout {
                                    spacing: 8
                                    Layout.alignment: Qt.AlignVCenter

                                    // Status Badge
                                    StyledRect {
                                        id: statusBadge
                                        height: 24
                                        width: 80
                                        radius: Styling.radius(-4)
                                        
                                        readonly property string statusStr: printerCard.modelData.status || "unknown"
                                        readonly property bool isPrinting: statusStr === "printing" || statusStr === "processing"
                                        
                                        readonly property color badgeColor: {
                                            if (statusStr === "idle") return Colors.green;
                                            if (isPrinting) return Colors.blue;
                                            return Colors.outline;
                                        }
                                        
                                        variant: "internalbg"
                                        
                                        Rectangle {
                                            anchors.fill: parent
                                            color: statusBadge.badgeColor
                                            opacity: 0.15
                                            radius: statusBadge.radius
                                        }

                                        RowLayout {
                                            anchors.centerIn: parent
                                            spacing: 4

                                            Text {
                                                visible: statusBadge.isPrinting
                                                text: Icons.circleNotch
                                                font.family: Icons.font
                                                font.pixelSize: 10
                                                color: statusBadge.badgeColor

                                                RotationAnimation on rotation {
                                                    running: statusBadge.isPrinting
                                                    from: 0
                                                    to: 360
                                                    duration: 1000
                                                    loops: Animation.Infinite
                                                }
                                            }

                                            Text {
                                                text: statusBadge.statusStr.toUpperCase()
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-2)
                                                font.bold: true
                                                color: statusBadge.badgeColor
                                            }
                                        }
                                    }

                                    // Set Default Button
                                    Button {
                                        visible: !printerCard.modelData.is_default
                                        flat: true
                                        implicitWidth: 32
                                        implicitHeight: 32
                                        
                                        background: StyledRect {
                                            variant: parent.hovered ? "focus" : "internalbg"
                                            radius: Styling.radius(-4)
                                        }
                                        
                                        contentItem: Text {
                                            text: Icons.accept
                                            font.family: Icons.font
                                            font.pixelSize: 14
                                            color: Colors.overBackground
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        onClicked: PrinterService.setDefaultPrinter(printerCard.modelData.name)
                                        
                                        StyledToolTip {
                                            visible: parent.hovered
                                            tooltipText: "Set as Default"
                                        }
                                    }

                                    // Delete Printer Button
                                    Button {
                                        id: deleteButton
                                        flat: true
                                        implicitWidth: deleteButton.confirm ? 56 : 32
                                        implicitHeight: 32
                                        
                                        property bool confirm: false
                                        
                                        background: StyledRect {
                                            variant: deleteButton.confirm ? "error" : (parent.hovered ? "focus" : "internalbg")
                                            radius: Styling.radius(-4)
                                            enableShadow: false
                                        }
                                        
                                        contentItem: Text {
                                            text: deleteButton.confirm ? "Confirm?" : ""
                                            font.family: Config.theme.font
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: deleteButton.confirm ? Colors.overError : Colors.red
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            
                                            Text {
                                                visible: !deleteButton.confirm
                                                anchors.centerIn: parent
                                                text: Icons.trash
                                                font.family: Icons.font
                                                font.pixelSize: 14
                                                color: Colors.red
                                            }
                                        }
                                        
                                        onClicked: {
                                            if (confirm) {
                                                PrinterService.deletePrinter(printerCard.modelData.name);
                                            } else {
                                                confirm = true;
                                                resetTimer.start();
                                            }
                                        }
                                        
                                        Timer {
                                            id: resetTimer
                                            interval: 3000
                                            onTriggered: deleteButton.confirm = false
                                        }
                                        
                                        StyledToolTip {
                                            visible: parent.hovered && !deleteButton.confirm
                                            tooltipText: "Delete Printer"
                                        }
                                    }

                                    // Expand Options Button
                                    Button {
                                        flat: true
                                        implicitWidth: 32
                                        implicitHeight: 32
                                        
                                        background: StyledRect {
                                            variant: parent.hovered ? "focus" : "internalbg"
                                            radius: Styling.radius(-4)
                                        }
                                        
                                        contentItem: Text {
                                            text: printerCard.expanded ? Icons.caretUp : Icons.caretDown
                                            font.family: Icons.font
                                            font.pixelSize: 14
                                            color: printerCard.item
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        onClicked: {
                                            root.expandedPrinter = printerCard.expanded ? "" : printerCard.modelData.name;
                                        }
                                        
                                        StyledToolTip {
                                            visible: parent.hovered
                                            tooltipText: printerCard.expanded ? "Hide Settings" : "Configure Options"
                                        }
                                    }
                                }
                            }

                            // Options Section (shown when expanded)
                            ColumnLayout {
                                id: optionsColumn
                                visible: printerCard.expanded
                                Layout.fillWidth: true
                                spacing: 10
                                Layout.topMargin: 4
                                Layout.bottomMargin: 4

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: Colors.outlineVariant
                                    opacity: 0.3
                                }

                                Repeater {
                                    model: printerCard.modelData.options || []

                                    delegate: RowLayout {
                                        id: optionRow
                                        required property var modelData
                                        required property int index

                                        Layout.fillWidth: true
                                        spacing: 12

                                        Text {
                                            text: optionRow.modelData.label
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            font.bold: true
                                            color: printerCard.item
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        ComboBox {
                                            id: choiceCombo
                                            Layout.preferredWidth: 180
                                            Layout.preferredHeight: 30

                                            model: optionRow.modelData.choices
                                            currentIndex: model.indexOf(optionRow.modelData.current)

                                            onActivated: index => {
                                                const val = model[index];
                                                PrinterService.setPrinterOption(printerCard.modelData.name, optionRow.modelData.name, val);
                                            }

                                            background: StyledRect {
                                                variant: choiceCombo.hovered ? "focus" : "internalbg"
                                                radius: Styling.radius(-4)
                                                enableShadow: false
                                            }

                                            contentItem: Text {
                                                text: choiceCombo.displayText
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-2)
                                                color: Colors.overBackground
                                                verticalAlignment: Text.AlignVCenter
                                                leftPadding: 8
                                                rightPadding: 24
                                                elide: Text.ElideRight
                                            }

                                            indicator: Text {
                                                x: choiceCombo.width - width - 8
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: Icons.caretDown
                                                font.family: Icons.font
                                                font.pixelSize: 12
                                                color: Colors.overBackground
                                            }

                                            popup: Popup {
                                                y: choiceCombo.height + 2
                                                width: choiceCombo.width
                                                implicitHeight: Math.min(180, popupListView.contentHeight + 8)
                                                padding: 4

                                                background: StyledRect {
                                                    variant: "popup"
                                                    radius: Styling.radius(-2)
                                                }

                                                ListView {
                                                    id: popupListView
                                                    anchors.fill: parent
                                                    clip: true
                                                    model: choiceCombo.delegateModel
                                                    currentIndex: choiceCombo.highlightedIndex
                                                    ScrollIndicator.vertical: ScrollIndicator {}
                                                }
                                            }

                                            delegate: ItemDelegate {
                                                id: delegateItem
                                                required property var modelData
                                                required property int index

                                                width: ListView.view.width
                                                height: 28

                                                background: StyledRect {
                                                    variant: delegateItem.highlighted ? "focus" : "common"
                                                    radius: Styling.radius(-4)
                                                    enableShadow: false
                                                }

                                                contentItem: Text {
                                                    text: delegateItem.modelData
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Styling.fontSize(-2)
                                                    color: Colors.overBackground
                                                    verticalAlignment: Text.AlignVCenter
                                                    leftPadding: 8
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: PrinterService.printers.length === 0
                    text: "No printers configured"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    color: Colors.overSurfaceVariant
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 16
                }
            }

            // Tab 1: Jobs & History
            ColumnLayout {
                visible: root.currentTab === 1
                Layout.fillWidth: true
                spacing: 16

                // Section 1: Active Print Jobs
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Active Print Jobs"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(0)
                        font.weight: Font.Medium
                        color: Colors.overBackground
                    }

                    Repeater {
                        model: PrinterService.jobs

                        delegate: StyledRect {
                            id: jobCard
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            height: 64
                            variant: "common"
                            enableShadow: false
                            radius: Styling.radius(0)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 12

                                Text {
                                    text: Icons.file
                                    font.family: Icons.font
                                    font.pixelSize: 20
                                    color: Colors.overBackground
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        text: jobCard.modelData.file || jobCard.modelData.id
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-1)
                                        font.bold: true
                                        color: Colors.overBackground
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    RowLayout {
                                        spacing: 8
                                        Text {
                                            text: jobCard.modelData.printer + " • " + jobCard.modelData.size
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-2)
                                            color: Colors.overSurfaceVariant
                                        }

                                        // Processing indicator
                                        StyledRect {
                                            visible: jobCard.modelData.status === "processing"
                                            variant: "primary"
                                            height: 16
                                            width: 76
                                            radius: Styling.radius(-6)

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 4
                                                Text {
                                                    text: Icons.circleNotch
                                                    font.family: Icons.font
                                                    font.pixelSize: 8
                                                    color: Styling.srItem("overprimary")
                                                    RotationAnimation on rotation {
                                                        running: jobCard.modelData.status === "processing"
                                                        from: 0
                                                        to: 360
                                                        duration: 1000
                                                        loops: Animation.Infinite
                                                    }
                                                }
                                                Text {
                                                    text: "PRINTING"
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Styling.fontSize(-3)
                                                    font.bold: true
                                                    color: Styling.srItem("overprimary")
                                                }
                                            }
                                        }
                                    }
                                }

                                // Cancel Job Button
                                Button {
                                    flat: true
                                    implicitWidth: 32
                                    implicitHeight: 32
                                    
                                    background: StyledRect {
                                        variant: parent.hovered ? "focus" : "internalbg"
                                        radius: Styling.radius(-4)
                                    }
                                    
                                    contentItem: Text {
                                        text: Icons.trash
                                        font.family: Icons.font
                                        font.pixelSize: 14
                                        color: Colors.red
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    
                                    onClicked: PrinterService.cancelJob(jobCard.modelData.id)
                                    
                                    StyledToolTip {
                                        visible: parent.hovered
                                        tooltipText: "Cancel print job"
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: PrinterService.jobs.length === 0
                        text: "No active print jobs"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.overSurfaceVariant
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                    }
                }

                // Section 2: Job History
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "Job History"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(0)
                        font.weight: Font.Medium
                        color: Colors.overBackground
                    }

                    Repeater {
                        model: PrinterService.completedJobs

                        delegate: StyledRect {
                            id: completedJobCard
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            height: 64
                            variant: "common"
                            enableShadow: false
                            radius: Styling.radius(0)

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 12

                                Text {
                                    text: Icons.file
                                    font.family: Icons.font
                                    font.pixelSize: 20
                                    color: Colors.overSurfaceVariant
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        readonly property string displayName: {
                                            const file = completedJobCard.modelData.file;
                                            return (file && file !== "(unknown)") ? file : "Job #" + completedJobCard.modelData.id.split("-").pop();
                                        }
                                        text: displayName
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-1)
                                        font.bold: true
                                        color: Colors.overBackground
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }

                                    RowLayout {
                                        spacing: 8
                                        Text {
                                            text: completedJobCard.modelData.printer + " • " + completedJobCard.modelData.size + " • " + completedJobCard.modelData.date
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-2)
                                            color: Colors.overSurfaceVariant
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                // Status Badge
                                StyledRect {
                                    id: historyStatusBadge
                                    variant: "internalbg"
                                    height: 20
                                    width: 68
                                    radius: Styling.radius(-6)

                                    Rectangle {
                                        anchors.fill: parent
                                        color: Colors.green
                                        opacity: 0.15
                                        radius: parent.radius
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "DONE"
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-3)
                                        font.bold: true
                                        color: Colors.green
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: PrinterService.completedJobs.length === 0
                        text: "No print history available"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        color: Colors.overSurfaceVariant
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 8
                    }
                }
            }
        }
    }

    Popup {
        id: addPrinterPopup
        visible: root.showAddForm
        onClosed: {
            root.showAddForm = false;
            root.newName = "";
            root.newAddress = "";
            root.newProtocol = "socket://";
            root.newDriver = "everywhere";
            driverSearchText.text = "";
        }
        onOpened: {
            PrinterService.discoverPrinters();
            driverSearchText.text = "";
            modalSearchInput.text = "";
        }

        modal: true
        focus: true
        dim: true
        
        x: Math.round((root.width - width) / 2)
        y: Math.round((root.height - height) / 2)
        width: 640
        height: Math.min(root.height - 40, 720)
        padding: 28
        margins: 10

        closePolicy: Popup.CloseOnEscape

        background: StyledRect {
            variant: "popup"
            radius: Styling.radius(4)
            enableShadow: true
        }

        contentItem: ColumnLayout {
            spacing: 20

            // Header Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                
                Text {
                    text: Icons.printer
                    font.family: Icons.font
                    font.pixelSize: 20
                    color: Colors.blue
                    Layout.alignment: Qt.AlignVCenter
                }
                
                Text {
                    text: "Add New Printer"
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(2)
                    font.bold: true
                    color: Colors.overBackground
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }
                
                Button {
                    id: closeBtn
                    flat: true
                    implicitWidth: 34
                    implicitHeight: 34
                    background: StyledRect {
                        variant: closeBtn.hovered ? "focus" : "common"
                        backgroundOpacity: closeBtn.hovered ? -1 : 0
                        enableBorder: closeBtn.hovered
                        radius: Styling.radius(8)
                    }
                    contentItem: Text {
                        text: Icons.x
                        font.family: Icons.font
                        font.pixelSize: 12
                        color: Colors.overBackground
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: root.showAddForm = false
                }
            }

            // Scrollable Content
            ScrollView {
                id: modalScrollView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: modalScrollView.width - 16
                    spacing: 20

                    // SECTION 1: SEARCH & NETWORK DISCOVERY
                    StyledRect {
                        Layout.fillWidth: true
                        Layout.preferredHeight: searchSectionCol.implicitHeight + 32
                        variant: "common"
                        radius: Styling.radius(2)
                        
                        ColumnLayout {
                            id: searchSectionCol
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 16
                            
                            Text {
                                text: "SEARCH NETWORK DEVICES"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-3)
                                font.bold: true
                                color: Colors.blue
                                font.letterSpacing: 1.2
                            }
                            
                            StyledRect {
                                Layout.fillWidth: true
                                height: 46
                                variant: modalSearchInput.activeFocus ? "focus" : "internalbg"
                                radius: Styling.radius(-4)
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 8
                                    
                                    Text {
                                        text: Icons.magnifyingGlass
                                        font.family: Icons.font
                                        font.pixelSize: 16
                                        color: Colors.overSurfaceVariant
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    
                                    TextField {
                                        id: modalSearchInput
                                        Layout.fillWidth: true
                                        background: null
                                        placeholderText: "Search nearby or enter IP address..."
                                        placeholderTextColor: Colors.outline
                                        color: Colors.overBackground
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-1)
                                        selectByMouse: true
                                        verticalAlignment: Text.AlignVCenter
                                        topPadding: 0
                                        bottomPadding: 0
                                        leftPadding: 4
                                        rightPadding: 4
                                    }
                                }
                            }

                            // Scan IP Address Button
                            Button {
                                id: probeBtn
                                visible: {
                                    const text = modalSearchInput.text.trim();
                                    return text.length > 0 && (text.includes(".") || text.includes(":") || text === "localhost");
                                }
                                Layout.fillWidth: true
                                implicitHeight: 44
                                flat: true
                                background: StyledRect {
                                    variant: probeBtn.hovered ? "primary" : "internalbg"
                                    radius: Styling.radius(-4)
                                }
                                contentItem: RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 8
                                    Text {
                                        text: PrinterService.probing ? Icons.circleNotch : Icons.magnifyingGlass
                                        font.family: Icons.font
                                        font.pixelSize: 14
                                        color: probeBtn.hovered ? Styling.srItem("overprimary") : Colors.blue
                                        
                                        RotationAnimation on rotation {
                                            running: PrinterService.probing
                                            from: 0
                                            to: 360
                                            duration: 1000
                                            loops: Animation.Infinite
                                        }
                                    }
                                    Text {
                                        text: PrinterService.probing ? "Probing " + modalSearchInput.text.trim() + "..." : "Scan Printer at: " + modalSearchInput.text.trim()
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-1)
                                        color: probeBtn.hovered ? Styling.srItem("overprimary") : Colors.overBackground
                                        font.bold: true
                                        Layout.fillWidth: true
                                    }
                                }
                                onClicked: {
                                    PrinterService.probeIp(modalSearchInput.text.trim());
                                }
                            }

                            // Scan / Discovery results header
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text {
                                    text: PrinterService.probedDevices.length > 0 ? "Detected Devices" : "Discovered Network Devices"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    font.bold: true
                                    color: Colors.overSurfaceVariant
                                }
                                
                                Text {
                                    visible: PrinterService.discovering
                                    text: Icons.circleNotch
                                    font.family: Icons.font
                                    font.pixelSize: 10
                                    color: Colors.blue
                                    RotationAnimation on rotation {
                                        running: PrinterService.discovering
                                        from: 0
                                        to: 360
                                        duration: 1000
                                        loops: Animation.Infinite
                                    }
                                }
                            }

                            // Devices list
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                
                                Repeater {
                                    model: {
                                        if (PrinterService.probedDevices.length > 0) {
                                            return PrinterService.probedDevices;
                                        }
                                        const query = modalSearchInput.text.toLowerCase().trim();
                                        if (query === "" || query.includes(".")) {
                                            return PrinterService.discoveredDevices;
                                        }
                                        return PrinterService.discoveredDevices.filter(d => d.name.toLowerCase().includes(query) || d.uri.toLowerCase().includes(query));
                                    }

                                    delegate: Button {
                                        id: devBtn
                                        required property var modelData
                                        required property int index

                                        Layout.fillWidth: true
                                        implicitHeight: 60
                                        flat: true
                                        
                                        readonly property bool isSelected: root.newName === devBtn.modelData.name.replace(/[^a-zA-Z0-9]/g, "_").replace(/_+/g, "_").replace(/(^_|_$)/g, "")

                                        background: StyledRect {
                                            variant: devBtn.hovered ? "focus" : "internalbg"
                                            radius: Styling.radius(-2)
                                            border.color: devBtn.isSelected ? Colors.blue : "transparent"
                                            border.width: 1
                                        }

                                        contentItem: RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 14
                                            
                                            StyledRect {
                                                width: 36
                                                height: 36
                                                radius: Styling.radius(-4)
                                                variant: devBtn.isSelected ? "primary" : "common"
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: Icons.printer
                                                    font.family: Icons.font
                                                    font.pixelSize: 16
                                                    color: parent.item
                                                }
                                            }
                                            
                                            ColumnLayout {
                                                spacing: 1
                                                Layout.fillWidth: true
                                                Text {
                                                    text: devBtn.modelData.name
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Styling.fontSize(-1)
                                                    font.bold: true
                                                    color: Colors.overBackground
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: devBtn.modelData.uri
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Styling.fontSize(-3)
                                                    color: Colors.overSurfaceVariant
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }
                                            
                                            // Protocol badge
                                            StyledRect {
                                                id: protoBadge
                                                height: 20
                                                width: 60
                                                radius: Styling.radius(-6)
                                                
                                                readonly property string proto: devBtn.modelData.uri.split("://", 1)[0].toLowerCase()
                                                
                                                readonly property color badgeColor: {
                                                    if (proto === "ipp" || proto === "ipps") return Colors.blue;
                                                    if (proto === "socket") return Colors.green;
                                                    if (proto === "lpd") return Colors.magenta;
                                                    return Colors.outline;
                                                }
                                                
                                                variant: "internalbg"
                                                
                                                Rectangle {
                                                    anchors.fill: parent
                                                    color: protoBadge.badgeColor
                                                    opacity: 0.15
                                                    radius: protoBadge.radius
                                                }
                                                
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: protoBadge.proto.toUpperCase()
                                                    font.family: Config.theme.font
                                                    font.pixelSize: Styling.fontSize(-3)
                                                    font.bold: true
                                                    color: protoBadge.badgeColor
                                                }
                                            }
                                        }

                                        onClicked: {
                                            let cleanName = devBtn.modelData.name
                                                .replace(/[^a-zA-Z0-9]/g, "_")
                                                .replace(/_+/g, "_")
                                                .replace(/(^_|_$)/g, "");
                                            root.newName = cleanName;
                                            
                                            let uri = devBtn.modelData.uri;
                                            if (uri.includes("://")) {
                                                let parts = uri.split("://", 2);
                                                root.newProtocol = parts[0] + "://";
                                                root.newAddress = parts[1];
                                            } else {
                                                root.newProtocol = "socket://";
                                                root.newAddress = uri;
                                            }
                                            
                                            if (root.newProtocol === "ipp://" || root.newProtocol === "ipps://" || root.newProtocol.includes("dnssd")) {
                                                root.newDriver = "everywhere";
                                            } else {
                                                root.newDriver = "drv:///sample.drv/generpcl.ppd";
                                            }
                                        }
                                    }
                                }

                                // Empty State
                                ColumnLayout {
                                    visible: (PrinterService.probedDevices.length === 0 && PrinterService.discoveredDevices.length === 0) && !PrinterService.discovering
                                    Layout.fillWidth: true
                                    spacing: 8
                                    Layout.topMargin: 12
                                    Layout.bottomMargin: 12
                                    
                                    Text {
                                        text: Icons.globe
                                        font.family: Icons.font
                                        font.pixelSize: 28
                                        color: Colors.outline
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    
                                    Text {
                                        text: "No network devices found. Enter IP above to scan."
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-2)
                                        color: Colors.overSurfaceVariant
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }
                            }
                        }
                    }

                    // SECTION 2: MANUAL CONFIGURATION
                    StyledRect {
                        Layout.fillWidth: true
                        Layout.preferredHeight: configSectionCol.implicitHeight + 32
                        variant: "common"
                        radius: Styling.radius(2)
                        
                        ColumnLayout {
                            id: configSectionCol
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 16
                            
                            Text {
                                text: "MANUAL CONFIGURATION"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-3)
                                font.bold: true
                                color: Colors.blue
                                font.letterSpacing: 1.2
                            }
                            
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Text {
                                        text: "Printer Name"
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-2)
                                        font.bold: true
                                        color: Colors.overSurfaceVariant
                                    }
                                    StyledRect {
                                        Layout.fillWidth: true
                                        height: 46
                                        variant: modalNameField.activeFocus ? "focus" : "internalbg"
                                        radius: Styling.radius(-4)
                                        
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 6
                                            
                                            Text {
                                                text: Icons.edit
                                                font.family: Icons.font
                                                font.pixelSize: 12
                                                color: Colors.overSurfaceVariant
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            TextField {
                                                id: modalNameField
                                                Layout.fillWidth: true
                                                topPadding: 0
                                                bottomPadding: 0
                                                leftPadding: 4
                                                rightPadding: 4
                                                background: null
                                                text: root.newName
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-1)
                                                color: Colors.overBackground
                                                placeholderTextColor: Colors.outline
                                                selectByMouse: true
                                                verticalAlignment: Text.AlignVCenter
                                                onTextChanged: root.newName = text
                                                placeholderText: "e.g., Office_Printer"
                                            }
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.preferredWidth: 140
                                    spacing: 4
                                    Text {
                                        text: "Protocol"
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-2)
                                        font.bold: true
                                        color: Colors.overSurfaceVariant
                                    }
                                    ComboBox {
                                        id: modalProtocolCombo
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 46
                                        model: ["socket://", "ipp://", "ipps://", "lpd://", "Custom"]
                                        currentIndex: model.indexOf(root.newProtocol) >= 0 ? model.indexOf(root.newProtocol) : 4
                                        onActivated: index => {
                                            if (index < 4) {
                                                root.newProtocol = model[index];
                                            } else {
                                                root.newProtocol = "";
                                            }
                                        }
                                        background: StyledRect {
                                            variant: modalProtocolCombo.hovered ? "focus" : "internalbg"
                                            radius: Styling.radius(-4)
                                        }
                                        contentItem: Text {
                                            text: modalProtocolCombo.displayText
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            color: Colors.overBackground
                                            verticalAlignment: Text.AlignVCenter
                                            leftPadding: 10
                                        }
                                        indicator: Text {
                                            x: modalProtocolCombo.width - width - 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: Icons.caretDown
                                            font.family: Icons.font
                                            font.pixelSize: 12
                                            color: Colors.overBackground
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text {
                                    text: root.newProtocol === "" ? "Full Connection URI" : "IP Address / Hostname"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    font.bold: true
                                    color: Colors.overSurfaceVariant
                                }
                                StyledRect {
                                    Layout.fillWidth: true
                                    height: 46
                                    variant: modalAddrField.activeFocus ? "focus" : "internalbg"
                                    radius: Styling.radius(-4)
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 6
                                        
                                        Text {
                                            text: Icons.globe
                                            font.family: Icons.font
                                            font.pixelSize: 12
                                            color: Colors.overSurfaceVariant
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        TextField {
                                            id: modalAddrField
                                            Layout.fillWidth: true
                                            topPadding: 0
                                            bottomPadding: 0
                                            leftPadding: 4
                                            rightPadding: 4
                                            background: null
                                            text: root.newAddress
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            color: Colors.overBackground
                                            placeholderTextColor: Colors.outline
                                            selectByMouse: true
                                            verticalAlignment: Text.AlignVCenter
                                            onTextChanged: root.newAddress = text
                                            placeholderText: root.newProtocol === "" ? "e.g., socket://192.168.1.100" : "e.g., 192.168.1.100"
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // SECTION 3: DRIVER SELECTION
                    StyledRect {
                        Layout.fillWidth: true
                        Layout.preferredHeight: driverSectionCol.implicitHeight + 32
                        variant: "common"
                        radius: Styling.radius(2)
                        
                        ColumnLayout {
                            id: driverSectionCol
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 16
                            
                            Text {
                                text: "DRIVER AND MODEL"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(-3)
                                font.bold: true
                                color: Colors.blue
                                font.letterSpacing: 1.2
                            }
                            
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text {
                                    text: "Driver / Model (Searchable)"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-2)
                                    font.bold: true
                                    color: Colors.overSurfaceVariant
                                }

                                StyledRect {
                                    Layout.fillWidth: true
                                    height: 46
                                    variant: driverSearchText.activeFocus ? "focus" : "internalbg"
                                    radius: Styling.radius(-4)
                                    
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 6
                                        
                                        Text {
                                            text: Icons.file
                                            font.family: Icons.font
                                            font.pixelSize: 12
                                            color: Colors.overSurfaceVariant
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        
                                        TextField {
                                            id: driverSearchText
                                            Layout.fillWidth: true
                                            topPadding: 0
                                            bottomPadding: 0
                                            leftPadding: 4
                                            rightPadding: 4
                                            background: null
                                            placeholderText: "Search local driver database (e.g. LaserJet, Epson)"
                                            placeholderTextColor: Colors.outline
                                            color: Colors.overBackground
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(-1)
                                            selectByMouse: true
                                            verticalAlignment: Text.AlignVCenter
                                            
                                            onTextChanged: {
                                                if (text.trim().length >= 2) {
                                                    PrinterService.searchDrivers(text.trim());
                                                }
                                            }
                                        }
                                        
                                        Text {
                                            visible: PrinterService.searchingDrivers
                                            text: Icons.circleNotch
                                            font.family: Icons.font
                                            font.pixelSize: 12
                                            color: Colors.overBackground
                                            RotationAnimation on rotation {
                                                running: PrinterService.searchingDrivers
                                                from: 0
                                                to: 360
                                                duration: 1000
                                                loops: Animation.Infinite
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: "Selected URI: " + root.newDriver
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-3)
                                    color: Colors.blue
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                StyledRect {
                                    visible: driverSearchText.text.trim().length >= 2 && PrinterService.searchedDrivers.length > 0
                                    Layout.fillWidth: true
                                    height: 120
                                    variant: "internalbg"
                                    radius: Styling.radius(-4)
                                    border.color: Colors.outlineVariant
                                    border.width: 1
                                    
                                    ScrollView {
                                        anchors.fill: parent
                                        clip: true
                                        
                                        ColumnLayout {
                                            width: parent.width
                                            spacing: 0
                                            
                                            Repeater {
                                                model: PrinterService.searchedDrivers
                                                
                                                delegate: ItemDelegate {
                                                    id: driverItem
                                                    required property var modelData
                                                    required property int index
                                                    Layout.fillWidth: true
                                                    implicitHeight: 32
                                                    
                                                    background: StyledRect {
                                                        variant: driverItem.hovered ? "focus" : "internalbg"
                                                        radius: Styling.radius(-4)
                                                        enableShadow: false
                                                    }
                                                    
                                                    contentItem: Text {
                                                        text: driverItem.modelData.name
                                                        font.family: Config.theme.font
                                                        font.pixelSize: Styling.fontSize(-2)
                                                        color: Colors.overBackground
                                                        verticalAlignment: Text.AlignVCenter
                                                        elide: Text.ElideRight
                                                        leftPadding: 8
                                                    }
                                                    
                                                    onClicked: {
                                                        root.newDriver = driverItem.modelData.uri;
                                                        driverSearchText.text = driverItem.modelData.name;
                                                        driverSearchText.focus = false;
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                ComboBox {
                                    id: driverPresetsCombo
                                    visible: driverSearchText.text.trim().length < 2 || PrinterService.searchedDrivers.length === 0
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 46
                                    
                                    readonly property var drivers: [
                                        {"label": "Auto / Driverless (IPP Everywhere)", "value": "everywhere"},
                                        {"label": "Generic PCL Laser Printer", "value": "drv:///sample.drv/generpcl.ppd"},
                                        {"label": "Generic PostScript Printer", "value": "drv:///sample.drv/generic.ppd"},
                                        {"label": "Generic PDF Printer", "value": "lsb/usr/cupsfilters/Generic-PDF_Printer-PDF.ppd"},
                                        {"label": "Raw (No Driver / Passthrough)", "value": "raw"}
                                    ]

                                    model: drivers
                                    textRole: "label"
                                    currentIndex: {
                                        for (let i = 0; i < drivers.length; i++) {
                                            if (drivers[i].value === root.newDriver) return i;
                                        }
                                        return 0;
                                    }

                                    onActivated: index => {
                                        root.newDriver = drivers[index].value;
                                        driverSearchText.text = drivers[index].label;
                                    }

                                    background: StyledRect {
                                        variant: driverPresetsCombo.hovered ? "focus" : "internalbg"
                                        radius: Styling.radius(-4)
                                    }
                                    contentItem: Text {
                                        text: driverPresetsCombo.displayText
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-1)
                                        color: Colors.overBackground
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: 10
                                    }
                                    indicator: Text {
                                        x: driverPresetsCombo.width - width - 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Icons.caretDown
                                        font.family: Icons.font
                                        font.pixelSize: 12
                                        color: Colors.overBackground
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Bottom Action Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Layout.topMargin: 8
                
                Item { Layout.fillWidth: true }

                Button {
                    id: cancelBtn
                    flat: true
                    implicitWidth: 120
                    implicitHeight: 44
                    background: StyledRect {
                        variant: cancelBtn.hovered ? "focus" : "common"
                        radius: Styling.radius(-4)
                    }
                    contentItem: Text {
                        text: "Cancel"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.bold: true
                        color: Colors.overBackground
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        root.showAddForm = false;
                    }
                }

                Button {
                    id: addBtn
                    flat: true
                    implicitWidth: 130
                    implicitHeight: 44
                    enabled: root.newName.trim() !== "" && root.newAddress.trim() !== ""
                    
                    background: StyledRect {
                        variant: addBtn.enabled ? (addBtn.hovered ? "primary" : "focus") : "internalbg"
                        radius: Styling.radius(-4)
                    }
                    contentItem: Text {
                        text: "Add Printer"
                        font.family: Config.theme.font
                        font.pixelSize: Styling.fontSize(-1)
                        font.bold: true
                        color: addBtn.enabled ? Styling.srItem("overprimary") : Colors.overSurfaceVariant
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    
                    onClicked: {
                        const fullUri = root.newProtocol + root.newAddress;
                        if (root.newDriver === "raw") {
                            PrinterService.addRawPrinter(root.newName.trim(), fullUri);
                        } else {
                            PrinterService.addPrinter(root.newName.trim(), fullUri, root.newDriver);
                        }
                        root.showAddForm = false;
                    }
                }
            }
        }
    }
}
