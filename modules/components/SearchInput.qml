import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.theme
import qs.config

StyledRect {
    id: root
    variant: "pane"

    property alias text: textField.text
    property alias placeholderText: textField.placeholderText
    property string iconText: ""
    property string prefixText: ""  // Prefix indicator (e.g., "clip ")
    property string prefixIcon: ""  // Prefix icon (e.g., Icons.clipboard)
    property bool clearOnEscape: true
    property bool handleTabNavigation: false  // Si true, captura Tab y emite señales. Si false, usa navegación normal.
    property bool passwordMode: false  // Si true, muestra círculos en lugar del texto
    property bool disableCursorNavigation: false
    property bool interceptNumbers: false
    signal numberPressed(int number)

    signal searchTextChanged(string text)
    signal accepted
    signal shiftAccepted
    signal backspaceOnEmpty  // Signal when backspace is pressed on empty text
    signal tabPressed
    signal shiftTabPressed
    signal ctrlRPressed
    signal ctrlPPressed
    signal ctrlUpPressed
    signal ctrlDownPressed
    signal escapePressed
    signal downPressed
    signal upPressed
    signal leftPressed
    signal rightPressed
    signal pageDownPressed
    signal pageUpPressed
    signal homePressed
    signal endPressed
    signal keyReleased(var event)

    function focusInput() {
        textField.forceActiveFocus();
    }

    function clear() {
        textField.text = "";
    }

    implicitHeight: 48
    radius: Styling.radius(4)

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Text {
            text: root.iconText
            font.family: Icons.font
            font.pixelSize: 20
            color: Styling.srItem("overprimary")
            visible: root.iconText.length > 0
        }

        // Prefix indicator
        StyledRect {
            variant: "primary"
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: Styling.radius(-4)
            visible: root.prefixText.length > 0 || root.prefixIcon.length > 0

            Text {
                id: prefixLabel
                anchors.centerIn: parent
                text: root.prefixIcon.length > 0 ? root.prefixIcon : root.prefixText.trim()
                font.family: root.prefixIcon.length > 0 ? Icons.font : Config.theme.font
                font.pixelSize: root.prefixIcon.length > 0 ? 18 : Config.theme.fontSize - 1
                // font.weight: Font.Bold
                color: Styling.srItem("primary")
            }
        }

        TextField {
            id: textField
            Layout.fillWidth: true
            placeholderTextColor: Colors.outline
            font.family: Config.theme.font
            font.pixelSize: Config.theme.fontSize
            color: Colors.overBackground
            background: null
            echoMode: root.passwordMode ? TextInput.Password : TextInput.Normal
            horizontalAlignment: root.centerText ? TextInput.AlignHCenter : TextInput.AlignLeft
            function checkAndInterceptNumber(inputText) {
                if (!root.interceptNumbers) return false;
                if (!inputText || inputText.length === 0) return false;
                if (/[a-zA-Z]/.test(inputText)) return false;

                let trimmed = inputText.trim();
                if (/^[0-9]+$/.test(trimmed)) {
                    let num = parseInt(trimmed, 10);
                    if (num >= 0 && num <= 9) {
                        let ws = (num === 0) ? 10 : num;
                        Qt.callLater(() => {
                            textField.clear();
                            root.numberPressed(ws);
                        });
                        return true;
                    }
                }
                return false;
            }

            onTextEdited: {
                if (checkAndInterceptNumber(text)) return;
            }

            onTextChanged: {
                if (checkAndInterceptNumber(text)) return;
                root.searchTextChanged(text);
            }

            onAccepted: {
                root.accepted();
            }

            Keys.onPressed: event => {
                if (root.interceptNumbers && /[a-zA-Z]/.test(textField.text) === false) {
                    let targetWs = -1;
                    if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                        targetWs = event.key - Qt.Key_1 + 1;
                    } else if (event.key >= Qt.Key_KP_1 && event.key <= Qt.Key_KP_9) {
                        targetWs = event.key - Qt.Key_KP_1 + 1;
                    } else if (event.key === Qt.Key_0 || event.key === Qt.Key_KP_0) {
                        targetWs = 10;
                    }
                    if (targetWs !== -1) {
                        event.accepted = true;
                        root.numberPressed(targetWs);
                        return;
                    }
                }

                if (event.key === Qt.Key_Backspace && textField.text.length === 0) {
                    root.backspaceOnEmpty();
                    event.accepted = true;
                } else if ((event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) && root.handleTabNavigation) {
                    if (event.modifiers & Qt.ShiftModifier || event.key === Qt.Key_Backtab) {
                        root.shiftTabPressed();
                    } else {
                        root.tabPressed();
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (event.modifiers & Qt.ShiftModifier) {
                        root.shiftAccepted();
                    } else {
                        root.accepted();
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_R && (event.modifiers & Qt.ControlModifier)) {
                    root.ctrlRPressed();
                    event.accepted = true;
                } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                    root.ctrlPPressed();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up && (event.modifiers & Qt.ControlModifier)) {
                    root.ctrlUpPressed();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down && (event.modifiers & Qt.ControlModifier)) {
                    root.ctrlDownPressed();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    if (root.clearOnEscape) {
                        clear();
                    }
                    root.escapePressed();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down) {
                    root.downPressed();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    root.upPressed();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Left) {
                    // Only emit signal if cursor is at the beginning, text is empty, or cursor navigation is disabled
                    if (root.disableCursorNavigation || textField.cursorPosition === 0 || textField.text.length === 0) {
                        root.leftPressed();
                        event.accepted = true;
                    }
                } else if (event.key === Qt.Key_Right) {
                    // Only emit signal if cursor is at the end, text is empty, or cursor navigation is disabled
                    if (root.disableCursorNavigation || textField.cursorPosition === textField.text.length || textField.text.length === 0) {
                        root.rightPressed();
                        event.accepted = true;
                    }
                } else if (event.key === Qt.Key_PageDown) {
                    root.pageDownPressed();
                    event.accepted = true;
                } else if (event.key === Qt.Key_PageUp) {
                    root.pageUpPressed();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Home) {
                    root.homePressed();
                    event.accepted = true;
                } else if (event.key === Qt.Key_End) {
                    root.endPressed();
                    event.accepted = true;
                }
            }

            Keys.onReleased: event => {
                root.keyReleased(event);
            }
        }
    }
}
