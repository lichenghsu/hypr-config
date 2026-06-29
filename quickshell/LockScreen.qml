import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

Scope {
    id: lockRoot
    property bool active: false
    property bool authFailed: false

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

    Process {
        id: pAuth
        property string pendingPw: ""
        command: ["/home/miles/.local/bin/lock-auth.sh"]
        stdinEnabled: true
        onStarted: write(pAuth.pendingPw + "\n")
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) lockRoot.deactivate()
            else lockRoot.authFailed = true
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlayWin
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

            HoverHandler { cursorShape: Qt.BlankCursor }

            property bool isPrimary: overlayWin.modelData === (
                Quickshell.screens.find(s => !s.name.startsWith("eDP"))
                ?? Quickshell.screens[0]
            )

            // Half-resolution canvas scaled 2×: each fillText renders 4× fewer pixels
            Canvas {
                id: matrixCanvas
                width: Math.ceil(parent.width / 2)
                height: Math.ceil(parent.height / 2)
                x: 0; y: 0
                scale: 2
                transformOrigin: Item.TopLeft

                property var cols: []
                property int charW: 8
                property int charH: 9
                property string chars: "ｦｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123456789"
                property var greenPalette: {
                    var p = []
                    for (var i = 0; i < 20; i++) {
                        var g = 30 + Math.floor(180 * (i / 19))
                        p.push("rgb(0," + g + ",0)")
                    }
                    return p
                }

                function randChar() {
                    return chars[Math.floor(Math.random() * chars.length)]
                }

                function initCols() {
                    var n = Math.ceil(width / charW)
                    var h = height, cH = charH, c = []
                    for (var i = 0; i < n; i++) {
                        var len = 5 + Math.floor(Math.random() * 12)
                        var trail = []
                        for (var j = 0; j < len; j++) trail.push(randChar())
                        c.push({
                            x: i * charW,
                            y: -Math.floor(Math.random() * (h / cH)) * cH,
                            speed: 1 + Math.random(),
                            len: len,
                            trail: trail
                        })
                    }
                    cols = c
                }

                onWidthChanged: initCols()
                onHeightChanged: initCols()
                Component.onCompleted: initCols()

                onPaint: {
                    var ctx = getContext("2d")
                    var w = width, h = height, cH = charH
                    var c = cols, n = c.length
                    var pal = greenPalette, palMax = pal.length - 1

                    ctx.fillStyle = "rgba(0,0,0,0.2)"
                    ctx.fillRect(0, 0, w, h)
                    ctx.font = "bold " + cH + "px monospace"
                    ctx.textBaseline = "top"

                    for (var i = 0; i < n; i++) {
                        var col = c[i]
                        var colLen = col.len
                        var trail = col.trail
                        var colY = col.y
                        var x = col.x

                        for (var j = 0; j < colLen; j++) {
                            var y = colY - j * cH
                            if (y < -cH || y >= h) continue
                            ctx.fillStyle = j === 0 ? "#ccffcc" : pal[Math.floor(palMax * (1 - j / colLen))]
                            if (Math.random() < 0.03) trail[j] = randChar()
                            ctx.fillText(trail[j], x, y)
                        }

                        col.y += col.speed * cH
                        if (col.y - colLen * cH >= h) {
                            col.y = 0
                            col.speed = 1 + Math.random()
                            col.len = 5 + Math.floor(Math.random() * 12)
                        }
                    }
                }

                Timer {
                    interval: overlayWin.isPrimary ? 33 : 100
                    running: lockRoot.active
                    repeat: true
                    onTriggered: matrixCanvas.requestPaint()
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

                    SequentialAnimation {
                        id: shakeAnim
                        NumberAnimation { target: dotsContainer; property: "x"; to: dotsContainer.x - 10; duration: 40 }
                        NumberAnimation { target: dotsContainer; property: "x"; to: dotsContainer.x + 18; duration: 60 }
                        NumberAnimation { target: dotsContainer; property: "x"; to: dotsContainer.x - 14; duration: 50 }
                        NumberAnimation { target: dotsContainer; property: "x"; to: dotsContainer.x + 8; duration: 50 }
                        NumberAnimation { target: dotsContainer; property: "x"; to: dotsContainer.x; duration: 40 }
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
                        onTriggered: errorMsg.opacity = 0
                    }

                    onOpacityChanged: if (opacity === 0) { visible = false; passwordField.text = "" }

                    Connections {
                        target: lockRoot
                        function onAuthFailedChanged() {
                            if (lockRoot.authFailed) {
                                passwordField.text = ""
                                dotsContainer.shaking = true
                                shakeAnim.restart()
                                errorMsg.visible = true
                                errorMsg.opacity = 1
                                errorTimer.restart()
                                lockRoot.authFailed = false
                            }
                        }
                    }
                }
            }
        }
    }
}
