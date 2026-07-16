import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: rootWindow

    property bool show: true
    property var shellRoot
    property var history: []
    property double now: Date.now()
    property double lastPressAt: 0
    readonly property int maxItems: 5
    readonly property int lifetimeMs: 3000
    readonly property int idleGapMs: 1200
    readonly property int maxChipsPerRow: 10

    property double heatLevel: 0.0

    property var heldMods: ({})
    property var modUsed: ({})
    readonly property var modOrder: ["Ctrl", "Shift", "Alt", "AltGr", "Super"]

    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region {}

    anchors.bottom: true
    anchors.right: true
    WlrLayershell.margins.bottom: 16
    WlrLayershell.margins.right: 16
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: show

    implicitWidth: keyColumn.implicitWidth + 40
    implicitHeight: keyColumn.implicitHeight + 32

    readonly property var codeNames: ({
        "KEY_SPACE": "Space", "KEY_ENTER": "Enter", "KEY_KPENTER": "Enter",
        "KEY_TAB": "Tab", "KEY_ESC": "Esc", "KEY_BACKSPACE": "Backspace",
        "KEY_CAPSLOCK": "Caps", "KEY_UP": "↑", "KEY_DOWN": "↓",
        "KEY_LEFT": "←", "KEY_RIGHT": "→",
        "BTN_LEFT": "LMB", "BTN_RIGHT": "RMB", "BTN_MIDDLE": "MMB",
        "BTN_SIDE": "M4", "BTN_EXTRA": "M5"
    })

    function displayName(code) {
        if (codeNames[code] !== undefined) return codeNames[code]
            var stripped = code.replace(/^KEY_|^BTN_/, "")
            return stripped.length <= 1 ? stripped : stripped.charAt(0) + stripped.slice(1).toLowerCase()
    }

    function modifierName(code) {
        if (code === "KEY_LEFTSHIFT" || code === "KEY_RIGHTSHIFT") return "Shift"
            if (code === "KEY_LEFTCTRL" || code === "KEY_RIGHTCTRL") return "Ctrl"
                if (code === "KEY_LEFTALT") return "Alt"
                    if (code === "KEY_RIGHTALT") return "AltGr"
                        if (code === "KEY_LEFTMETA" || code === "KEY_RIGHTMETA") return "Super"
                            return ""
    }

    signal enterTriggered()

    /* [EXPLANATION] SEQUENCE DETECTION
     *      Checks if the last 4 inputs in the row match 's', 'u', 'd', 'o' sequentially.
     *      Returns true if a full match is detected.
     */
    function checkSudoMatch(chipsArray) {
        if (chipsArray.length < 4) return false;
        var len = chipsArray.length;
        var c1 = chipsArray[len-4].text.toLowerCase();
        var c2 = chipsArray[len-3].text.toLowerCase();
        var c3 = chipsArray[len-2].text.toLowerCase();
        var c4 = chipsArray[len-1].text.toLowerCase();
        return (c1 === "s" && c2 === "u" && c3 === "d" && c4 === "o");
    }

    function pushEntry(text) {
        var pressTime = Date.now()

        if (lastPressAt > 0) {
            var diff = pressTime - lastPressAt
            if (diff < 400) {
                rootWindow.heatLevel = Math.min(1.0, rootWindow.heatLevel + 0.05)
            } else if (diff > 1800) {
                rootWindow.heatLevel = Math.max(0.0, rootWindow.heatLevel - 0.25)
            }
        }

        var finalFormatText = (text === "Enter") ? "ENTER ·" : text
        var snapshotHeat = rootWindow.heatLevel

        if (text === "Enter") {
            var arrEnter = history.slice()
            if (arrEnter.length > 0 && !arrEnter[arrEnter.length - 1].sealed) {
                var lastRow = arrEnter[arrEnter.length - 1]
                arrEnter[arrEnter.length - 1] = {
                    chips: lastRow.chips.concat([{ text: finalFormatText, heat: snapshotHeat, isEnter: true, isSudo: false }]),
                    until: pressTime + lifetimeMs,
                    sealed: true
                }
                history = arrEnter
            } else {
                var newEnterRow = history.concat([{ chips: [{ text: finalFormatText, heat: snapshotHeat, isEnter: true, isSudo: false }], until: pressTime + lifetimeMs, sealed: true }])
                if (newEnterRow.length > maxItems) newEnterRow = newEnterRow.slice(newEnterRow.length - maxItems)
                    history = newEnterRow
            }
            lastPressAt = 0
            rootWindow.enterTriggered()
            return
        }

        var canJoinRow = history.length > 0
        && !history[history.length - 1].sealed
        && (pressTime - lastPressAt) < idleGapMs
        && history[history.length - 1].chips.length < maxChipsPerRow

        if (canJoinRow) {
            var arr = history.slice()
            var currentSec = arr[arr.length - 1]
            var updatedChips = currentSec.chips.concat([{ text: finalFormatText, heat: snapshotHeat, isEnter: false, isSudo: false }])

            /* [EXPLANATION] ARRAY COMPACTION / MERGING LOGIC
             *              If 'sudo' is detected, we strip the last 4 individual elements ('s','u','d','o')
             *              using splice(), and push a single consolidated "SUDO" object into the array.
             */
            if (checkSudoMatch(updatedChips)) {
                updatedChips.splice(updatedChips.length - 4, 4);
                updatedChips.push({ text: "ＳＵＤＯ", heat: snapshotHeat, isEnter: false, isSudo: true });
            }

            arr[arr.length - 1] = { chips: updatedChips, until: pressTime + lifetimeMs, sealed: false }
            history = arr
        } else {
            var arr2 = history.concat([{ chips: [{ text: finalFormatText, heat: snapshotHeat, isEnter: false, isSudo: false }], until: pressTime + lifetimeMs, sealed: false }])
            if (arr2.length > maxItems) arr2 = arr2.slice(arr2.length - maxItems)
                history = arr2
        }
        lastPressAt = pressTime
    }

    function parseLine(line) {
        var m = line.match(/(KEYBOARD_KEY|POINTER_BUTTON)\s+\+[\d.]+s\s+([A-Za-z0-9_]+)\s+\(\d+\)\s+(pressed|released)/)
        if (!m) return
            var code = m[2]
            var pressed = m[3] === "pressed"
            var modName = modifierName(code)

            if (modName !== "") {
                if (pressed) {
                    heldMods[modName] = true
                    modUsed[modName] = false
                } else {
                    if (heldMods[modName] && !modUsed[modName]) pushEntry(modName)
                        delete heldMods[modName]
                        delete modUsed[modName]
                }
                return
            }

            if (!pressed) return
                var mods = modOrder.filter(n => heldMods[n])
                mods.forEach(n => modUsed[n] = true)
                pushEntry(mods.concat([displayName(code)]).join("+"))
    }

    Process {
        id: inputWatcher
        command: ["libinput", "debug-events", "--show-keycodes"]
        running: true
        stdout: SplitParser {
            onRead: data => rootWindow.parseLine(data)
        }
        onExited: restartTimer.start()
    }

    Timer {
        id: restartTimer
        interval: 1000
        onTriggered: inputWatcher.running = true
    }

    Timer {
        interval: 60
        running: true
        repeat: true
        onTriggered: {
            rootWindow.now = Date.now()
            var arr = rootWindow.history.filter(e => e.until > rootWindow.now)
            if (arr.length !== rootWindow.history.length) rootWindow.history = arr

                if (Date.now() - rootWindow.lastPressAt > 1000 && rootWindow.heatLevel > 0) {
                    rootWindow.heatLevel = Math.max(0.0, rootWindow.heatLevel - 0.015)
                }
        }
    }

    onShowChanged: {
        toast.visible = true
        toastTimer.restart()
    }

    Timer {
        id: toastTimer
        interval: 1400
        onTriggered: toast.visible = false
    }

    PanelWindow {
        id: toast
        visible: false
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.layer: WlrLayer.Overlay
        mask: Region {}
        anchors.top: true
        anchors.left: true
        anchors.right: true
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        implicitHeight: 120

        Rectangle {
            id: toastCard
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 48
            radius: 0
            height: 48
            width: toastRow.implicitWidth + 32
            color: Qt.rgba(0.12, 0.12, 0.16, 0.55)
            border.color: Qt.rgba(1, 0.42, 0, 0.5)
            border.width: 1
            opacity: toast.visible ? 1 : 0
            scale: toast.visible ? 1 : 0.85
            Behavior on opacity { NumberAnimation { duration: 150 } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.10) }
                    GradientStop { position: 0.6; color: Qt.rgba(1, 1, 1, 0.0) }
                }
            }

            Rectangle {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                width: 3
                radius: 0
                color: shellRoot ? shellRoot.colAccent : "#FF6A00"
                opacity: 0.9
            }

            Row {
                id: toastRow
                anchors.centerIn: parent
                spacing: 10
                Rectangle {
                    width: 10; height: 10; radius: 5
                    anchors.verticalCenter: parent.verticalCenter
                    color: rootWindow.show ? (shellRoot ? shellRoot.colAccent : "#FF6A00") : Qt.rgba(1, 1, 1, 0.3)
                }
                Text {
                    text: rootWindow.show ? "Key Overlay On" : "Key Overlay Off"
                    color: shellRoot ? shellRoot.colFg : "#fff"
                    font.family: shellRoot ? shellRoot.fontFamily : "monospace"
                    font.pixelSize: 14
                    font.bold: true
                }
            }
        }
    }

    ColumnLayout {
        id: keyColumn
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        spacing: 12

        Repeater {
            model: rootWindow.history

            delegate: Row {
                id: rowItem
                required property var modelData
                Layout.alignment: Qt.AlignRight
                spacing: 4
                opacity: Math.max(0, Math.min(1, (rowItem.modelData.until - rootWindow.now) / 400))
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Connections {
                    target: rootWindow
                    function onEnterTriggered() {
                        if (rowItem.index === (rootWindow.history.length - 1)) {
                            bounceAnim.restart()
                        }
                    }
                }

                SequentialAnimation {
                    id: bounceAnim
                    readonly property int jumpDistance: -8
                    NumberAnimation { target: rowItem; property: "y"; to: bounceAnim.jumpDistance; duration: 60; easing.type: Easing.OutQuad }
                    NumberAnimation { target: rowItem; property: "y"; to: 0; duration: 140; easing.type: Easing.OutBounce }
                }

                Repeater {
                    model: rowItem.modelData.chips

                    delegate: Rectangle {
                        id: chip
                        required property var modelData

                        radius: chip.modelData.isSudo ? 2 : 0

                        height: chip.modelData.isSudo ? 43 : 36

                        width: Math.max(36, label.implicitWidth + (chip.modelData.isSudo ? 32 : 22))

                        /* [EXPLANATION] CUSTOM STYLING BY PROPERTY
                         *                          Using the conditional ternary operator (condition ? ifTrue : ifFalse)
                         *                          allows us to swap colors immediately for specific custom keywords.
                         */
                        color: chip.modelData.isSudo ? Qt.rgba(0.18, 0.14, 0.02, 0.55) : Qt.rgba(
                            0.14 + (chip.modelData.heat * 0.20),
                                                                                                 0.09 - (chip.modelData.heat * 0.04),
                                                                                                 0.04,
                                                                                                 0.5
                        )

                        border.color: chip.modelData.isSudo ? Qt.rgba(1.0, 0.85, 0.15, 0.85) : Qt.rgba(
                            1.0,
                            0.42 - (chip.modelData.heat * 0.42),
                                                                                                       0,
                                                                                                       0.5
                        )
                        border.width: chip.modelData.isSudo ? 1.5 : 1

                        scale: 0.8
                        opacity: 0
                        Component.onCompleted: {
                            scale = 1;
                            opacity = 1;
                            if (chip.modelData.isEnter) {
                                shockwaveAnim.start();
                            }
                            /* [EXPLANATION] TRIGGERING UNIQUE EFFECTS
                             *                              When the combined component mounts, we check its type flag
                             *                              and initiate the ultra-fast scale animation.
                             */
                            if (chip.modelData.isSudo) {
                                sudoShockwaveAnim.start();
                            }
                        }
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            gradient: Gradient {
                                GradientStop {
                                    position: 0.0;
                                    color: chip.modelData.isSudo ? Qt.rgba(1.0, 0.88, 0.5, 0.18) : Qt.rgba(1, 1, 1, 0.10)
                                }
                                GradientStop {
                                    position: 0.6;
                                    color: Qt.rgba(1, 1, 1, 0.0)
                                }
                            }
                        }

                        Rectangle {
                            id: shockwave
                            anchors.centerIn: parent
                            width: parent.width
                            height: parent.height
                            radius: parent.radius
                            color: "transparent"
                            border.color: shellRoot ? shellRoot.colAccent : "#FF6A00"
                            border.width: 2
                            visible: chip.modelData.isEnter
                            opacity: 0
                            scale: 1.0

                            ParallelAnimation {
                                id: shockwaveAnim
                                NumberAnimation { target: shockwave; property: "scale"; from: 1.0; to: 1.4; duration: 300; easing.type: Easing.OutCubic }
                                NumberAnimation { target: shockwave; property: "opacity"; from: 0.8; to: 0.0; duration: 300; easing.type: Easing.OutCubic }
                            }
                        }

                        /* [EXPLANATION] EXPANDING SHOCKWAVE EFFECT
                         *                          An overlay border container that scales up rapidly from 1.0 to 1.6
                         *                          while dropping opacity to 0 to simulate an outward explosive wave.
                         */
                        Rectangle {
                            id: sudoShockwave
                            anchors.centerIn: parent
                            width: parent.width
                            height: parent.height
                            radius: parent.radius
                            color: "transparent"
                            border.color: "#FFD700"
                            border.width: 2.5
                            visible: chip.modelData.isSudo
                            opacity: 0
                            scale: 1.0

                            ParallelAnimation {
                                id: sudoShockwaveAnim
                                NumberAnimation { target: sudoShockwave; property: "scale"; from: 1.0; to: 1.6; duration: 130; easing.type: Easing.OutQuad }
                                NumberAnimation { target: sudoShockwave; property: "opacity"; from: 1.0; to: 0.0; duration: 130; easing.type: Easing.OutQuad }
                            }
                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            width: 3
                            radius: 0

                            color: {
                                if (chip.modelData.isSudo) return "#FFD700";
                                var defaultColor = shellRoot ? shellRoot.colAccent : "#FF6A00";
                                if (chip.modelData.heat <= 0.05) {
                                    return defaultColor;
                                } else {
                                    return Qt.rgba(
                                        Math.min(1.0, chip.modelData.heat * 1.2),
                                                   Math.max(0.0, 0.48 - (chip.modelData.heat * 0.48)),
                                                   Math.max(0.0, 1.00 - (chip.modelData.heat * 1.00)),
                                                   0.75
                                    );
                                }
                            }
                        }

                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: chip.modelData.text
                            color: chip.modelData.isSudo ? "#FFD700" : (shellRoot ? shellRoot.colFg : "#ffffff")
                            font.family: shellRoot ? shellRoot.fontFamily : "monospace"

                            font.pixelSize: chip.modelData.isSudo ? 16 : 13
                            font.bold: true
                        }
                    }
                }
            }
        }
    }
}
