import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

Scope {
    id: lockRoot
    property bool active: false
    property bool authFailed: false

    readonly property string matrixChars: "ｦｱｼﾝABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%&*()-+=[]{}|;:,./<>?"
    readonly property int atlasCharW: 14
    readonly property int atlasCharH: 18

    function activate() {
        lockRoot.active = true
        lockRoot.authFailed = false
        pSubmap.running = true
    }

    function deactivate() {
        lockRoot.active = false
        lockRoot.authFailed = false
        pReset.running = true
    }

    function submitPassword(pw) {
        if (pw.length === 0 || pAuth.running) return
        pAuth.pendingPw = pw
        pAuth.running = true
    }

    Process {
        id: pSubmap
        command: ["hyprctl", "dispatch", "submap", "locked"]
        running: false
    }

    Process {
        id: pReset
        command: ["hyprctl", "dispatch", "submap", "reset"]
        running: false
    }

    Timer {
        id: authFailTimer
        interval: 10
        repeat: false
        onTriggered: lockRoot.authFailed = true
    }

    Process {
        id: pAuth
        property string pendingPw: ""
        command: ["/home/miles/.local/bin/lock-auth.sh"]
        stdinEnabled: true
        onStarted: write(pAuth.pendingPw + "\n")
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) lockRoot.deactivate()
            else authFailTimer.start()
        }
    }

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

            HoverHandler { cursorShape: Qt.BlankCursor }

            property bool isPrimary: overlayWin.modelData === (
                Quickshell.screens.find(s => !s.name.startsWith("eDP"))
                ?? Quickshell.screens[0]
            )

            // Atlas lives inside each PanelWindow — cannot share across windows
            Canvas {
                id: atlasCanvas
                visible: false
                width: lockRoot.matrixChars.length * lockRoot.atlasCharW
                height: lockRoot.atlasCharH * 4   // 4 tiers: head, bright, medium, dim

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    ctx.font = "bold " + lockRoot.atlasCharH + "px monospace"
                    ctx.textBaseline = "top"
                    var chars = lockRoot.matrixChars
                    var cW = lockRoot.atlasCharW, cH = lockRoot.atlasCharH
                    var colors = ["#ccffcc", "#00cc44", "#007722", "#003311"]
                    for (var tier = 0; tier < 4; tier++) {
                        ctx.fillStyle = colors[tier]
                        for (var i = 0; i < chars.length; i++)
                            ctx.fillText(chars[i], i * cW, tier * cH)
                    }
                }
                Component.onCompleted: requestPaint()
            }

            // ── GPU matrix rain ───────────────────────────────────────────
            ShaderEffect {
                anchors.fill: parent

                property var atlasSource: atlasCanvas
                property real time: 0.0
                property real gridW: lockRoot.atlasCharW / overlayWin.width
                property real gridH: lockRoot.atlasCharH / overlayWin.height
                property real numChars: lockRoot.matrixChars.length
                property real trailLen: 14.0

                fragmentShader: Qt.resolvedUrl("matrix.frag.qsb")

                Timer {
                    interval: 33
                    running: lockRoot.active
                    repeat: true
                    onTriggered: parent.time += 0.033
                }
            }

            // ── Auth UI (primary screen only) ─────────────────────────────
            Column {
                anchors.centerIn: parent
                visible: overlayWin.isPrimary
                spacing: 28

                onVisibleChanged: if (visible) focusTimer.start()

                Connections {
                    target: lockRoot
                    function onActiveChanged() {
                        if (lockRoot.active) passwordField.text = ""
                    }
                }

                Timer {
                    id: focusTimer
                    interval: 80
                    onTriggered: passwordField.forceActiveFocus()
                }

                // ── Clock ─────────────────────────────────────────────────
                Text {
                    id: clockText
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: "#00ff41"
                    font.pixelSize: 72
                    font.family: "JetBrainsMono Nerd Font"
                    font.weight: Font.Light

                    property var now: new Date()
                    text: Qt.formatTime(now, "hh:mm")

                    Timer {
                        interval: 1000
                        running: lockRoot.active
                        repeat: true
                        onTriggered: clockText.now = new Date()
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: "#009920"
                    font.pixelSize: 14
                    font.family: "JetBrainsMono Nerd Font"
                    text: Qt.formatDate(new Date(), "dddd, MMMM d")
                }

                // Hidden input — off-screen to avoid I-beam cursor
                TextInput {
                    id: passwordField
                    x: -9999; y: -9999
                    width: 1; height: 1
                    echoMode: TextInput.Password
                    color: "transparent"
                    cursorVisible: false
                    focus: lockRoot.active
                    Keys.onReturnPressed: lockRoot.submitPassword(passwordField.text)
                    Keys.onEnterPressed: lockRoot.submitPassword(passwordField.text)
                }

                // ── Password dots ─────────────────────────────────────────
                Item {
                    id: dotsContainer
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 240
                    height: 32

                    property bool shaking: false
                    property real shakeOffset: 0
                    transform: Translate { x: dotsContainer.shakeOffset }

                    SequentialAnimation {
                        id: shakeAnim
                        NumberAnimation { target: dotsContainer; property: "shakeOffset"; to: -10; duration: 40 }
                        NumberAnimation { target: dotsContainer; property: "shakeOffset"; to:  18; duration: 60 }
                        NumberAnimation { target: dotsContainer; property: "shakeOffset"; to: -14; duration: 50 }
                        NumberAnimation { target: dotsContainer; property: "shakeOffset"; to:   8; duration: 50 }
                        NumberAnimation { target: dotsContainer; property: "shakeOffset"; to:   0; duration: 40 }
                        onFinished: dotsContainer.shaking = false
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: pAuth.running
                        text: "authenticating..."
                        color: "#00cc44"
                        font.pixelSize: 13
                        font.family: "JetBrainsMono Nerd Font"
                    }

                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: !pAuth.running
                        Repeater {
                            model: Math.min(passwordField.text.length, 28)
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: dotsContainer.shaking ? "#ff4444" : "#00ff41"
                                Behavior on color { ColorAnimation { duration: 80 } }
                            }
                        }
                    }
                }

                // ── Error ─────────────────────────────────────────────────
                Connections {
                    target: lockRoot
                    function onAuthFailedChanged() {
                        if (!lockRoot.authFailed || !overlayWin.isPrimary) return
                        lockRoot.authFailed = false
                        dotsContainer.shaking = true
                        shakeAnim.restart()
                        errorMsg.visible = true
                        errorMsg.opacity = 1
                        errorTimer.restart()
                    }
                }

                Text {
                    id: errorMsg
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "wrong password"
                    color: "#ff4444"
                    font.pixelSize: 13
                    font.family: "JetBrainsMono Nerd Font"
                    font.bold: true
                    visible: false
                    opacity: 0

                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Timer {
                        id: errorTimer
                        interval: 2000
                        onTriggered: {
                            errorMsg.opacity = 0
                            passwordField.text = ""
                        }
                    }

                    onOpacityChanged: if (opacity === 0) visible = false
                }
            }
        }
    }
}
