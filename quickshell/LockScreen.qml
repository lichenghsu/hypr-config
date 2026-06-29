import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Controls

Scope {
    id: lockRoot
    property bool active: false

    // Watch for external lock trigger written by qs-lock script
    FileView {
        id: triggerFile
        path: "/home/miles/.cache/qs-lock-trigger"
        watchChanges: true
        onFileChanged: {
            var content = triggerFile.text()
            if (content.trim().length > 0) {
                lockRoot.activate()
                pClearTrigger.running = true
            }
        }
    }

    // Clear trigger file after reading so next invocation re-fires
    Process {
        id: pClearTrigger
        command: ["sh", "-c", "echo -n > /home/miles/.cache/qs-lock-trigger"]
    }

    // PAM auth via unix_chkpwd — reads password from stdin
    Process {
        id: pAuth
        command: ["sh", "-c", "/sbin/unix_chkpwd \"$USER\" nonull"]
        stdinEnabled: true
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
    }

    function deactivate() {
        lockRoot.active = false
        passwordField.text = ""
        errorMsg.visible = false
    }

    function submitPassword() {
        if (passwordField.text.length === 0) return
        pAuth.running = true
        pAuth.write(passwordField.text + "\n")
    }

    // One window per screen
    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            visible: lockRoot.active
            color: "black"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: lockRoot.active
                ? WlrKeyboardFocus.Exclusive
                : WlrKeyboardFocus.None
            WlrLayershell.namespace: "qs-lockscreen"

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            // ── Matrix rain canvas ────────────────────────────────────────
            Canvas {
                id: matrixCanvas
                anchors.fill: parent
                visible: lockRoot.active

                property var cols: []
                property int charW: 16
                property int charH: 20
                property var charSet: "ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("")

                function initCols() {
                    var n = Math.floor(width / charW)
                    cols = []
                    for (var i = 0; i < n; i++) {
                        var len = 8 + Math.floor(Math.random() * 20)
                        var chars = []
                        for (var j = 0; j < len + 2; j++)
                            chars.push(charSet[Math.floor(Math.random() * charSet.length)])
                        cols.push({
                            y: Math.random() * -height,
                            speed: 1 + Math.random() * 2,
                            len: len,
                            chars: chars
                        })
                    }
                }

                onWidthChanged: { initCols(); requestPaint() }
                onHeightChanged: { initCols(); requestPaint() }

                onPaint: {
                    var ctx = getContext("2d")
                    var h = height, w = width

                    ctx.fillStyle = "rgba(0,0,0,0.07)"
                    ctx.fillRect(0, 0, w, h)

                    ctx.font = charH + "px 'JetBrainsMono Nerd Font', monospace"

                    for (var i = 0; i < cols.length; i++) {
                        var col = cols[i]
                        var x = i * charW

                        for (var j = 0; j < col.len; j++) {
                            var yy = col.y - j * charH
                            if (yy < 0 || yy > h) continue
                            var alpha = (1 - j / col.len)
                            if (j === 0) {
                                ctx.fillStyle = "rgba(200,255,200," + alpha + ")"
                            } else {
                                ctx.fillStyle = "rgba(0," + Math.floor(180 * alpha + 40) + ",0," + alpha + ")"
                            }
                            if (Math.random() < 0.05)
                                col.chars[j] = charSet[Math.floor(Math.random() * charSet.length)]
                            ctx.fillText(col.chars[j] || "0", x, yy)
                        }

                        col.y += col.speed * charH * 0.5
                        if (col.y - col.len * charH > h) {
                            col.y = Math.random() * -charH * 10
                            col.speed = 1 + Math.random() * 2
                            col.len = 8 + Math.floor(Math.random() * 20)
                        }
                    }
                }

                Timer {
                    interval: 50
                    running: lockRoot.active
                    repeat: true
                    onTriggered: matrixCanvas.requestPaint()
                }

                Component.onCompleted: initCols()
            }

            // ── Password box (primary screen only) ────────────────────────
            Item {
                anchors.centerIn: parent
                property var primaryScreen: Quickshell.screens.find(s => !s.name.startsWith("eDP")) ?? Quickshell.screens[0]
                visible: modelData === primaryScreen
                width: 340
                height: 150

                // Grab focus whenever lock activates
                onVisibleChanged: if (visible) focusTimer.start()
                Timer {
                    id: focusTimer
                    interval: 50
                    onTriggered: passwordField.forceActiveFocus()
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.78)
                    border.color: Qt.rgba(0, 0.8, 0, 0.5)
                    border.width: 1
                    radius: 8
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        text: ""
                        color: Qt.rgba(0, 0.9, 0, 0.9)
                        font.pixelSize: 28
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
                                color: Qt.rgba(0, 0.9, 0, 0.9)
                            }
                        }
                    }

                    // Hidden TextInput captures keystrokes exclusively
                    TextInput {
                        id: passwordField
                        width: 1; height: 1
                        echoMode: TextInput.Password
                        color: "transparent"
                        cursorVisible: false
                        focus: lockRoot.active

                        Keys.onReturnPressed: lockRoot.submitPassword()
                        Keys.onEnterPressed: lockRoot.submitPassword()
                        // ESC is intentionally ignored — cannot dismiss lock screen
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
