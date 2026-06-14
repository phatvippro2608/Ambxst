import QtQuick
import QtQuick.Layouts
import qs.config

Item {
    id: root

    property string text: ""
    property alias font: textLabel.font
    property alias color: textLabel.color
    property int horizontalAlignment: Text.AlignHCenter
    property int verticalAlignment: Text.AlignVCenter

    property int delay: 2000          // Delay at endpoints in ms
    property int speed: 30            // Pixels per second to scroll
    property string type: "continuous" // "continuous", "bounce", or "fade-snap"
    property int separatorWidth: 48    // Spacing between repeated text in continuous mode

    clip: true
    implicitHeight: textLabel.implicitHeight

    readonly property bool needsScrolling: textLabel.implicitWidth > width

    onTextChanged: resetAndRestart()
    onWidthChanged: resetAndRestart()
    onNeedsScrollingChanged: resetAndRestart()
    onTypeChanged: resetAndRestart()

    function resetAndRestart() {
        continuousAnim.stop();
        bounceAnim.stop();
        fadeSnapAnim.stop();
        textRow.x = 0;
        textRow.opacity = 1.0;
        if (needsScrolling && visible) {
            if (type === "continuous") {
                continuousAnim.restart();
            } else if (type === "bounce") {
                bounceAnim.restart();
            } else if (type === "fade-snap") {
                fadeSnapAnim.restart();
            }
        }
    }

    onVisibleChanged: {
        if (visible && needsScrolling) {
            if (type === "continuous") {
                continuousAnim.restart();
            } else if (type === "bounce") {
                bounceAnim.restart();
            } else if (type === "fade-snap") {
                fadeSnapAnim.restart();
            }
        } else {
            continuousAnim.stop();
            bounceAnim.stop();
            fadeSnapAnim.stop();
        }
    }

    Row {
        id: textRow
        height: parent.height
        spacing: root.separatorWidth

        Text {
            id: textLabel
            text: root.text
            height: parent.height
            verticalAlignment: root.verticalAlignment
            horizontalAlignment: root.needsScrolling ? Text.AlignLeft : root.horizontalAlignment
            elide: Text.ElideNone
            width: root.needsScrolling ? implicitWidth : root.width
        }

        Text {
            id: textLabelRepeat
            text: root.text
            height: parent.height
            verticalAlignment: root.verticalAlignment
            horizontalAlignment: Text.AlignLeft
            elide: Text.ElideNone
            width: implicitWidth
            visible: root.needsScrolling && root.type === "continuous"
            font: textLabel.font
            color: textLabel.color
        }
    }

    // 1. Continuous Wrap-around Animation
    SequentialAnimation {
        id: continuousAnim
        loops: Animation.Infinite
        running: false

        // Pause at start (fully aligned)
        PauseAnimation { duration: root.delay }

        // Scroll one full period (text + separator)
        NumberAnimation {
            target: textRow
            property: "x"
            from: 0
            to: -(textLabel.implicitWidth + root.separatorWidth)
            duration: Math.max(1000, (textLabel.implicitWidth + root.separatorWidth) * 1000 / root.speed)
            easing.type: Easing.Linear
        }
    }

    // 2. Bounce Animation (back and forth)
    SequentialAnimation {
        id: bounceAnim
        loops: Animation.Infinite
        running: false

        // Pause at start
        PauseAnimation { duration: root.delay }

        // Scroll to end
        NumberAnimation {
            target: textRow
            property: "x"
            from: 0
            to: root.width - textLabel.implicitWidth - 8
            duration: Math.max(1000, Math.abs(textLabel.implicitWidth - root.width) * 1000 / root.speed)
            easing.type: Easing.InOutQuad
        }

        // Pause at end
        PauseAnimation { duration: root.delay }

        // Scroll back to start
        NumberAnimation {
            target: textRow
            property: "x"
            to: 0
            duration: Math.max(1000, Math.abs(textLabel.implicitWidth - root.width) * 1000 / root.speed)
            easing.type: Easing.InOutQuad
        }
    }

    // 3. Fade and Snap back Animation
    SequentialAnimation {
        id: fadeSnapAnim
        loops: Animation.Infinite
        running: false

        // Pause at start
        PauseAnimation { duration: root.delay }

        // Scroll to end
        NumberAnimation {
            target: textRow
            property: "x"
            from: 0
            to: root.width - textLabel.implicitWidth - 8
            duration: Math.max(1000, Math.abs(textLabel.implicitWidth - root.width) * 1000 / root.speed)
            easing.type: Easing.InOutQuad
        }

        // Pause at end
        PauseAnimation { duration: root.delay }

        // Fade out
        NumberAnimation {
            target: textRow
            property: "opacity"
            to: 0
            duration: 300
            easing.type: Easing.OutQuad
        }

        // Jump back to start
        PropertyAction {
            target: textRow
            property: "x"
            value: 0
        }

        // Fade in
        NumberAnimation {
            target: textRow
            property: "opacity"
            to: 1
            duration: 300
            easing.type: Easing.InQuad
        }
    }

    Component.onCompleted: {
        resetAndRestart();
    }
}
