import QtQuick
import Quickshell
import Quickshell.Wayland

// ── iPhone Duo 闔上動畫：鎖屏前先截圖，左半不動，右半沿中線朝眼睛翻過來蓋上（像闔書），翻的那片越翻越模糊、變暗，蓋上後黑掉才進 LockScreen ──
// fold.frag：透視投影 + duo-open 的毛玻璃模糊/變暗（github.com/marcoazeem/duo-open）
// 截圖時 overlay 是透明的，所以 ScreencopyView 抓到的是底下的桌面
Scope {
    id: fold

    property var lockScreen
    signal finished()

    property bool running: false
    property real progress: 0          // 0 = 攤平，1 = 完全闔上
    readonly property real tilt: progress * 180                 // 動的那半翻過去的角度，180 = 完全蓋上
    readonly property real fade: Math.max(0, (progress - 0.85) / 0.15)  // 蓋上後最後 15% 收成全黑

    // 調整手感
    property real eyeFactor: 1.4       // 眼睛距離 = 螢幕寬 × 這個值，越小透視越誇張
    property real blurSpread: 0.05     // 每 px 間距增加的模糊半徑
    property real darkening: 0.02      // 每 px 模糊半徑損失的亮度
    property real paneSide: 1          // 1 右半翻過來蓋左半；-1 左半翻過來蓋右半
    property real vacatedGlow: 0.45    // 翻走那半留下的模糊殘影：從原亮度降到這個值再慢慢黑掉，0 = 很快變黑

    function play() {
        if (running) return;
        progress = 0;
        running = true;
        startDelay.restart();
        failsafe.restart();
    }

    function done() {
        if (!running) return;
        foldAnim.stop();
        failsafe.stop();
        fold.finished();
    }

    // LockScreen 的黑底出來後才收掉，避免中間閃到桌面
    Connections {
        target: fold.lockScreen
        function onPreLockActiveChanged() { if (fold.lockScreen.preLockActive) fold.running = false; }
        function onActiveChanged() { if (fold.lockScreen.active) fold.running = false; }
    }

    // 給 screencopy 一點時間拿到第一幀
    Timer { id: startDelay; interval: 60; onTriggered: foldAnim.restart() }

    // 截圖失敗或動畫卡住也一定要鎖
    Timer { id: failsafe; interval: 3000; onTriggered: { fold.done(); fold.running = false; } }

    SequentialAnimation {
        id: foldAnim
        NumberAnimation { target: fold; property: "progress"; from: 0; to: 1; duration: 650; easing.type: Easing.InOutSine }
        PauseAnimation { duration: 0 }
        ScriptAction { script: fold.done() }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            visible: fold.running
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "qs-foldlock"
            anchors { top: true; bottom: true; left: true; right: true }

            HoverHandler { cursorShape: Qt.BlankCursor }

            ScreencopyView {
                id: shot
                width: win.width; height: win.height
                captureSource: fold.running ? win.modelData : null
                live: false
            }

            ShaderEffectSource {
                id: shotSrc
                sourceItem: shot
                hideSource: true
                visible: false
            }

            // 截到圖之後才蓋上，不然會先黑一下
            ShaderEffect {
                anchors.fill: parent
                visible: shot.hasContent

                property var source: shotSrc
                property real resW: width
                property real resH: height
                property real tilt: fold.tilt * Math.PI / 180
                property real eyeDist: width * fold.eyeFactor
                property real blurSpread: fold.blurSpread
                property real darkening: fold.darkening
                property real fade: fold.fade
                property real paneSide: fold.paneSide
                property real vacatedGlow: fold.vacatedGlow

                fragmentShader: Qt.resolvedUrl("fold.frag.qsb")
            }
        }
    }
}
