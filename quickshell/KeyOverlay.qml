import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Always-on overlay in the bottom-right corner showing recent key/mouse
// combos, one per row, stacking upward from the bottom. Reads raw input
// events via `libinput debug-events`, which requires the running user to
// be in the `input` group (udev grants read access to /dev/input/event*).
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

    // modifiers currently held down, and whether each was already used in a combo
    property var heldMods: ({})
    property var modUsed: ({})
    readonly property var modOrder: ["Ctrl", "Shift", "Alt", "AltGr", "Super"]

    // never take keyboard focus, never intercept the mouse
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

    // consecutive presses within idleGapMs join the same (bottom) row as separate
    // boxes; a long enough pause seals that row and starts a fresh one, pushing
    // older rows up. A single combo (e.g. Ctrl+C) is still only one box.
    function pushEntry(text) {
        var pressTime = Date.now()
        var canJoinRow = history.length > 0 && (pressTime - lastPressAt) < idleGapMs
                         && history[history.length - 1].chips.length < maxChipsPerRow
        if (canJoinRow) {
            var arr = history.slice()
            var lastRow = arr[arr.length - 1]
            arr[arr.length - 1] = { chips: lastRow.chips.concat([text]), until: pressTime + lifetimeMs }
            history = arr
        } else {
            var arr2 = history.concat([{ chips: [text], until: pressTime + lifetimeMs }])
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

    // brief top-center toast confirming the SUPER+X toggle, independent of `show`
    // so it still appears when the overlay itself is being hidden
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
            radius: 14
            height: 48
            width: toastRow.implicitWidth + 32
            color: Qt.rgba(0.12, 0.12, 0.16, 0.55)
            border.color: Qt.rgba(1, 1, 1, 0.16)
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
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width * 0.5
                height: 2
                radius: 1
                color: shellRoot ? shellRoot.colAccent : "#007AFF"
                opacity: 0.7
            }

            Row {
                id: toastRow
                anchors.centerIn: parent
                spacing: 10

                Rectangle {
                    width: 10
                    height: 10
                    radius: 5
                    anchors.verticalCenter: parent.verticalCenter
                    color: rootWindow.show ? (shellRoot ? shellRoot.colAccent : "#007AFF") : Qt.rgba(1, 1, 1, 0.3)
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
        spacing: 6

        Repeater {
            model: rootWindow.history

            // one row per burst of activity; grows to the left as chips are added,
            // right edge stays pinned via Layout.alignment
            delegate: Row {
                id: rowItem
                required property var modelData
                Layout.alignment: Qt.AlignRight
                spacing: 4
                opacity: Math.max(0, Math.min(1, (rowItem.modelData.until - rootWindow.now) / 400))

                Behavior on opacity { NumberAnimation { duration: 150 } }

                Repeater {
                    model: rowItem.modelData.chips

                    delegate: Rectangle {
                        id: chip
                        required property string modelData
                        radius: 12
                        height: 36
                        width: Math.max(36, label.implicitWidth + 22)
                        color: Qt.rgba(0.12, 0.12, 0.16, 0.45)
                        border.color: Qt.rgba(1, 1, 1, 0.16)
                        border.width: 1

                        scale: 0.8
                        opacity: 0
                        Component.onCompleted: { scale = 1; opacity = 1 }
                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        // subtle glass sheen fading from the top
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.10) }
                                GradientStop { position: 0.6; color: Qt.rgba(1, 1, 1, 0.0) }
                            }
                        }

                        // thin accent underline for a modern tag feel
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width * 0.5
                            height: 2
                            radius: 1
                            color: shellRoot ? shellRoot.colAccent : "#007AFF"
                            opacity: 0.7
                        }

                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: chip.modelData
                            color: shellRoot ? shellRoot.colFg : "#fff"
                            font.family: shellRoot ? shellRoot.fontFamily : "monospace"
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }
                }
            }
        }
    }
}
