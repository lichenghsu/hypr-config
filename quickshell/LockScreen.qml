import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls

Scope {
    id: lockRoot
    property bool active: false

    // Actual cmatrix command running in foot terminal
    Process {
        id: pCmatrix
        command: ["foot", "--fullscreen", "--app-id=cmatrix-lock", "-e", "cmatrix", "-s", "-b"]
    }

    // PAM auth via unix_chkpwd — password passed through env var to avoid stdin race
    Process {
        id: pAuth
        property string pendingPw: ""
        command: ["sh", "-c", "printf '%s\\n' \"$QSLOCK_PASS\" | /sbin/unix_chkpwd \"$USER\" nonull"]
        environment: ({"QSLOCK_PASS": pendingPw})
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                lockRoot.deactivate()
            } else {
                passwordField.text = ""
                errorMsg.visible = true
                errorTimer.restart()
            }
        }
    }

    function activate() {
        lockRoot.active = true
        pCmatrix.running = true
    }

    function deactivate() {
        pCmatrix.signal(15) // SIGTERM
        lockRoot.active = false
        passwordField.text = ""
        errorMsg.visible = false
    }

    function submitPassword() {
        if (passwordField.text.length === 0) return
        if (pAuth.running) return
        pAuth.pendingPw = passwordField.text
        pAuth.running = true
    }

    // ── Background layer: black, covers desktop behind cmatrix ───────────
    Variants {
        model: Quickshell.screens
        PanelWindow {
            required property var modelData
            screen: modelData
            visible: lockRoot.active
            color: "black"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "qs-lockbg"
            anchors.top: true; anchors.bottom: true
            anchors.left: true; anchors.right: true
        }
    }

    // ── Overlay layer: transparent, exclusive keyboard, auth UI ──────────
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: overlayWindow
            required property var modelData
            screen: modelData
            visible: lockRoot.active
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: lockRoot.active
                ? WlrKeyboardFocus.Exclusive
                : WlrKeyboardFocus.None
            WlrLayershell.namespace: "qs-lockscreen"
            anchors.top: true; anchors.bottom: true
            anchors.left: true; anchors.right: true

            // Password UI only on primary screen
            property var primaryScreen: Quickshell.screens.find(s => !s.name.startsWith("eDP")) ?? Quickshell.screens[0]

            Item {
                anchors.centerIn: parent
                visible: overlayWindow.modelData === overlayWindow.primaryScreen
                width: 300
                height: 130

                onVisibleChanged: if (visible) focusTimer.start()
                Timer {
                    id: focusTimer
                    interval: 80
                    onTriggered: passwordField.forceActiveFocus()
                }

                // Glassmorphism box
                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.70)
                    border.color: Qt.rgba(0, 0.8, 0, 0.6)
                    border.width: 1
                    radius: 8
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 14

                    Text {
                        text: ""
                        color: "#00cc44"
                        font.pixelSize: 26
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    // Password dots
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 8
                        Repeater {
                            model: Math.min(passwordField.text.length, 24)
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: "#00cc44"
                            }
                        }
                    }

                    TextInput {
                        id: passwordField
                        width: 1; height: 1
                        echoMode: TextInput.Password
                        color: "transparent"
                        cursorVisible: false
                        focus: lockRoot.active
                        Keys.onReturnPressed: lockRoot.submitPassword()
                        Keys.onEnterPressed: lockRoot.submitPassword()
                    }

                    Text {
                        id: errorMsg
                        text: "incorrect password"
                        color: "#ff4444"
                        font.pixelSize: 11
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: false
                        Timer {
                            id: errorTimer
                            interval: 2000
                            onTriggered: errorMsg.visible = false
                        }
                    }
                }
            }
        }
    }
}
