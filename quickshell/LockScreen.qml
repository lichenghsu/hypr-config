import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

Scope {
    id: lockRoot
    property bool active: false

    // Called by shell.qml IpcHandler lock()
    function activate() {
        lockRoot.active = true
    }

    function deactivate() {
        lockRoot.active = false
        passwordField.text = ""
        errorMsg.visible = false
    }

    function submitPassword() {
        if (passwordField.text.length === 0 || pAuth.running) return
        pAuth.pendingPw = passwordField.text
        pAuth.running = true
    }

    // Auth: stdin written after process starts to avoid timing issues
    Process {
        id: pAuth
        property string pendingPw: ""
        command: ["/home/miles/.local/bin/lock-auth.sh"]
        stdinEnabled: true
        onStarted: write(pAuth.pendingPw + "\n")
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

    // One Overlay window per screen: black background + cmatrix canvas + auth UI
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlayWin
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

            anchors.top: true; anchors.bottom: true
            anchors.left: true; anchors.right: true

            // ── Matrix rain canvas ────────────────────────────────────────
            Canvas {
                id: matrixCanvas
                anchors.fill: parent

                property var cols: []
                property int charW: 14
                property int charH: 18
                property string chars: "ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ012345789ABCDEFGHIJZ"

                function randChar() {
                    return chars[Math.floor(Math.random() * chars.length)]
                }

                function initCols() {
                    var n = Math.ceil(width / charW)
                    cols = []
                    for (var i = 0; i < n; i++) {
                        var len = 6 + Math.floor(Math.random() * 18)
                        var trail = []
                        for (var j = 0; j < len; j++) trail.push(randChar())
                        cols.push({
                            y: -Math.floor(Math.random() * (height / charH)) * charH,
                            speed: (0.5 + Math.random() * 1.5),
                            len: len,
                            trail: trail
                        })
                    }
                }

                onWidthChanged: initCols()
                onHeightChanged: initCols()
                Component.onCompleted: initCols()

                onPaint: {
                    var ctx = getContext("2d")
                    // Fade previous frame — cmatrix trail effect
                    ctx.fillStyle = "rgba(0,0,0,0.15)"
                    ctx.fillRect(0, 0, width, height)

                    ctx.font = "bold " + charH + "px monospace"
                    ctx.textBaseline = "top"

                    for (var i = 0; i < cols.length; i++) {
                        var col = cols[i]
                        var x = i * charW

                        for (var j = 0; j < col.len; j++) {
                            var y = col.y - j * charH
                            if (y < -charH || y > height) continue

                            if (j === 0) {
                                // Head: bright white-green
                                ctx.fillStyle = "#ccffcc"
                            } else {
                                // Tail: fading green
                                var brightness = Math.floor(200 * (1 - j / col.len))
                                ctx.fillStyle = "rgb(0," + (40 + brightness) + ",0)"
                            }

                            // Randomly mutate character
                            if (Math.random() < 0.04)
                                col.trail[j] = randChar()

                            ctx.fillText(col.trail[j], x, y)
                        }

                        col.y += col.speed * charH
                        if (col.y - col.len * charH > height) {
                            col.y = 0
                            col.speed = 0.5 + Math.random() * 1.5
                            col.len = 6 + Math.floor(Math.random() * 18)
                        }
                    }
                }

                Timer {
                    interval: 50
                    running: lockRoot.active
                    repeat: true
                    onTriggered: matrixCanvas.requestPaint()
                }
            }

            // ── Password UI (primary screen only) ─────────────────────────
            property bool isPrimary: overlayWin.modelData === (
                Quickshell.screens.find(s => !s.name.startsWith("eDP"))
                ?? Quickshell.screens[0]
            )

            Item {
                anchors.centerIn: parent
                visible: overlayWin.isPrimary
                width: 280
                height: 120

                onVisibleChanged: if (visible) focusTimer.start()

                Timer {
                    id: focusTimer
                    interval: 80
                    onTriggered: passwordField.forceActiveFocus()
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(0, 0, 0, 0.8)
                    border.color: "#00cc44"
                    border.width: 1
                    radius: 6
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 10

                    // Lock icon
                    Text {
                        text: ""
                        color: "#00cc44"
                        font.pixelSize: 24
                        font.family: "JetBrainsMono Nerd Font"
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    // Password dots
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 6
                        Repeater {
                            model: Math.min(passwordField.text.length, 28)
                            Rectangle {
                                width: 7; height: 7; radius: 4
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
                        text: "wrong password"
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
