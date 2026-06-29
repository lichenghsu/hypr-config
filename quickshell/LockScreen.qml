import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

Scope {
    id: lockRoot
    property bool active: false
    property bool authFailed: false

    readonly property string matrixChars: "ｦｱｼﾝｲｳｴｵｶｷｸｹｺｻｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝｳﾞｰ･0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!@#$%&*()-+=[]{}|;:,./<>?♀αΦζ♀∞β㏒±∩"
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
                    ctx.font = "bold " + lockRoot.atlasCharH + "px 'MS Gothic', 'IPAGothic', 'IPA Gothic', monospace"
                    ctx.textBaseline = "top"
                    var chars = lockRoot.matrixChars
                    var cW = lockRoot.atlasCharW, cH = lockRoot.atlasCharH
                    var colors = ["#ffffff", "#00cc44", "#007722", "#003311"]
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

                // ── Matrix Glitch Clock with Easter Egg Quotes ───────────────────────────
                Text {
                    id: clockText
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: 72
                    font.family: "Share Tech Mono"

                    property var now: new Date()
                    property bool glowTrigger: false
                    property bool glitchActive: false

                    text: glitchActive ? getGlitchedContent() : Qt.formatTime(now, "hh:mm:ss")

                    color: lockRoot.authFailed
                    ? "#ff3333"
                    : (glowTrigger ? "#ffffff" : "#00ff41")

                    function getGlitchedContent() {
                        if (Math.random() < 0.15) {
                            var quotes = [
                                "Wake up.",
                                "Knock...",
                                "Matrix..",
                                "The One.",
                                "Red Pill",
                                "BluePill",
                                "RealWorld"
                            ];
                            var randomQuote = quotes[Math.floor(Math.random() * quotes.length)];

                            while (randomQuote.length < 8) {
                                if (Math.random() < 0.5) randomQuote = " " + randomQuote;
                                else randomQuote = randomQuote + " ";
                            }
                            return randomQuote;
                        }

                        var normalTime = Qt.formatTime(now, "hh:mm:ss");
                        var result = "";
                        var pool = lockRoot.matrixChars;

                        for (var i = 0; i < normalTime.length; i++) {
                            if (normalTime[i] === ':') {
                                result += ':';
                            } else {
                                if (Math.random() < 0.40) {
                                    result += pool[Math.floor(Math.random() * pool.length)];
                                } else {
                                    result += normalTime[i];
                                }
                            }
                        }
                        return result;
                    }

                    SequentialAnimation on opacity {
                        running: lockRoot.active && !lockRoot.authFailed
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.8; duration: 40; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1.0; duration: 30 }
                        NumberAnimation { to: 0.88; duration: 50 }
                        NumberAnimation { to: 1.0; duration: 70 }
                        PauseAnimation  { duration: 1800 }
                    }

                    Timer {
                        interval: Math.random() * 400 + 100
                        running: lockRoot.active && !lockRoot.authFailed
                        repeat: true
                        onTriggered: {
                            clockText.glowTrigger = (Math.random() < 0.12)
                            interval = Math.random() * 400 + 100
                        }
                    }

                    Timer {
                        interval: 1000
                        running: lockRoot.active
                        repeat: true
                        onTriggered: clockText.now = new Date()
                    }

                    Timer {
                        id: glitchTimer
                        interval: Math.random() * 1200 + 300
                        running: lockRoot.active
                        repeat: true
                        onTriggered: {
                            clockText.glitchActive = (Math.random() < 0.15);

                            if (clockText.glitchActive) {
                                glitchTimer.interval = Math.random() * 100 + 150;
                            } else {
                                glitchTimer.interval = Math.random() * 1200 + 300;
                            }
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: "#009920"
                    font.pixelSize: 14
                    font.family: "Share Tech Mono"
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

                // ── Matrix Password Terminal Box with Live Cursor ─────────────────────────
                Rectangle {
                    id: passwordBox
                    anchors.horizontalCenter: parent.horizontalCenter

                    width: 280
                    height: 40
                    color: "#22000000"
                    border.color: dotsContainer.shaking ? "#ff1133" : "#00ff41"
                    border.width: 1
                    radius: 2

                    Behavior on border.color { ColorAnimation { duration: 80 } }

                    Item {
                        id: dotsContainer
                        anchors.centerIn: parent
                        width: parent.width - 20
                        height: parent.height

                        property bool shaking: false
                        property int glitchSeed: 0
                        property bool cursorBlink: true

                        onShakingChanged: {
                            if (shaking) {
                                dotsGlitchTimer.tickCount = 0
                                dotsGlitchTimer.start()
                            }
                        }

                        Text {
                            id: authText
                            anchors.centerIn: parent
                            visible: pAuth.running
                            text: "AUTHENTICATING..."
                            color: "#00cc44"
                            opacity: pAuth.running ? (Math.random() * 0.3 + 0.7) : 1.0
                            font.pixelSize: 13
                            font.family: "'Share Tech Mono', 'Courier New', 'JetBrainsMono Nerd Font', monospace"
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            visible: !pAuth.running

                            Repeater {
                                model: Math.min(passwordField.text.length, 24)

                                Text {
                                    font.family: "Share Tech Mono"
                                    font.pixelSize: 16
                                    font.bold: true

                                    text: dotsContainer.shaking && ((Math.sin(index + dotsContainer.glitchSeed) + 1) / 2 < 0.65)
                                    ? lockRoot.matrixChars[Math.floor((Math.sin(index * 45.67 + dotsContainer.glitchSeed) + 1) / 2 * lockRoot.matrixChars.length)]
                                    : "■"

                                    color: dotsContainer.shaking ? "#ff1133" : "#00ff41"
                                    Behavior on color { ColorAnimation { duration: 60 } }
                                }
                            }

                            Text {
                                font.family: "Share Tech Mono"
                                font.pixelSize: 16
                                font.bold: true

                                text: dotsContainer.shaking
                                ? lockRoot.matrixChars[Math.floor(Math.random() * lockRoot.matrixChars.length)]
                                : (dotsContainer.cursorBlink ? "█" : " ")

                                color: dotsContainer.shaking ? "#ff1133" : (dotsContainer.cursorBlink ? "#ffffff" : "transparent")

                                visible: passwordField.text.length < 24
                            }
                        }

                        Timer {
                            id: cursorTimer
                            interval: Math.random() * 400 + 100
                            running: lockRoot.active && !pAuth.running
                            repeat: true
                            onTriggered: {
                                dotsContainer.cursorBlink = !dotsContainer.cursorBlink
                                cursorTimer.interval = Math.random() * 400 + 100 // 每次重新隨機化頻率
                            }
                        }

                        Timer {
                            id: dotsGlitchTimer
                            interval: 50
                            repeat: true
                            running: false
                            property int tickCount: 0

                            onTriggered: {
                                tickCount++
                                if (tickCount >= 8) {
                                    dotsGlitchTimer.stop()
                                    dotsContainer.shaking = false
                                    dotsContainer.glitchSeed = 0
                                    dotsContainer.cursorBlink = true
                                } else {
                                    dotsContainer.glitchSeed = Math.floor(Math.random() * 10000)
                                }
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
                    font.pixelSize: 14 // 稍微放大一點更清晰
                    font.family: "Share Tech Mono"
                    font.bold: true

                    text: glitchActive ? getGlitchedError() : currentText

                    property string targetText: "SYSTEM ERROR: ACCESS DENIED"
                    property string currentText: "SYSTEM ERROR: ACCESS DENIED"
                    property bool glitchActive: false

                    color: "#ff1133"

                    visible: lockRoot.authFailed
                    opacity: lockRoot.authFailed ? 1.0 : 0.0

                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    function getGlitchedError() {
                        var result = "";
                        var pool = lockRoot.matrixChars;
                        for (var i = 0; i < targetText.length; i++) {
                            if (targetText[i] === ' ' || targetText[i] === ':') {
                                result += targetText[i];
                            } else {
                                result += (Math.random() < 0.5)
                                ? pool[Math.floor(Math.random() * pool.length)]
                                : targetText[i];
                            }
                        }
                        return result;
                    }

                    Timer {
                        id: decryptTimer
                        interval: 40
                        repeat: true
                        running: lockRoot.authFailed

                        property int tickCount: 0

                        onTriggered: {
                            tickCount++
                            if (tickCount < 8) {
                                errorMsg.glitchActive = true
                            } else if (tickCount === 8) {
                                errorMsg.glitchActive = false
                            } else if (tickCount > 45) {
                                errorMsg.glitchActive = true
                            }
                        }
                    }

                    Timer {
                        id: errorTimer
                        interval: 2200
                        running: lockRoot.authFailed
                        repeat: false
                        onTriggered: {
                            decryptTimer.tickCount = 0
                            errorMsg.glitchActive = false
                            lockRoot.authFailed = false
                            if (typeof passwordField !== "undefined") passwordField.text = ""
                        }
                    }

                    onOpacityChanged: if (opacity === 0) visible = false
                }
            }
        }
    }
}
