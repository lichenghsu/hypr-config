import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

Scope {
    id: lockRoot
    property bool active: false
    property bool preLockActive: false
    property bool authFailed: false
    property bool authSuccess: false
    property bool intrusionActive: false
    property int  intrusionPhase: 0
    property bool errorVisible: false

    readonly property string matrixChars: "ｦｱｼﾝｲｳｴｵｶｷｸｹｺｻｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝｳﾞｰ･0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!@#$%&*()-+=[]{}|;:,./<>?♀αΦζ♀∞β㏒±∩"
    readonly property int atlasCharW: 14
    readonly property int atlasCharH: 18

    function activate() {
        lockRoot.authFailed = false
        lockRoot.authSuccess = false
        lockRoot.intrusionActive = false
        lockRoot.intrusionPhase = 0
        lockRoot.preLockActive = true
        lockRoot.errorVisible = false
        successUnlockTimer.stop()
        preLockTimer.start()
        pSubmap.running = true
    }

    function deactivate() {
        lockRoot.active = false
        lockRoot.preLockActive = false
        lockRoot.authFailed = false
        lockRoot.authSuccess = false
        lockRoot.errorVisible = false
        pReset.running = true
    }

    function submitPassword(pw) {
        if (pw.length === 0 || pAuth.running || lockRoot.authSuccess) return
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

    Timer {
        id: successUnlockTimer
        interval: 2600
        running: false
        repeat: false
        onTriggered: {
            lockRoot.deactivate()
        }
    }

    Process {
        id: pAuth
        property string pendingPw: ""
        command: ["/home/miles/.local/bin/lock-auth.sh"]
        stdinEnabled: true
        onStarted: write(pAuth.pendingPw + "\n")
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                lockRoot.authSuccess = true
                successUnlockTimer.start()
            }
            else authFailTimer.start()
        }
    }

    Timer {
        id: preLockTimer
        interval: 2200
        running: false
        repeat: false
        onTriggered: {
            lockRoot.active = true
            preLockHideTimer.start()
        }
    }

    Timer {
        id: preLockHideTimer
        interval: 80
        running: false
        repeat: false
        onTriggered: lockRoot.preLockActive = false
    }

    Timer {
        id: intrusionTriggerTimer
        running: lockRoot.active && !lockRoot.authSuccess && !lockRoot.intrusionActive
        repeat: true
        onTriggered: {
            lockRoot.intrusionActive = true
            lockRoot.intrusionPhase = 0
            intrusionPhaseTimer.start()
            interval = Math.floor(Math.random() * 30000 + 22000)
        }
        Component.onCompleted: interval = Math.floor(Math.random() * 30000 + 22000)
    }

    Timer {
        id: intrusionPhaseTimer
        interval: 1400
        repeat: true
        running: false
        onTriggered: {
            lockRoot.intrusionPhase++
            if (lockRoot.intrusionPhase >= 4) {
                lockRoot.intrusionActive = false
                lockRoot.intrusionPhase = 0
                intrusionPhaseTimer.stop()
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: overlayWin
            required property var modelData
            screen: modelData

            visible: lockRoot.active || lockRoot.preLockActive
            color: "black"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: (lockRoot.active || lockRoot.preLockActive)
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

            Canvas {
                id: atlasCanvas
                visible: false
                width: lockRoot.matrixChars.length * lockRoot.atlasCharW
                height: lockRoot.atlasCharH * 4
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
                    running: lockRoot.active || lockRoot.preLockActive
                    repeat: true
                    onTriggered: parent.time += 0.033
                }
            }

            Item {
                id: preLockOverlay
                anchors.fill: parent
                z: 10
                visible: overlayWin.isPrimary && lockRoot.preLockActive

                property int tick: 0

                Timer {
                    interval: 55
                    running: lockRoot.preLockActive
                    repeat: true
                    onTriggered: preLockOverlay.tick = (preLockOverlay.tick + 1) % 10000
                }

                function mainText(t) {
                    if (t < 9) {
                        var pool = lockRoot.matrixChars
                        var r = ""
                        for (var i = 0; i < 8; i++) r += pool[Math.floor(Math.random() * pool.length)]
                        return r
                    }
                    if (t < 22) {
                        var p1 = ["LOCKDOWN", "LOCK.SYS", "ENGAGING", "SECURING", "!CORTEX!", "OVERLOAD"]
                        return p1[Math.floor(t / 3) % p1.length]
                    }
                    if (t < 33) {
                        var p2 = ["LOCKED__", "SECURE__", "ARMED___", "ENGAGED_"]
                        return p2[Math.floor(t / 2) % p2.length]
                    }
                    return "LOCKED__"
                }

                function mainColor(t) {
                    if (t < 9)  return (t % 2 === 0) ? "#ff1133" : "#ff4455"
                    if (t < 22) return (t % 3 === 0) ? "#ffaa00" : "#ff6600"
                    if (t < 33) return (t % 2 === 0) ? "#00aaff" : "#00d4ff"
                    return "#00ff41"
                }

                readonly property var statusLines: [
                    ">> CYBERWARE OVERLOAD: DETECTED",
                    ">> NEURAL LINK: DESTABILIZING",
                    ">> CORTEX ICE: FRAGMENTING",
                    ">> EMERGENCY LOCKDOWN: INITIATED",
                    ">> MAGI SECURITY PROTOCOL: ACTIVE",
                    ">> A.T. FIELD: ENGAGING",
                    ">> TERMINAL DOGMA: LOCKED",
                    ">> ALL ACCESS: REVOKED",
                    ">> SYSTEM SECURED"
                ]

                Text {
                    anchors.top: parent.top
                    anchors.topMargin: 38
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: 15
                    font.family: "Share Tech Mono"
                    font.bold: true
                    text: preLockOverlay.tick < 5 ? ""
                        : preLockOverlay.tick < 20 ? "!!  SYSTEM ALERT: LOCKDOWN INITIATED  !!"
                        : ">>  NERV SECURITY PROTOCOL: ACTIVE  <<"
                    color: preLockOverlay.tick < 20 ? "#ff1133" : "#ffcc00"
                    opacity: (preLockOverlay.tick % 3 === 0) ? 0.3 : 1.0
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 22

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.pixelSize: 96
                        font.family: "Share Tech Mono"
                        font.bold: true
                        text: preLockOverlay.mainText(preLockOverlay.tick)
                        color: preLockOverlay.mainColor(preLockOverlay.tick)
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.pixelSize: 15
                        font.family: "Share Tech Mono"
                        text: preLockOverlay.statusLines[
                            Math.min(Math.floor(preLockOverlay.tick / 4), preLockOverlay.statusLines.length - 1)
                        ]
                        color: preLockOverlay.tick < 22 ? "#ff6666" : preLockOverlay.tick < 33 ? "#88ccff" : "#00cc44"
                        opacity: 0.85
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#22ff1133"
                    visible: false
                    opacity: 0

                    SequentialAnimation {
                        running: lockRoot.preLockActive
                        loops: 1
                        PropertyAction  { target: parent; property: "visible"; value: true }
                        NumberAnimation { target: parent; property: "opacity"; to: 0.28; duration: 65 }
                        NumberAnimation { target: parent; property: "opacity"; to: 0.0;  duration: 130 }
                        NumberAnimation { target: parent; property: "opacity"; to: 0.16; duration: 65 }
                        NumberAnimation { target: parent; property: "opacity"; to: 0.0;  duration: 200 }
                        PropertyAction  { target: parent; property: "visible"; value: false }
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                visible: overlayWin.isPrimary && lockRoot.active
                spacing: 28

                onVisibleChanged: if (visible) focusTimer.start()

                Connections {
                    target: lockRoot
                    function onActiveChanged() {
                        if (lockRoot.active) {
                            passwordField.text = ""
                            clockText.now = new Date()
                            clockText.unlockTick = 0
                            clockText.unlockColor = "#00ff41"
                            clockText.glitchStreamText = ""

                            dateText.isCyberpunkGlitch = false
                            dateText.frozenGlitchText = ""
                            dateText.unlockStatusIdx = 0
                            dateText.intrusionStatusIdx = 0
                            cyberpunkFreezeTimer.stop()
                        }
                    }
                }

                Timer {
                    id: focusTimer
                    interval: 80
                    onTriggered: passwordField.forceActiveFocus()
                }

                Text {
                    id: clockText
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: 72
                    font.family: "Share Tech Mono"

                    property var now: new Date()
                    property bool glowTrigger: false
                    property bool glitchActive: false
                    property string glitchStreamText: ""
                    property int unlockTick: 0
                    property string unlockColor: "#00ff41"
                    property int intrusionTick: 0

                    text: lockRoot.authSuccess ? glitchStreamText
                        : lockRoot.intrusionActive ? getIntrusionClock(intrusionTick)
                        : (glitchActive ? getGlitchedContent() : Qt.formatTime(now, "hh:mm:ss"))

                    color: lockRoot.authSuccess ? unlockColor
                        : lockRoot.intrusionActive ? intrusionClockColor(intrusionTick)
                        : (lockRoot.authFailed ? "#ff3333" : (glowTrigger ? "#ffffff" : "#00ff41"))

                    function getIntrusionClock(tick) {
                        var p = lockRoot.intrusionPhase
                        if (p === 0) {
                            var alert = ["INTRUDR.", "HACKIN_!", "ALERT!!!", "BREACH!!", "!!!!!!!!!", "!!ERROR!", "INVADE__"]
                            return alert[Math.floor(Math.random() * alert.length)]
                        } else if (p === 1) {
                            var breach = ["ICE:BRKE", "CRACKING", "WALL_DWN", "FW:DOWN.", "BURN_ICE", "NET_BURN", "FLATLINE"]
                            return breach[Math.floor(Math.random() * breach.length)]
                        } else if (p === 2) {
                            var counter = ["COUNTER.", "MAGI_DEF", "ICE:HOLD", "TRACE___", "SCORPION", "BLOCK_OK", "DAEMON__"]
                            return counter[Math.floor(Math.random() * counter.length)]
                        } else {
                            var resolve = ["BLOCKED.", "SEVERED.", "SAFE____", "CLEAN___", "SECURE_.", "GHOST___"]
                            return resolve[Math.floor(Math.random() * resolve.length)]
                        }
                    }

                    function intrusionClockColor(tick) {
                        var p = lockRoot.intrusionPhase
                        if (p === 0) return (tick % 2 === 0) ? "#ff1133" : "#ff4455"
                        if (p === 1) return (tick % 3 === 0) ? "#ff8800" : "#ff6600"
                        if (p === 2) return (tick % 2 === 0) ? "#ffcc00" : "#ffdd44"
                        return "#00ff41"
                    }

                    function getUnlockMatrixStream() {
                        var unlockQuotes = [
                            "SYSTEM..", "BYPASS..", "OVERRIDE", "KNOCK___",
                            "NEO_ONE_", "SUCCEED.", "01010101", "FREE_MND", "ACCESS__"
                        ];
                        return unlockQuotes[Math.floor(Math.random() * unlockQuotes.length)];
                    }

                    function getGlitchedContent() {
                        if (Math.random() < 0.15) {
                            var quotes = ["Wake up.", "Knock...", "Matrix..", "The One.", "Red Pill", "BluePill", "RealWorld"];
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
                            if (normalTime[i] === ':') result += ':';
                            else {
                                result += (Math.random() < 0.40) ? pool[Math.floor(Math.random() * pool.length)] : normalTime[i];
                            }
                        }
                        return result;
                    }

                    SequentialAnimation on opacity {
                        running: lockRoot.active && !lockRoot.authFailed && !lockRoot.authSuccess
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.8; duration: 40; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 1.0; duration: 30 }
                        NumberAnimation { to: 0.88; duration: 50 }
                        NumberAnimation { to: 1.0; duration: 70 }
                        PauseAnimation  { duration: 1800 }
                    }

                    Timer {
                        interval: 75
                        running: lockRoot.intrusionActive && lockRoot.active
                        repeat: true
                        onTriggered: clockText.intrusionTick = (clockText.intrusionTick + 1) % 1000
                    }

                    Timer {
                        id: unlockGlitchTimer
                        interval: 60
                        running: lockRoot.authSuccess && lockRoot.active
                        repeat: true
                        onTriggered: {
                            clockText.unlockTick++
                            var t = clockText.unlockTick
                            var r = Math.random()

                            if (t <= 10) {
                                var matrixPool = ["SYSTEM..", "BYPASS..", "OVERRIDE", "KNOCK___",
                                    "NEO_ONE_", "01010101", "FREE_MND", "ACCESS__",
                                    "INIT....", "LOAD_SYS", "DAT4_RUN", "EXEC_CTL"]
                                clockText.glitchStreamText = matrixPool[Math.floor(r * matrixPool.length)]
                                clockText.unlockColor = "#00ff41"
                            } else if (t <= 22) {
                                if (r < 0.18) {
                                    clockText.glitchStreamText = clockText.getUnlockMatrixStream()
                                    clockText.unlockColor = "#00ff41"
                                } else {
                                    var cp = ["BREACH..", "PROTOCOL", "ICE_MELT", "JACK_IN.",
                                        "NETRUN__", "SYNC:400", "ICE:BRKE", "NET.DIVE",
                                        "DAEMON__", "SHARD_OK", "CHIP:HOT", "FLATLINE."]
                                    clockText.glitchStreamText = cp[Math.floor(Math.random() * cp.length)]
                                    clockText.unlockColor = r < 0.35 ? "#ffaa00" : "#ff6600"
                                }
                            } else if (t <= 36) {
                                if (r < 0.10) {
                                    clockText.glitchStreamText = clockText.getUnlockMatrixStream()
                                    clockText.unlockColor = "#00ff41"
                                } else if (r < 0.20) {
                                    var cp2 = ["NETRUN__", "DAEMON__", "JACK_IN.", "SHARD_OK"]
                                    clockText.glitchStreamText = cp2[Math.floor(Math.random() * cp2.length)]
                                    clockText.unlockColor = "#ff6600"
                                } else {
                                    var eva = ["[==>   ]", "[====> ]", "[======]", "UNIT-01.",
                                        "MAGI-SYS", "A.T.OFF.", "SYNC:MAX", "LCL:NORM",
                                        "PILOT_ID", "NERV_OK.", "BRSRKR_.", "EVA:WAKE"]
                                    clockText.glitchStreamText = eva[Math.floor(Math.random() * eva.length)]
                                    clockText.unlockColor = r < 0.4 ? "#00aaff" : "#00d4ff"
                                }
                            } else {
                                if (r < 0.07) {
                                    clockText.glitchStreamText = clockText.getUnlockMatrixStream()
                                    clockText.unlockColor = "#00ff41"
                                } else {
                                    var fin = ["WELCOME.", "PILOT_OK", "INIT:100", "SYNC_100", "UNIT_ONL", "FREE____"]
                                    clockText.glitchStreamText = fin[Math.floor(Math.random() * fin.length)]
                                    clockText.unlockColor = "#ffffff"
                                }
                            }

                            unlockGlitchTimer.interval = Math.floor(Math.random() * 60 + 35)
                        }
                    }

                    Timer {
                        interval: Math.random() * 400 + 100
                        running: lockRoot.active && !lockRoot.authFailed && !lockRoot.authSuccess
                        repeat: true
                        onTriggered: {
                            clockText.glowTrigger = (Math.random() < 0.12)
                            interval = Math.random() * 400 + 100
                        }
                    }

                    Timer {
                        interval: 1000
                        running: lockRoot.active && !lockRoot.authSuccess
                        repeat: true
                        onTriggered: clockText.now = new Date()
                    }

                    Timer {
                        id: glitchTimer
                        interval: Math.random() * 1200 + 300
                        running: lockRoot.active && !lockRoot.authSuccess
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
                    id: dateText
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: 14
                    font.family: "Share Tech Mono"

                    property bool isCyberpunkGlitch: false
                    property string frozenGlitchText: ""
                    property int unlockStatusIdx: 0
                    property int intrusionStatusIdx: 0
                    readonly property var intrusionMessages: [
                        ">> UNAUTHORIZED ACCESS: DETECTED",
                        ">> SOURCE: BLACKWALL PROXY // UNKNOWN",
                        ">> NETRUNNER SIGNATURE: ACTIVE",
                        ">> ICE LAYER 1: COMPROMISED",
                        ">> FIREWALL: CRACKING",
                        ">> EMERGENCY PROTOCOL: INITIATED",
                        ">> MAGI COUNTER-ICE: DEPLOYED",
                        ">> SCORPION DAEMON: ACTIVE",
                        ">> INTRUSION VECTOR: TRACED",
                        ">> CONNECTION: SEVERING...",
                        ">> NETRUNNER: FLATLINED",
                        ">> MAGI INTEGRITY: RESTORED"
                    ]
                    readonly property var unlockStatusMessages: [
                        ">> BREACH PROTOCOL: INITIATED",
                        ">> SCANNING NEURAL LINK...",
                        ">> ICE BARRIER: DISSOLVING",
                        ">> NETWATCH COUNTERMEASURE: BYPASSED",
                        ">> MAGI-01: PATTERN BLUE  [OK]",
                        ">> MAGI-02: PATTERN BLUE  [OK]",
                        ">> MAGI-03: PATTERN BLUE  [OK]",
                        ">> MAJORITY VOTE: AUTHORIZED",
                        ">> A.T. FIELD: FULLY COLLAPSED",
                        ">> LCL PRESSURE: NOMINAL",
                        ">> PILOT SYNC RATE: 400%",
                        ">> BERSERKER MODE: SUPPRESSED",
                        ">> NERV CENTRAL DOGMA: ONLINE",
                        ">> EVANGELION UNIT-01: ACTIVE",
                        ">> WELCOME BACK, THIRD CHILD."
                    ]

                    text: lockRoot.authSuccess
                        ? unlockStatusMessages[Math.min(unlockStatusIdx, unlockStatusMessages.length - 1)]
                        : lockRoot.intrusionActive
                        ? intrusionMessages[Math.min(intrusionStatusIdx, intrusionMessages.length - 1)]
                        : (isCyberpunkGlitch ? frozenGlitchText : (clockText.glitchActive ? getGlitchedDate() : Qt.formatDate(clockText.now, "dddd, MMMM d, yyyy")))

                    color: lockRoot.authSuccess ? clockText.unlockColor
                        : lockRoot.intrusionActive
                        ? (lockRoot.intrusionPhase === 0 ? "#ff1133"
                           : lockRoot.intrusionPhase === 1 ? "#ff6600"
                           : lockRoot.intrusionPhase === 2 ? "#ffcc00" : "#00ff41")
                        : (lockRoot.authFailed ? "#ff3333" : (isCyberpunkGlitch ? "#fcee0a" : (clockText.glowTrigger ? "#ffffff" : "#009920")))

                    Timer {
                        id: cyberpunkFreezeTimer
                        interval: 1800
                        repeat: false
                        onTriggered: { dateText.isCyberpunkGlitch = false; }
                    }

                    Timer {
                        id: unlockStatusTimer
                        interval: 160
                        running: lockRoot.authSuccess && lockRoot.active
                        repeat: true
                        onTriggered: {
                            if (dateText.unlockStatusIdx < dateText.unlockStatusMessages.length - 1)
                                dateText.unlockStatusIdx++
                        }
                    }

                    Timer {
                        id: intrusionStatusTimer
                        interval: 370
                        running: lockRoot.intrusionActive && lockRoot.active
                        repeat: true
                        onTriggered: {
                            if (dateText.intrusionStatusIdx < dateText.intrusionMessages.length - 1)
                                dateText.intrusionStatusIdx++
                        }
                    }

                    function getGlitchedDate() {
                        if (isCyberpunkGlitch) return frozenGlitchText;
                        if (Math.random() < 0.20) {
                            isCyberpunkGlitch = true;
                            var brokenDays = ["NIGHT_CITY", "SYSTEM_ERR//", "░N░U░L░L░", "CORE_PANIC", "GHOST_IN_SYS", "0x7F_GHOST", "⚠️_OVERFLOW"];
                            var fakeDay = brokenDays[Math.floor(Math.random() * brokenDays.length)];
                            var brokenMonths = ["0xFA_SECTOR", "█▍BAD_ICE", "NET_OVERRIDE", "NETWATCH_ERR", "NEO_TOKYO_//", "FXXK_CORP_SYS", "CRIT_DATA"];
                            var fakeMonth = Math.random() < 0.5 ? brokenMonths[Math.floor(Math.random() * brokenMonths.length)] : Qt.formatDate(clockText.now, "MMM");
                            var realDayNum = Qt.formatDate(clockText.now, "d");
                            var fakeDayNum = Math.random() < 0.5 ? realDayNum : ["0x" + parseInt(realDayNum).toString(16).toUpperCase(), "NaN", "Ø", "##"][Math.floor(Math.random() * 4)];
                            var fakeYear = ["2077", "2077//", "[2077]", "0x081D", "20XX"][Math.floor(Math.random() * 5)];
                            frozenGlitchText = fakeDay + ", " + fakeMonth + " " + fakeDayNum + ", " + fakeYear;
                            cyberpunkFreezeTimer.restart();
                            return frozenGlitchText;
                        }
                        if (Math.random() < 0.12) {
                            var systemAlerts = ["⚠️ SYSTEM FAILURE ⚠️", "► DETECT_INTRUSION: 403", "// OVERRIDE_ACTIVATED //", "▒▒ ERR_DATA_CORRUPT ▒▒", " [ ACCESS_DENIED ] "];
                            return systemAlerts[Math.floor(Math.random() * systemAlerts.length)];
                        }
                        var normalDate = Qt.formatDate(clockText.now, "dddd, MMMM d, yyyy");
                        var result = "";
                        var pool = lockRoot.matrixChars;
                        for (var i = 0; i < normalDate.length; i++) {
                            if (normalDate[i] === ' ' || normalDate[i] === ',') result += normalDate[i];
                            else {
                                result += (Math.random() < 0.35) ? pool[Math.floor(Math.random() * pool.length)] : normalDate[i];
                            }
                        }
                        return result;
                    }
                }

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

                Rectangle {
                    id: passwordBox
                    anchors.horizontalCenter: parent.horizontalCenter

                    width: lockRoot.authSuccess ? 500 : 280
                    height: 40
                    opacity: lockRoot.authSuccess ? 0.0 : 1.0
                    color: "#22000000"

                    border.color: lockRoot.authSuccess ? "#ffffff" : (dotsContainer.shaking ? "#ff1133" : "#00ff41")
                    border.width: lockRoot.authSuccess ? 3 : 1
                    radius: 2

                    Behavior on border.color { ColorAnimation { duration: 80 } }
                    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.InBack } }
                    Behavior on opacity { NumberAnimation { duration: 500 } }

                    Item {
                        id: dotsContainer
                        clip: true
                        anchors.centerIn: parent
                        width: parent.width - 28
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
                            visible: pAuth.running || lockRoot.authSuccess
                            text: lockRoot.authSuccess ? "ACCESS GRANTED [SYSTEM UNLOCKED]" : "AUTHENTICATING..."
                            color: lockRoot.authSuccess ? "#ffffff" : "#00cc44"
                            font.bold: true
                            opacity: pAuth.running && !lockRoot.authSuccess ? (Math.random() * 0.3 + 0.7) : 1.0
                            font.pixelSize: 13
                            font.family: "'Share Tech Mono', 'Courier New', 'JetBrainsMono Nerd Font', monospace"
                        }

                        Item {
                            width: passwordRow.width
                            height: parent.height

                            anchors.centerIn: passwordRow.width < dotsContainer.width ? parent : undefined
                            anchors.right: passwordRow.width >= dotsContainer.width ? parent.right : undefined

                            Row {
                                id: passwordRow
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                visible: !pAuth.running && !lockRoot.authSuccess

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
                                    id: liveCursor
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
                        }

                        Timer {
                            id: cursorTimer
                            interval: Math.random() * 400 + 100
                            running: lockRoot.active && !pAuth.running && !lockRoot.authSuccess
                            repeat: true
                            onTriggered: {
                                dotsContainer.cursorBlink = !dotsContainer.cursorBlink
                                cursorTimer.interval = Math.random() * 400 + 100
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

                Connections {
                    target: lockRoot
                    function onAuthFailedChanged() {
                        if (!lockRoot.authFailed || !overlayWin.isPrimary) return
                        lockRoot.authFailed = false
                        dotsContainer.shaking = true
                        lockRoot.errorVisible = true
                        decryptTimer.tickCount = 0
                        errorTimer.restart()
                    }
                }

                Text {
                    id: errorMsg
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: 14
                    font.family: "Share Tech Mono"
                    font.bold: true

                    text: glitchActive ? getGlitchedError() : currentText

                    property string targetText: "SYSTEM ERROR: ACCESS DENIED"
                    property string currentText: "SYSTEM ERROR: ACCESS DENIED"
                    property bool glitchActive: false
                    color: "#ff1133"

                    visible: lockRoot.errorVisible
                    opacity: lockRoot.errorVisible ? 1.0 : 0.0

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
                        running: lockRoot.errorVisible

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
                        repeat: false
                        onTriggered: {
                            decryptTimer.tickCount = 0
                            errorMsg.glitchActive = false
                            lockRoot.errorVisible = false
                            if (typeof passwordField !== "undefined") passwordField.text = ""
                        }
                    }

                }
            }

            Column {
                visible: overlayWin.isPrimary && lockRoot.intrusionActive
                anchors.top: parent.top
                anchors.topMargin: 36
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: 17
                    font.family: "Share Tech Mono"
                    font.bold: true
                    text: lockRoot.intrusionPhase === 0 ? "!!  NETRUNNER INTRUSION DETECTED  !!"
                        : lockRoot.intrusionPhase === 1 ? "!!  FIREWALL COMPROMISED  !!"
                        : lockRoot.intrusionPhase === 2 ? ">>  MAGI COUNTER-ICE: ACTIVE  <<"
                        : "--  THREAT NEUTRALIZED  --"
                    color: lockRoot.intrusionPhase === 0 ? "#ff1133"
                        : lockRoot.intrusionPhase === 1 ? "#ff6600"
                        : lockRoot.intrusionPhase === 2 ? "#ffcc00"
                        : "#00ff41"

                    SequentialAnimation on opacity {
                        running: lockRoot.intrusionActive
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.15; duration: 90 }
                        NumberAnimation { to: 1.0;  duration: 70 }
                        PauseAnimation  { duration: lockRoot.intrusionPhase < 2 ? 80 : 300 }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: 12
                    font.family: "Share Tech Mono"
                    opacity: 0.65
                    text: lockRoot.intrusionPhase === 0 ? "// TRACING SIGNAL..."
                        : lockRoot.intrusionPhase === 1 ? "// ICE LAYERS DISSOLVING..."
                        : lockRoot.intrusionPhase === 2 ? "// SCORPION DAEMON DEPLOYED"
                        : "// CONNECTION SEVERED: 0.003ms"
                    color: lockRoot.intrusionPhase < 2 ? "#ff6666" : lockRoot.intrusionPhase === 2 ? "#ffdd88" : "#88ff99"
                }
            }

            Rectangle {
                id: intrusionFlash
                anchors.fill: parent
                color: lockRoot.intrusionPhase === 2 ? "#22ffcc00" : "#22ff1133"
                visible: false
                opacity: 0

                SequentialAnimation {
                    id: flashAnim
                    running: false
                    loops: 1
                    PropertyAction  { target: intrusionFlash; property: "visible"; value: true }
                    NumberAnimation { target: intrusionFlash; property: "opacity"; to: 0.22; duration: 70 }
                    NumberAnimation { target: intrusionFlash; property: "opacity"; to: 0.0;  duration: 140 }
                    NumberAnimation { target: intrusionFlash; property: "opacity"; to: 0.14; duration: 70 }
                    NumberAnimation { target: intrusionFlash; property: "opacity"; to: 0.0;  duration: 220 }
                    PropertyAction  { target: intrusionFlash; property: "visible"; value: false }
                }
            }

            Connections {
                target: lockRoot
                function onIntrusionActiveChanged() {
                    if (lockRoot.intrusionActive) flashAnim.start()
                }
                function onIntrusionPhaseChanged() {
                    if (lockRoot.intrusionActive && lockRoot.intrusionPhase === 2) flashAnim.start()
                }
            }
        }
    }
}
