import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

// SUPER+C / 三指上滑 關閉確認視窗
// 預設低調樣式；人類補完計畫（shellRoot.evaMode）開啟時改用 EVA / NERV 警告風格
// 按下時先記住當下焦點視窗的 address，確認後只關那個視窗，
// 避免對話框出現期間焦點移動而關錯。ENTER / Y 確認，ESC / N / 點外面取消。
PanelWindow {
    id: rootWindow

    property bool show: false
    property var shellRoot

    property string targetAddr: ""
    property string targetClass: ""
    property string targetTitle: ""
    property int targetPid: 0
    property int selected: 0 // 0 = ABORT（預設）, 1 = TERMINATE

    readonly property color evaRed: "#FF1A1A"
    readonly property color evaOrange: "#FF6A00"
    readonly property string evaFont: shellRoot ? shellRoot.fontFamily : "monospace"
    readonly property bool noAnim: !!(shellRoot && shellRoot.batteryMode)
    readonly property bool eva: !!(shellRoot && shellRoot.evaMode)

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: show || panel.opacity > 0 || calmPanel.opacity > 0

    // 由 IPC 呼叫：抓目前焦點視窗後才顯示；已顯示時再按 SUPER+C 不做事，避免連按誤殺
    function request() {
        if (show || pActive.running) return
        pActive.running = true
    }

    function confirm() {
        if (!targetAddr) { show = false; return }
        pClose.command = ["hyprctl", "dispatch", "hl.dsp.window.close({window = hl.get_window(\"address:" + targetAddr + "\")})"]
        pClose.running = true
        show = false
    }

    Process {
        id: pActive
        command: ["hyprctl", "activewindow", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let w = null
                try { w = JSON.parse(text) } catch (e) {}
                if (!w || !w.address) return
                rootWindow.targetAddr = w.address
                rootWindow.targetClass = w.class || w.initialClass || "UNKNOWN"
                rootWindow.targetTitle = w.title || ""
                rootWindow.targetPid = w.pid || 0
                rootWindow.selected = 0
                const fm = Hyprland.focusedMonitor
                const fs = fm ? Quickshell.screens.find(s => s.name === fm.name) : null
                if (fs) rootWindow.screen = fs
                rootWindow.show = true
            }
        }
    }

    Process { id: pClose }

    onShowChanged: if (show) focusTimer.start()
    Timer { id: focusTimer; interval: 50; onTriggered: keyCatcher.forceActiveFocus() }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: rootWindow.show
        Keys.onPressed: event => {
            const k = event.key
            if (k === Qt.Key_Escape || k === Qt.Key_N) rootWindow.show = false
            else if (k === Qt.Key_Y) rootWindow.confirm()
            else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) {
                if (rootWindow.selected === 1) rootWindow.confirm()
                else rootWindow.show = false
            }
            else if (k === Qt.Key_Left || k === Qt.Key_Right || k === Qt.Key_Tab || k === Qt.Key_H || k === Qt.Key_L)
                rootWindow.selected = 1 - rootWindow.selected
            else return
            event.accepted = true
        }

        // 暗幕（EVA 模式加紅色掃描線）
        Rectangle {
            anchors.fill: parent
            color: rootWindow.eva ? Qt.rgba(0.08, 0, 0, 0.55) : Qt.rgba(0, 0, 0, 0.25)
            opacity: rootWindow.show ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: rootWindow.noAnim ? 0 : 200 } }
            Repeater {
                model: rootWindow.eva ? Math.ceil(parent.height / 4) : 0
                Rectangle { y: index * 4; width: parent.width; height: 1; color: Qt.rgba(1, 0, 0, 0.06) }
            }
            MouseArea { anchors.fill: parent; enabled: rootWindow.show; onClicked: rootWindow.show = false }
        }

        Rectangle {
            id: panel
            anchors.centerIn: parent
            width: 620
            height: content.implicitHeight + 2 * stripeTop.height + 48
            color: Qt.rgba(0.04, 0, 0, 0.96)
            border.color: rootWindow.evaRed
            border.width: 2
            opacity: rootWindow.show && rootWindow.eva ? 1 : 0
            scale: rootWindow.show ? 1 : 1.08
            Behavior on opacity { NumberAnimation { duration: rootWindow.noAnim ? 0 : 160 } }
            Behavior on scale { NumberAnimation { duration: rootWindow.noAnim ? 0 : 220; easing.type: Easing.OutExpo } }
            MouseArea { anchors.fill: parent } // 吃掉點擊，避免穿透到暗幕而取消

            // 上下斜紋警戒帶
            Component {
                id: hazardStripe
                Item {
                    clip: true
                    Rectangle { anchors.fill: parent; color: rootWindow.evaRed }
                    Row {
                        x: -40 + panel.stripeShift
                        spacing: 14
                        Repeater {
                            model: 40
                            Rectangle { width: 14; height: 60; y: -15; color: "black"; rotation: 35 }
                        }
                    }
                }
            }
            property real stripeShift: 0
            NumberAnimation on stripeShift {
                from: 0; to: 28; duration: 900; loops: Animation.Infinite
                running: rootWindow.show && rootWindow.eva && !rootWindow.noAnim
            }
            Loader { id: stripeTop; sourceComponent: hazardStripe; anchors { top: parent.top; left: parent.left; right: parent.right; margins: 2 } height: 22 }
            Loader { sourceComponent: hazardStripe; anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 2 } height: 22 }

            ColumnLayout {
                id: content
                anchors { left: parent.left; right: parent.right; top: stripeTop.bottom; margins: 24 }
                spacing: 14

                RowLayout {
                    spacing: 18
                    // 六角形警示標誌
                    Canvas {
                        Layout.preferredWidth: 78; Layout.preferredHeight: 78
                        onPaint: {
                            const c = getContext("2d"); const r = 36, cx = 39, cy = 39
                            c.reset(); c.beginPath()
                            for (let i = 0; i < 6; i++) {
                                const a = Math.PI / 3 * i
                                c.lineTo(cx + r * Math.cos(a), cy + r * Math.sin(a))
                            }
                            c.closePath(); c.lineWidth = 3; c.strokeStyle = rootWindow.evaRed; c.stroke()
                            c.fillStyle = rootWindow.evaRed; c.font = "bold 40px sans-serif"
                            c.textAlign = "center"; c.textBaseline = "middle"; c.fillText("!", cx, cy + 2)
                        }
                    }
                    ColumnLayout {
                        spacing: 0
                        Text {
                            text: "WARNING"
                            color: rootWindow.evaRed
                            font { family: rootWindow.evaFont; pixelSize: 54; bold: true; letterSpacing: 6 }
                            SequentialAnimation on opacity {
                                running: rootWindow.show && rootWindow.eva && !rootWindow.noAnim; loops: Animation.Infinite
                                NumberAnimation { to: 0.25; duration: 420 }
                                NumberAnimation { to: 1; duration: 420 }
                            }
                        }
                        Text {
                            text: "PROCESS TERMINATION REQUESTED // AUTH: OPERATOR"
                            color: rootWindow.evaOrange
                            font { family: rootWindow.evaFont; pixelSize: 12; bold: true; letterSpacing: 1.5 }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 0.1, 0.1, 0.5) }

                GridLayout {
                    columns: 2; columnSpacing: 16; rowSpacing: 4
                    Layout.fillWidth: true
                    Text { text: "TARGET"; color: rootWindow.evaOrange; font { family: rootWindow.evaFont; pixelSize: 13; bold: true } }
                    Text { text: rootWindow.targetClass.toUpperCase(); color: "white"; font { family: rootWindow.evaFont; pixelSize: 15; bold: true } Layout.fillWidth: true; elide: Text.ElideRight }
                    Text { text: "TITLE"; color: rootWindow.evaOrange; font { family: rootWindow.evaFont; pixelSize: 13; bold: true } }
                    Text { text: rootWindow.targetTitle; color: Qt.rgba(1, 1, 1, 0.8); font { family: rootWindow.evaFont; pixelSize: 13 } Layout.fillWidth: true; elide: Text.ElideRight }
                    Text { text: "PID / ADDR"; color: rootWindow.evaOrange; font { family: rootWindow.evaFont; pixelSize: 13; bold: true } }
                    Text { text: rootWindow.targetPid + " / " + rootWindow.targetAddr; color: Qt.rgba(1, 1, 1, 0.6); font { family: rootWindow.evaFont; pixelSize: 12 } }
                }

                Text {
                    Layout.fillWidth: true
                    text: "UNSAVED DATA MAY BE LOST. PROCEED WITH TERMINATION?"
                    color: rootWindow.evaRed
                    font { family: rootWindow.evaFont; pixelSize: 13; bold: true; letterSpacing: 1 }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 16
                    Repeater {
                        model: [
                            { label: "ABORT", hint: "ESC / N", idx: 0 },
                            { label: "TERMINATE", hint: "Y", idx: 1 }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool active: rootWindow.selected === modelData.idx || btnMouse.containsMouse
                            readonly property color tone: modelData.idx === 1 ? rootWindow.evaRed : rootWindow.evaOrange
                            Layout.fillWidth: true
                            height: 48
                            color: active ? tone : "transparent"
                            border.color: tone; border.width: 2
                            Text {
                                anchors.centerIn: parent
                                text: modelData.label + "  [" + modelData.hint + "]"
                                color: parent.active ? "black" : parent.tone
                                font { family: rootWindow.evaFont; pixelSize: 15; bold: true; letterSpacing: 3 }
                            }
                            MouseArea {
                                id: btnMouse
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: modelData.idx === 1 ? rootWindow.confirm() : (rootWindow.show = false)
                            }
                        }
                    }
                }
            }
        }

        // 低調樣式（預設）：小卡片、沿用主題色，無動畫特效
        Rectangle {
            id: calmPanel
            readonly property color fg: rootWindow.shellRoot ? rootWindow.shellRoot.colFg : "white"
            readonly property color accent: rootWindow.shellRoot ? rootWindow.shellRoot.colAccent : "#FF6A00"
            anchors.centerIn: parent
            width: 380
            height: calmCol.implicitHeight + 36
            color: Qt.rgba(0.08, 0.08, 0.08, 0.95)
            border.color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1
            opacity: rootWindow.show && !rootWindow.eva ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: rootWindow.noAnim ? 0 : 120 } }
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: calmCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                spacing: 6

                Text {
                    text: "Close " + rootWindow.targetClass + "?"
                    color: calmPanel.fg
                    font { family: rootWindow.evaFont; pixelSize: 15; bold: true }
                    Layout.fillWidth: true; elide: Text.ElideRight
                }
                Text {
                    text: rootWindow.targetTitle
                    visible: text !== ""
                    color: Qt.rgba(calmPanel.fg.r, calmPanel.fg.g, calmPanel.fg.b, 0.55)
                    font { family: rootWindow.evaFont; pixelSize: 12 }
                    Layout.fillWidth: true; elide: Text.ElideRight
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    spacing: 8
                    Item { Layout.fillWidth: true }
                    Repeater {
                        model: [
                            { label: "Cancel", hint: "Esc", idx: 0 },
                            { label: "Close", hint: "Y", idx: 1 }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool active: rootWindow.selected === modelData.idx || calmMouse.containsMouse
                            implicitWidth: calmLabel.implicitWidth + 24
                            implicitHeight: 30
                            color: active ? Qt.rgba(calmPanel.accent.r, calmPanel.accent.g, calmPanel.accent.b, 0.18) : "transparent"
                            border.color: active ? calmPanel.accent : Qt.rgba(1, 1, 1, 0.15)
                            border.width: 1
                            Text {
                                id: calmLabel
                                anchors.centerIn: parent
                                text: modelData.label + "  " + modelData.hint
                                color: parent.active ? calmPanel.accent : calmPanel.fg
                                font { family: rootWindow.evaFont; pixelSize: 12 }
                            }
                            MouseArea {
                                id: calmMouse
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: modelData.idx === 1 ? rootWindow.confirm() : (rootWindow.show = false)
                            }
                        }
                    }
                }
            }
        }
    }
}
