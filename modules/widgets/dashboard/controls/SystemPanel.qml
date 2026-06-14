pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.modules.components
import qs.modules.globals
import qs.modules.theme

Item {
    // =====================
    // HELPER COMPONENTS
    // =====================

    id: root

    property int maxContentWidth: 480
    readonly property int contentWidth: Math.min(width, maxContentWidth)
    readonly property real sideMargin: (width - contentWidth) / 2
    property string currentSection: ""

    function geocodeAddress(addressText, callback) {
        function tryQuery(query) {
            if (!query) {
                callback(null, "Không tìm thấy địa điểm.");
                return ;
            }
            var xhr = new XMLHttpRequest();
            var url = "https://nominatim.openstreetmap.org/search?q=" + encodeURIComponent(query) + "&format=json&limit=1";
            xhr.open("GET", url, true);
            xhr.setRequestHeader("User-Agent", "AmbxstWeatherService/1.0");
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (xhr.status === 200) {
                        try {
                            var results = JSON.parse(xhr.responseText);
                            if (results && results.length > 0) {
                                var lat = results[0].lat;
                                var lon = results[0].lon;
                                callback(lat + "," + lon, null, results[0].display_name);
                            } else {
                                if (query.indexOf(",") !== -1) {
                                    var parts = query.split(",");
                                    parts.shift();
                                    var nextQuery = parts.join(",").trim();
                                    tryQuery(nextQuery);
                                } else {
                                    tryOpenMeteo(addressText, callback);
                                }
                            }
                        } catch (e) {
                            tryOpenMeteo(addressText, callback);
                        }
                    } else {
                        tryOpenMeteo(addressText, callback);
                    }
                }
            };
            xhr.send();
        }

        function tryOpenMeteo(query, cb) {
            var xhr = new XMLHttpRequest();
            var url = "https://geocoding-api.open-meteo.com/v1/search?name=" + encodeURIComponent(query) + "&count=1";
            xhr.open("GET", url, true);
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (xhr.status === 200) {
                        try {
                            var data = JSON.parse(xhr.responseText);
                            if (data.results && data.results.length > 0) {
                                var lat = data.results[0].latitude;
                                var lon = data.results[0].longitude;
                                cb(lat + "," + lon, null, data.results[0].name + ", " + (data.results[0].admin1 || "") + ", " + data.results[0].country);
                            } else {
                                cb(null, "Không tìm thấy địa điểm.");
                            }
                        } catch (e) {
                            cb(null, "Lỗi phân tích dữ liệu geocode.");
                        }
                    } else {
                        cb(null, "Lỗi kết nối máy chủ geocode.");
                    }
                }
            };
            xhr.send();
        }

        var currentQuery = addressText.trim();
        var coordsRegex = /^-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*$/;
        if (coordsRegex.test(currentQuery)) {
            callback(currentQuery, null, "Coordinates entered directly");
            return ;
        }
        tryQuery(currentQuery);
    }

    function detectLocation(callback) {
        function tryFreeIpapi() {
            var xhr = new XMLHttpRequest();
            var url = "https://freeipapi.com/api/json";
            xhr.open("GET", url, true);
            xhr.setRequestHeader("User-Agent", "AmbxstWeatherService/1.0");
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (xhr.status === 200) {
                        try {
                            var res = JSON.parse(xhr.responseText);
                            if (res && res.latitude !== undefined && res.longitude !== undefined) {
                                var coords = res.latitude + "," + res.longitude;
                                var name = (res.cityName || "") + ", " + (res.regionName || "") + ", " + (res.countryName || "");
                                name = name.replace(/^,\s*/, "").replace(/,\s*,/g, ",").trim();
                                callback(coords, null, name);
                                return ;
                            }
                        } catch (e) {
                        }
                    }
                    tryIpapi();
                }
            };
            xhr.send();
        }

        function tryIpapi() {
            var xhr = new XMLHttpRequest();
            var url = "https://ipapi.co/json/";
            xhr.open("GET", url, true);
            xhr.setRequestHeader("User-Agent", "AmbxstWeatherService/1.0");
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (xhr.status === 200) {
                        try {
                            var res = JSON.parse(xhr.responseText);
                            if (res && res.latitude !== undefined && res.longitude !== undefined) {
                                var coords = res.latitude + "," + res.longitude;
                                var name = (res.city || "") + ", " + (res.region || "") + ", " + (res.country_name || "");
                                name = name.replace(/^,\s*/, "").replace(/,\s*,/g, ",").trim();
                                callback(coords, null, name);
                                return ;
                            }
                        } catch (e) {
                        }
                    }
                    tryIpinfo();
                }
            };
            xhr.send();
        }

        function tryIpinfo() {
            var xhr = new XMLHttpRequest();
            var url = "https://ipinfo.io/json";
            xhr.open("GET", url, true);
            xhr.setRequestHeader("User-Agent", "AmbxstWeatherService/1.0");
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE) {
                    if (xhr.status === 200) {
                        try {
                            var res = JSON.parse(xhr.responseText);
                            if (res && res.loc) {
                                var name = (res.city || "") + ", " + (res.region || "") + ", " + (res.country || "");
                                name = name.replace(/^,\s*/, "").replace(/,\s*,/g, ",").trim();
                                callback(res.loc, null, name);
                                return ;
                            }
                        } catch (e) {
                        }
                    }
                    callback(null, "Không thể tự động phát hiện vị trí.");
                }
            };
            xhr.send();
        }

        tryFreeIpapi();
    }

    // Main content
    Flickable {
        id: mainFlickable

        anchors.fill: parent
        contentHeight: mainColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: mainColumn

            width: mainFlickable.width
            spacing: 8

            // Header wrapper
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: titlebar.height

                PanelTitlebar {
                    id: titlebar

                    width: root.contentWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    title: root.currentSection === "" ? "System" : (root.currentSection === "system" ? "System Resources" : (root.currentSection.charAt(0).toUpperCase() + root.currentSection.slice(1)))
                    statusText: ""
                    actions: {
                        if (root.currentSection !== "")
                            return [{
                            "icon": Icons.arrowLeft,
                            "tooltip": "Back",
                            "onClicked": function() {
                                root.currentSection = "";
                            }
                        }];

                        return [];
                    }
                }

            }

            // Content wrapper - centered
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: contentColumn.implicitHeight

                ColumnLayout {
                    id: contentColumn

                    width: root.contentWidth
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 16

                    // ═══════════════════════════════════════════════════════════════
                    // MENU SECTION
                    // ═══════════════════════════════════════════════════════════════
                    ColumnLayout {
                        visible: root.currentSection === ""
                        Layout.fillWidth: true
                        spacing: 8

                        SectionButton {
                            text: "Prefixes"
                            sectionId: "prefixes"
                        }

                        SectionButton {
                            text: "Weather"
                            sectionId: "weather"
                        }

                        SectionButton {
                            text: "Location"
                            sectionId: "location"
                        }

                        SectionButton {
                            text: "Performance"
                            sectionId: "performance"
                        }

                        SectionButton {
                            text: "System Resources"
                            sectionId: "system"
                        }

                        SectionButton {
                            text: "Idle"
                            sectionId: "idle"
                        }

                        SectionButton {
                            text: "Display"
                            sectionId: "display"
                        }

                    }

                    // =====================
                    // PREFIX SECTION
                    // =====================
                    ColumnLayout {
                        property string settingsSection: "prefixes"

                        visible: root.currentSection === "prefixes"
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Prefixes"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        Text {
                            text: "Keyboard shortcuts for quick actions in launcher"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overSurfaceVariant
                            opacity: 0.7
                        }

                        // Clipboard prefix
                        PrefixRow {
                            Layout.fillWidth: true
                            label: "Clipboard"
                            prefixValue: Config.prefix.clipboard
                            onPrefixEdited: (newValue) => {
                                Config.prefix.clipboard = newValue;
                            }
                        }

                        // Emoji prefix
                        PrefixRow {
                            Layout.fillWidth: true
                            label: "Emoji"
                            prefixValue: Config.prefix.emoji
                            onPrefixEdited: (newValue) => {
                                Config.prefix.emoji = newValue;
                            }
                        }

                        // Tmux prefix
                        PrefixRow {
                            Layout.fillWidth: true
                            label: "Tmux"
                            prefixValue: Config.prefix.tmux
                            onPrefixEdited: (newValue) => {
                                Config.prefix.tmux = newValue;
                            }
                        }

                        // Wallpapers prefix
                        PrefixRow {
                            Layout.fillWidth: true
                            label: "Wallpapers"
                            prefixValue: Config.prefix.wallpapers
                            onPrefixEdited: (newValue) => {
                                Config.prefix.wallpapers = newValue;
                            }
                        }

                        // Notes prefix
                        PrefixRow {
                            Layout.fillWidth: true
                            label: "Notes"
                            prefixValue: Config.prefix.notes
                            onPrefixEdited: (newValue) => {
                                Config.prefix.notes = newValue;
                            }
                        }

                    }

                    // =====================
                    // WEATHER SECTION
                    // =====================
                    ColumnLayout {
                        property string settingsSection: "weather"

                        visible: root.currentSection === "weather"
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Weather"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        // Location
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Location"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(0)
                                color: Colors.overBackground
                                Layout.preferredWidth: 100
                            }

                            StyledRect {
                                variant: "common"
                                Layout.fillWidth: true
                                Layout.preferredHeight: 36
                                radius: Styling.radius(-2)

                                TextInput {
                                    id: locationInput

                                    readonly property string configValue: Config.weather.location

                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(0)
                                    color: Colors.overBackground
                                    selectByMouse: true
                                    clip: true
                                    verticalAlignment: TextInput.AlignVCenter
                                    onConfigValueChanged: {
                                        if (text !== configValue)
                                            text = configValue;

                                    }
                                    Component.onCompleted: text = configValue
                                    onEditingFinished: {
                                        if (text !== Config.weather.location)
                                            Config.weather.location = text.trim();

                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: !locationInput.text && !locationInput.activeFocus
                                        text: "e.g. Buenos Aires, 10.1834,105.9984..."
                                        font: locationInput.font
                                        color: Colors.overSurfaceVariant
                                    }

                                }

                            }

                            // Geocode button
                            StyledRect {
                                id: geocodeBtn

                                property bool isHovered: false
                                property bool isGeocoding: false

                                variant: isGeocoding ? "primary" : (isHovered ? "focus" : "common")
                                Layout.preferredWidth: 80
                                Layout.preferredHeight: 36
                                radius: Styling.radius(-2)

                                Text {
                                    anchors.centerIn: parent
                                    text: geocodeBtn.isGeocoding ? "..." : "Geocode"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                    font.weight: Font.Bold
                                    color: geocodeBtn.item
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: geocodeBtn.isGeocoding ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onEntered: {
                                        if (!geocodeBtn.isGeocoding)
                                            geocodeBtn.isHovered = true;

                                    }
                                    onExited: geocodeBtn.isHovered = false
                                    onClicked: {
                                        if (geocodeBtn.isGeocoding || !locationInput.text.trim())
                                            return ;

                                        geocodeBtn.isGeocoding = true;
                                        resolvedText.text = "Geocoding...";
                                        LocationService.reportAccess("Weather Widget");
                                        root.geocodeAddress(locationInput.text, function(coords, error, displayName) {
                                            geocodeBtn.isGeocoding = false;
                                            if (coords) {
                                                Config.weather.location = coords;
                                                locationInput.text = coords;
                                                if (displayName)
                                                    resolvedText.text = "Resolved: " + displayName;

                                            } else {
                                                resolvedText.text = "Error: " + error;
                                            }
                                        });
                                    }
                                }

                            }

                            // Auto detect button
                            StyledRect {
                                id: autoBtn

                                property bool isHovered: false
                                property bool isDetecting: false

                                variant: isDetecting ? "primary" : (isHovered ? "focus" : "common")
                                Layout.preferredWidth: 60
                                Layout.preferredHeight: 36
                                radius: Styling.radius(-2)

                                Text {
                                    anchors.centerIn: parent
                                    text: autoBtn.isDetecting ? "..." : "Auto"
                                    font.family: Config.theme.font
                                    font.pixelSize: Styling.fontSize(-1)
                                    font.weight: Font.Bold
                                    color: autoBtn.item
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: autoBtn.isDetecting ? Qt.ArrowCursor : Qt.PointingHandCursor
                                    onEntered: {
                                        if (!autoBtn.isDetecting)
                                            autoBtn.isHovered = true;

                                    }
                                    onExited: autoBtn.isHovered = false
                                    onClicked: {
                                        if (autoBtn.isDetecting)
                                            return ;

                                        autoBtn.isDetecting = true;
                                        resolvedText.text = "Detecting location...";
                                        LocationService.reportAccess("Weather Widget");
                                        root.detectLocation(function(coords, error, displayName) {
                                            autoBtn.isDetecting = false;
                                            if (coords) {
                                                Config.weather.location = coords;
                                                locationInput.text = coords;
                                                if (displayName)
                                                    resolvedText.text = "Detected: " + displayName;

                                            } else {
                                                resolvedText.text = "Error: " + error;
                                            }
                                        });
                                    }
                                }

                            }

                        }

                        // Resolved location status display
                        Text {
                            id: resolvedText

                            text: {
                                var coords = Config.weather.location;
                                var coordsRegex = /^-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*$/;
                                if (coordsRegex.test(coords))
                                    return "Current coordinates: " + coords;

                                return coords ? "Current: " + coords : "";
                            }
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: text.startsWith("Error") ? Colors.error : Colors.overSurfaceVariant
                            Layout.fillWidth: true
                            Layout.leftMargin: 108
                            elide: Text.ElideRight
                            wrapMode: Text.WordWrap
                        }

                        // Unit selector
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Unit"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(0)
                                color: Colors.overBackground
                                Layout.preferredWidth: 100
                            }

                            Row {
                                spacing: 8

                                Repeater {
                                    model: [{
                                        "id": "C",
                                        "label": "Celsius"
                                    }, {
                                        "id": "F",
                                        "label": "Fahrenheit"
                                    }]

                                    delegate: StyledRect {
                                        id: unitButton

                                        required property var modelData
                                        required property int index
                                        property bool isSelected: Config.weather.unit === modelData.id
                                        property bool isHovered: false

                                        variant: isSelected ? "primary" : (isHovered ? "focus" : "common")
                                        width: unitLabel.width + 24
                                        height: 36
                                        radius: Styling.radius(-2)

                                        Text {
                                            id: unitLabel

                                            anchors.centerIn: parent
                                            text: unitButton.modelData.label
                                            font.family: Config.theme.font
                                            font.pixelSize: Styling.fontSize(0)
                                            font.weight: unitButton.isSelected ? Font.Bold : Font.Normal
                                            color: unitButton.item
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: unitButton.isHovered = true
                                            onExited: unitButton.isHovered = false
                                            onClicked: Config.weather.unit = unitButton.modelData.id
                                        }

                                    }

                                }

                            }

                        }

                    }

                    // =====================
                    // LOCATION SECTION
                    // =====================
                    ColumnLayout {
                        property string settingsSection: "location"

                        visible: root.currentSection === "location"
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Location Services"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        Text {
                            text: "Manage system-wide location access and application permissions."
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overSurfaceVariant
                            opacity: 0.7
                            Layout.bottomMargin: 8
                        }

                        // Global System Location Toggle
                        ToggleRow {
                            Layout.fillWidth: true
                            label: "Location Services"
                            description: "Allow system and apps to access your current location"
                            checked: LocationService.active
                            onToggled: (checked) => {
                                LocationService.toggle();
                            }
                        }

                        // App Location Permissions header
                        Text {
                            text: "App Location Permissions"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.topMargin: 16
                            Layout.bottomMargin: -4
                        }

                        // Weather Widget Permission
                        AppPermissionRow {
                            icon: Icons.mapPin
                            label: "Weather Widget"
                            description: {
                                var last = LocationService.lastAccessed["Weather Widget"];
                                return last ? "Last accessed: " + last : "Has not accessed location recently";
                            }
                            checked: Config.system.location.allowWeatherApp
                            onToggled: (checked) => {
                                Config.system.location.allowWeatherApp = checked;
                            }
                        }

                        // AI Assistant Permission
                        AppPermissionRow {
                            icon: Icons.robot
                            label: "AI Assistant"
                            description: {
                                var last = LocationService.lastAccessed["AI Assistant"];
                                return last ? "Last accessed: " + last : "Has not accessed location recently";
                            }
                            checked: Config.system.location.allowAiApp
                            onToggled: (checked) => {
                                Config.system.location.allowAiApp = checked;
                            }
                        }

                        // System Timezone Permission
                        AppPermissionRow {
                            icon: Icons.clock
                            label: "System Timezone"
                            description: {
                                var last = LocationService.lastAccessed["System Timezone"];
                                return last ? "Last accessed: " + last : "Has not accessed location recently";
                            }
                            checked: Config.system.location.allowTimezoneApp
                            onToggled: (checked) => {
                                Config.system.location.allowTimezoneApp = checked;
                            }
                        }

                    }

                    // =====================
                    // PERFORMANCE SECTION
                    // =====================
                    ColumnLayout {
                        property string settingsSection: "performance"

                        visible: root.currentSection === "performance"
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Performance"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        Text {
                            text: "Toggle visual effects to improve performance"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overSurfaceVariant
                            opacity: 0.7
                        }

                        // Blur Transition toggle
                        ToggleRow {
                            Layout.fillWidth: true
                            label: "Blur Transition"
                            description: "Animated blur when opening panels"
                            checked: Config.performance.blurTransition
                            onToggled: (checked) => {
                                Config.performance.blurTransition = checked;
                            }
                        }

                        // Window Preview toggle
                        ToggleRow {
                            Layout.fillWidth: true
                            label: "Window Preview"
                            description: "Show window thumbnails in overview"
                            checked: Config.performance.windowPreview
                            onToggled: (checked) => {
                                Config.performance.windowPreview = checked;
                            }
                        }

                        // Wavy Line toggle
                        ToggleRow {
                            Layout.fillWidth: true
                            label: "Wavy Line"
                            description: "Animated wavy line effect"
                            checked: Config.performance.wavyLine
                            onToggled: (checked) => {
                                Config.performance.wavyLine = checked;
                            }
                        }

                        // Rotate Cover Art toggle
                        ToggleRow {
                            Layout.fillWidth: true
                            label: "Disable Cover Art Rotation"
                            description: "Stop the vinyl disc from spinning"
                            checked: !Config.performance.rotateCoverArt
                            onToggled: (checked) => {
                                Config.performance.rotateCoverArt = !checked;
                            }
                        }

                    }

                    // =====================
                    // SYSTEM SECTION
                    // =====================
                    ColumnLayout {
                        property string settingsSection: "system"

                        visible: root.currentSection === "system"
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "System Resources"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        Text {
                            text: "Configure which disks to monitor"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overSurfaceVariant
                            opacity: 0.7
                        }

                        // Disks list
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Repeater {
                                id: disksRepeater

                                model: Config.system.disks

                                delegate: RowLayout {
                                    id: diskRow

                                    required property string modelData
                                    required property int index

                                    Layout.fillWidth: true
                                    spacing: 8

                                    StyledRect {
                                        variant: "common"
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 36
                                        radius: Styling.radius(-2)

                                        TextInput {
                                            id: diskInput

                                            anchors.fill: parent
                                            anchors.margins: 8
                                            font.family: Config.theme.monoFont
                                            font.pixelSize: Styling.monoFontSize(0)
                                            color: Colors.overBackground
                                            selectByMouse: true
                                            clip: true
                                            verticalAlignment: TextInput.AlignVCenter
                                            text: diskRow.modelData
                                            onEditingFinished: {
                                                if (text.trim() !== diskRow.modelData) {
                                                    let newDisks = Config.system.disks.slice();
                                                    newDisks[diskRow.index] = text.trim();
                                                    Config.system.disks = newDisks;
                                                }
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: !diskInput.text && !diskInput.activeFocus
                                                text: "e.g. /, /home..."
                                                font: diskInput.font
                                                color: Colors.overSurfaceVariant
                                            }

                                        }

                                    }

                                    // Remove button
                                    StyledRect {
                                        id: removeDiskButton

                                        variant: removeDiskArea.containsMouse ? "focus" : "common"
                                        Layout.preferredWidth: 36
                                        Layout.preferredHeight: 36
                                        radius: Styling.radius(-2)
                                        visible: disksRepeater.count > 1

                                        Text {
                                            anchors.centerIn: parent
                                            text: Icons.trash
                                            font.family: Icons.font
                                            font.pixelSize: 14
                                            color: Colors.error
                                        }

                                        MouseArea {
                                            id: removeDiskArea

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                let newDisks = Config.system.disks.slice();
                                                newDisks.splice(diskRow.index, 1);
                                                Config.system.disks = newDisks;
                                            }
                                        }

                                        StyledToolTip {
                                            visible: removeDiskArea.containsMouse
                                            tooltipText: "Remove disk"
                                        }

                                    }

                                }

                            }

                            // Add disk button
                            StyledRect {
                                id: addDiskButton

                                variant: addDiskArea.containsMouse ? "primaryfocus" : "primary"
                                Layout.preferredWidth: addDiskContent.width + 24
                                Layout.preferredHeight: 36
                                radius: Styling.radius(-2)

                                Row {
                                    id: addDiskContent

                                    anchors.centerIn: parent
                                    spacing: 6

                                    Text {
                                        text: Icons.plus
                                        font.family: Icons.font
                                        font.pixelSize: 14
                                        color: addDiskButton.item
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "Add Disk"
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(0)
                                        color: addDiskButton.item
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                }

                                MouseArea {
                                    id: addDiskArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        let newDisks = Config.system.disks.slice();
                                        newDisks.push("/");
                                        Config.system.disks = newDisks;
                                    }
                                }

                            }

                        }

                    }

                    // =====================
                    // IDLE SECTION
                    // =====================
                    ColumnLayout {
                        property string settingsSection: "idle"

                        visible: root.currentSection === "idle"
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Idle"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        TextInputRow {
                            label: "Lock Cmd"
                            value: Config.system.idle.general.lock_cmd ?? ""
                            placeholder: "Command to lock screen"
                            onValueEdited: (newValue) => {
                                if (newValue !== Config.system.idle.general.lock_cmd) {
                                    GlobalStates.markShellChanged();
                                    Config.system.idle.general.lock_cmd = newValue;
                                }
                            }
                        }

                        TextInputRow {
                            label: "Before Sleep"
                            value: Config.system.idle.general.before_sleep_cmd ?? ""
                            placeholder: "Command before sleep"
                            onValueEdited: (newValue) => {
                                if (newValue !== Config.system.idle.general.before_sleep_cmd) {
                                    GlobalStates.markShellChanged();
                                    Config.system.idle.general.before_sleep_cmd = newValue;
                                }
                            }
                        }

                        TextInputRow {
                            label: "After Sleep"
                            value: Config.system.idle.general.after_sleep_cmd ?? ""
                            placeholder: "Command after sleep"
                            onValueEdited: (newValue) => {
                                if (newValue !== Config.system.idle.general.after_sleep_cmd) {
                                    GlobalStates.markShellChanged();
                                    Config.system.idle.general.after_sleep_cmd = newValue;
                                }
                            }
                        }

                        Text {
                            text: "Listeners"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(0)
                            color: Colors.overBackground
                            Layout.topMargin: 8
                        }

                        Repeater {
                            model: Config.system.idle.listeners

                            delegate: ColumnLayout {
                                required property var modelData
                                required property int index

                                Layout.fillWidth: true
                                spacing: 4
                                Layout.bottomMargin: 8

                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 1
                                    color: Colors.surfaceBright
                                    visible: index > 0
                                }

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: "Listener " + (index + 1)
                                        font.family: Config.theme.font
                                        font.pixelSize: Styling.fontSize(-1)
                                        font.bold: true
                                        color: Styling.srItem("overprimary")
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    StyledRect {
                                        id: deleteListenerBtn

                                        variant: "error"
                                        Layout.preferredWidth: 24
                                        Layout.preferredHeight: 24
                                        radius: Styling.radius(-2)

                                        Text {
                                            anchors.centerIn: parent
                                            text: Icons.trash
                                            font.family: Icons.font
                                            color: deleteListenerBtn.item
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                // Create a copy of the list to ensure change detection
                                                var list = [];
                                                for (var i = 0; i < Config.system.idle.listeners.length; i++) list.push(Config.system.idle.listeners[i])
                                                list.splice(index, 1);
                                                Config.system.idle.listeners = list;
                                                GlobalStates.markShellChanged();
                                            }
                                        }

                                    }

                                }

                                NumberInputRow {
                                    label: "Timeout (s)"
                                    value: modelData.timeout || 0
                                    minValue: 1
                                    maxValue: 7200
                                    onValueEdited: (val) => {
                                        var list = [];
                                        for (var i = 0; i < Config.system.idle.listeners.length; i++) list.push(Config.system.idle.listeners[i])
                                        list[index].timeout = val;
                                        Config.system.idle.listeners = list;
                                        GlobalStates.markShellChanged();
                                    }
                                }

                                TextInputRow {
                                    label: "On Timeout"
                                    value: modelData.onTimeout || ""
                                    onValueEdited: (val) => {
                                        var list = [];
                                        for (var i = 0; i < Config.system.idle.listeners.length; i++) list.push(Config.system.idle.listeners[i])
                                        list[index].onTimeout = val;
                                        Config.system.idle.listeners = list;
                                        GlobalStates.markShellChanged();
                                    }
                                }

                                TextInputRow {
                                    label: "On Resume"
                                    value: modelData.onResume || ""
                                    onValueEdited: (val) => {
                                        var list = [];
                                        for (var i = 0; i < Config.system.idle.listeners.length; i++) list.push(Config.system.idle.listeners[i])
                                        list[index].onResume = val;
                                        Config.system.idle.listeners = list;
                                        GlobalStates.markShellChanged();
                                    }
                                }

                            }

                        }

                        StyledRect {
                            id: addListenerBtn

                            variant: "common"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: Styling.radius(-2)

                            Text {
                                anchors.centerIn: parent
                                text: "Add Listener"
                                font.family: Config.theme.font
                                font.pixelSize: Styling.fontSize(0)
                                font.bold: true
                                color: addListenerBtn.item
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var list = [];
                                    if (Config.system.idle.listeners) {
                                        for (var i = 0; i < Config.system.idle.listeners.length; i++) list.push(Config.system.idle.listeners[i])
                                    }
                                    list.push({
                                        "timeout": 60,
                                        "onTimeout": "",
                                        "onResume": ""
                                    });
                                    Config.system.idle.listeners = list;
                                    GlobalStates.markShellChanged();
                                }
                            }

                        }

                    }

                    // =====================
                    // DISPLAY SECTION
                    // =====================
                    ColumnLayout {
                        property string settingsSection: "display"

                        visible: root.currentSection === "display"
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Display Configuration"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-1)
                            font.weight: Font.Medium
                            color: Colors.overSurfaceVariant
                            Layout.bottomMargin: -4
                        }

                        Text {
                            text: "Select multi-monitor display mode"
                            font.family: Config.theme.font
                            font.pixelSize: Styling.fontSize(-2)
                            color: Colors.overSurfaceVariant
                            opacity: 0.7
                            Layout.bottomMargin: 8
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            ColumnLayout {
                                spacing: 8
                                Layout.fillWidth: true

                                Repeater {
                                    model: [{
                                        "id": "extend",
                                        "label": "Extend Displays",
                                        "desc": "Use all connected monitors as one large desktop"
                                    }, {
                                        "id": "mirror",
                                        "label": "Mirror / Clone",
                                        "desc": "Mirror internal screen content to external monitors"
                                    }, {
                                        "id": "internal",
                                        "label": "Internal Only",
                                        "desc": "Turn off external screens and use laptop display only"
                                    }, {
                                        "id": "external",
                                        "label": "External Only",
                                        "desc": "Turn off laptop display and use external screen(s)"
                                    }]

                                    delegate: StyledRect {
                                        id: modeButton

                                        required property var modelData
                                        required property int index
                                        property bool isSelected: Config.system.display ? (Config.system.display.mode === modelData.id) : (modelData.id === "extend")
                                        property bool isHovered: false

                                        variant: isSelected ? "primary" : (isHovered ? "focus" : "common")
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 52
                                        radius: Styling.radius(-2)

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 2

                                            Text {
                                                text: modeButton.modelData.label
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(0)
                                                font.weight: modeButton.isSelected ? Font.Bold : Font.Normal
                                                color: modeButton.item
                                            }

                                            Text {
                                                text: modeButton.modelData.desc
                                                font.family: Config.theme.font
                                                font.pixelSize: Styling.fontSize(-2)
                                                color: modeButton.item
                                                opacity: 0.7
                                            }

                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: modeButton.isHovered = true
                                            onExited: modeButton.isHovered = false
                                            onClicked: {
                                                if (Config.system.display) {
                                                    Config.system.display.mode = modeButton.modelData.id;
                                                    GlobalStates.markShellChanged();
                                                }
                                            }
                                        }

                                    }

                                }

                            }

                        }

                    }

                    // Bottom spacing
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 16
                    }

                }

            }

        }

    }

    component SectionButton: StyledRect {
        id: sectionBtn

        required property string text
        required property string sectionId
        property bool isHovered: false

        variant: isHovered ? "focus" : "pane"
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        radius: Styling.radius(0)

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16

            Text {
                text: sectionBtn.text
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                font.bold: true
                color: Colors.overBackground
                Layout.fillWidth: true
            }

            Text {
                text: Icons.caretRight
                font.family: Icons.font
                font.pixelSize: 20
                color: Colors.overSurfaceVariant
            }

        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: sectionBtn.isHovered = true
            onExited: sectionBtn.isHovered = false
            onClicked: root.currentSection = sectionBtn.sectionId
        }

    }

    // Inline component for number input rows
    component NumberInputRow: RowLayout {
        id: numberInputRowRoot

        property string label: ""
        property int value: 0
        property int minValue: 0
        property int maxValue: 100
        property string suffix: ""

        signal valueEdited(int newValue)

        Layout.fillWidth: true
        spacing: 8

        Text {
            text: numberInputRowRoot.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            color: Colors.overBackground
            Layout.fillWidth: true
        }

        StyledRect {
            variant: "common"
            Layout.preferredWidth: 60
            Layout.preferredHeight: 32
            radius: Styling.radius(-2)

            TextInput {
                id: numberTextInput

                // Sync text when external value changes
                readonly property int configValue: numberInputRowRoot.value

                anchors.fill: parent
                anchors.margins: 8
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overBackground
                selectByMouse: true
                clip: true
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                onConfigValueChanged: {
                    if (!activeFocus && text !== configValue.toString())
                        text = configValue.toString();

                }
                Component.onCompleted: text = configValue.toString()
                onEditingFinished: {
                    let newVal = parseInt(text);
                    if (!isNaN(newVal)) {
                        newVal = Math.max(numberInputRowRoot.minValue, Math.min(numberInputRowRoot.maxValue, newVal));
                        numberInputRowRoot.valueEdited(newVal);
                    }
                }

                validator: IntValidator {
                    bottom: numberInputRowRoot.minValue
                    top: numberInputRowRoot.maxValue
                }

            }

        }

        Text {
            text: numberInputRowRoot.suffix
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            color: Colors.overSurfaceVariant
            visible: suffix !== ""
        }

    }

    // Inline component for text input rows
    component TextInputRow: RowLayout {
        id: textInputRowRoot

        property string label: ""
        property string value: ""
        property string placeholder: ""

        signal valueEdited(string newValue)

        Layout.fillWidth: true
        spacing: 8

        Text {
            text: textInputRowRoot.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            color: Colors.overBackground
            Layout.preferredWidth: 100
        }

        StyledRect {
            variant: "common"
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            radius: Styling.radius(-2)

            TextInput {
                id: textInputField

                // Sync text when external value changes
                readonly property string configValue: textInputRowRoot.value

                anchors.fill: parent
                anchors.margins: 8
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overBackground
                selectByMouse: true
                clip: true
                verticalAlignment: TextInput.AlignVCenter
                onConfigValueChanged: {
                    if (!activeFocus && text !== configValue)
                        text = configValue;

                }
                Component.onCompleted: text = configValue
                onEditingFinished: {
                    textInputRowRoot.valueEdited(text);
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: textInputRowRoot.placeholder
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    color: Colors.overSurfaceVariant
                    visible: textInputField.text === ""
                }

            }

        }

    }

    // PrefixRow component for prefix inputs
    component PrefixRow: RowLayout {
        id: prefixRow

        property string label: ""
        property string prefixValue: ""

        signal prefixEdited(string newValue)

        spacing: 8

        Text {
            text: prefixRow.label
            font.family: Config.theme.font
            font.pixelSize: Styling.fontSize(0)
            color: Colors.overBackground
            Layout.preferredWidth: 100
        }

        StyledRect {
            variant: "common"
            Layout.preferredWidth: 80
            Layout.preferredHeight: 36
            radius: Styling.radius(-2)

            TextInput {
                id: prefixInput

                anchors.fill: parent
                anchors.margins: 8
                font.family: Config.theme.monoFont
                font.pixelSize: Styling.monoFontSize(0)
                color: Colors.overBackground
                selectByMouse: true
                clip: true
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                text: prefixRow.prefixValue
                maximumLength: 4
                onEditingFinished: {
                    if (text !== prefixRow.prefixValue && text.trim() !== "")
                        prefixRow.prefixEdited(text.trim());

                }
            }

        }

        Item {
            Layout.fillWidth: true
        }

    }

    // ToggleRow component for boolean toggles
    component ToggleRow: RowLayout {
        property string label: ""
        property string description: ""
        property bool checked: false

        signal toggled(bool checked)

        spacing: 8

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                text: label
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(0)
                color: Colors.overBackground
            }

            Text {
                visible: description !== ""
                text: description
                font.family: Config.theme.font
                font.pixelSize: Styling.fontSize(-2)
                color: Colors.overSurfaceVariant
                opacity: 0.7
            }

        }

        // Checkbox styled like in BindsPanel
        Item {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32

            Rectangle {
                anchors.fill: parent
                radius: Styling.radius(-4)
                color: Colors.background
                visible: !checked
            }

            StyledRect {
                variant: "primary"
                anchors.fill: parent
                radius: Styling.radius(-4)
                visible: checked
                opacity: checked ? 1 : 0

                Text {
                    anchors.centerIn: parent
                    text: Icons.accept
                    color: Styling.srItem("primary")
                    font.family: Icons.font
                    font.pixelSize: 16
                    scale: checked ? 1 : 0

                    Behavior on scale {
                        enabled: Config.animDuration > 0

                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.5
                        }

                    }

                }

                Behavior on opacity {
                    enabled: Config.animDuration > 0

                    NumberAnimation {
                        duration: Config.animDuration / 2
                        easing.type: Easing.OutQuart
                    }

                }

            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: toggled(!checked)
            }

        }

    }

    // AppPermissionRow component for app permissions with icon
    component AppPermissionRow: StyledRect {
        id: appRowRoot

        property string icon: ""
        property string label: ""
        property string description: ""
        property bool checked: false
        property bool isHovered: false

        signal toggled(bool checked)

        variant: isHovered ? "focus" : "common"
        Layout.fillWidth: true
        Layout.preferredHeight: 64
        radius: Styling.radius(-2)

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
                text: appRowRoot.icon
                font.family: Icons.font
                font.pixelSize: 20
                color: Colors.overBackground
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                Text {
                    text: appRowRoot.label
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(0)
                    font.weight: Font.Medium
                    color: Colors.overBackground
                    Layout.fillWidth: true
                }

                Text {
                    text: appRowRoot.description
                    font.family: Config.theme.font
                    font.pixelSize: Styling.fontSize(-2)
                    color: Colors.overSurfaceVariant
                    opacity: 0.7
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

            }

            Item {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    anchors.fill: parent
                    radius: Styling.radius(-4)
                    color: Colors.background
                    visible: !appRowRoot.checked
                }

                StyledRect {
                    variant: "primary"
                    anchors.fill: parent
                    radius: Styling.radius(-4)
                    visible: appRowRoot.checked
                    opacity: appRowRoot.checked ? 1 : 0

                    Text {
                        anchors.centerIn: parent
                        text: Icons.accept
                        color: Styling.srItem("primary")
                        font.family: Icons.font
                        font.pixelSize: 16
                        scale: appRowRoot.checked ? 1 : 0

                        Behavior on scale {
                            enabled: Config.animDuration > 0

                            NumberAnimation {
                                duration: Config.animDuration / 2
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.5
                            }

                        }

                    }

                    Behavior on opacity {
                        enabled: Config.animDuration > 0

                        NumberAnimation {
                            duration: Config.animDuration / 2
                            easing.type: Easing.OutQuart
                        }

                    }

                }

            }

        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: appRowRoot.isHovered = true
            onExited: appRowRoot.isHovered = false
            onClicked: appRowRoot.toggled(!appRowRoot.checked)
        }

    }

}
