import QtQuick
import Quickshell
import Quickshell.Wayland

// ── Party mode：music popup 的 disco icon 開啟後，在 popup 所在螢幕蓋一層 mirror ball 特效，歌詞放大置中 ──
// 純視覺層：不吃滑鼠、不搶鍵盤，popup 本身仍在最上面可操作
Scope {
    id: party

    property var shellRoot
    property bool show: false

    // cava 平均值 → 0~1 節拍強度，平滑一下避免抖
    property real beat: 0
    readonly property real beatTarget: {
        var b = shellRoot ? shellRoot.cavaBars : [];
        if (!b || b.length === 0) return 0;
        var s = 0;
        for (var i = 0; i < b.length; i++) s += b[i];
        return Math.min(1, s / b.length / 20 * 1.6);
    }
    Behavior on beat { NumberAnimation { duration: 90 } }
    onBeatTargetChanged: beat = beatTarget

    // 背景模糊：theme 預設關 blur，只在 party 開著時用 hyprctl eval 臨時打開，關掉時還原 theme 值
    // battery mode 下不開，省電
    readonly property bool blurOn: show && !(shellRoot && shellRoot.batteryMode)
    onBlurOnChanged: {
        Quickshell.execDetached(["hyprctl", "eval", blurOn
            ? "hl.config({ decoration = { blur = { enabled = true, size = 8, passes = 3 } } })"
            : "local t = require(\"theme\"); hl.config({ decoration = { blur = { enabled = t.blur_enabled, size = t.blur_size, passes = t.blur_passes } } })"]);
    }

    readonly property var lines: shellRoot ? shellRoot.lyricsLines : []
    readonly property int idx: shellRoot ? shellRoot.lyricsIndex : -1
    function lineAt(i) {
        return i >= 0 && i < lines.length ? (lines[i].text || "♪") : "";
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData

            // popup 所在的螢幕把球移到左邊，避免被 popup 擋住
            readonly property bool popupScreen: party.shellRoot && modelData === party.shellRoot.screen

            // 只在 music popup 所在的螢幕顯示，其他螢幕不畫（省 GPU）
            visible: popupScreen && (party.show || stage.opacity > 0)
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "qs-party"
            mask: Region {}

            anchors.top: true; anchors.bottom: true
            anchors.left: true; anchors.right: true

            Item {
                id: stage
                anchors.fill: parent
                opacity: party.show ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

                ShaderEffect {
                    id: fx
                    anchors.fill: parent
                    property real time: 0
                    property real aspect: width / Math.max(1, height)
                    property real beat: party.beat
                    property real ballX: win.popupScreen ? 0.2 : 0.5
                    property real ballY: 0.17
                    property real ballR: 0.075 + 0.006 * party.beat
                    property color tint: party.shellRoot ? party.shellRoot.playerColor : "#FF6A00"
                    property real tintR: tint.r
                    property real tintG: tint.g
                    property real tintB: tint.b
                    fragmentShader: Qt.resolvedUrl("party.frag.qsb")

                    FrameAnimation {
                        running: win.visible
                        // FrameAnimation 不是 Item，沒有 parent，要用 id
                        onTriggered: fx.time += frameTime
                    }
                }

                // ── cava 頻譜：貼底、左右鏡像（低音在中間），彩虹漸層混 playerColor ──
                Row {
                    id: spectrum
                    readonly property var bars: party.shellRoot ? party.shellRoot.cavaBars : []
                    readonly property int half: bars.length
                    readonly property real maxH: parent.height * 0.22
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width * 0.9
                    height: maxH
                    spacing: 6

                    Repeater {
                        model: spectrum.half * 2
                        Item {
                            required property int index
                            // 0..half-1 反向，half..2half-1 正向 → 中間是低音
                            readonly property int k: index < spectrum.half ? spectrum.half - 1 - index : index - spectrum.half
                            readonly property real level: Math.min(1, (spectrum.bars[k] || 0) / 20)
                            width: (spectrum.width - spectrum.spacing * (spectrum.half * 2 - 1)) / Math.max(1, spectrum.half * 2)
                            height: spectrum.height

                            Rectangle {
                                id: bar
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: Math.max(3, spectrum.maxH * parent.level)
                                Behavior on height { NumberAnimation { duration: 80 } }
                                readonly property color c: Qt.tint(
                                    Qt.hsva((parent.k / Math.max(1, spectrum.half) * 0.8 + fx.time * 0.05) % 1, 0.75, 1, 1),
                                    Qt.rgba(fx.tint.r, fx.tint.g, fx.tint.b, 0.35))
                                gradient: Gradient {
                                    GradientStop { position: 0; color: Qt.rgba(bar.c.r, bar.c.g, bar.c.b, 0.9) }
                                    GradientStop { position: 1; color: Qt.rgba(bar.c.r, bar.c.g, bar.c.b, 0.15) }
                                }
                            }
                        }
                    }
                }

                // ── 歌詞：上一行 / 目前 / 下一行，目前那行放大發光 ──
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: parent.height * 0.12
                    width: parent.width * 0.85
                    spacing: 18

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: party.lines.length > 0 ? party.lineAt(party.idx - 1) : ""
                        color: Qt.rgba(1, 1, 1, 0.35)
                        font { family: party.shellRoot ? party.shellRoot.fontFamily : ""; pixelSize: 26; bold: true }
                    }

                    Text {
                        id: current
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        text: party.lines.length > 0
                            ? party.lineAt(party.idx) || "♪"
                            : (party.shellRoot ? party.shellRoot.mprisTitle : "")
                        color: "#FFFFFF"
                        style: Text.Outline
                        styleColor: party.shellRoot ? party.shellRoot.playerColor : "#FF6A00"
                        font { family: party.shellRoot ? party.shellRoot.fontFamily : ""; pixelSize: 64; bold: true }
                        scale: 1 + 0.06 * party.beat
                        transformOrigin: Item.Center
                        transform: Translate { id: currentShift }

                        // 換行：縮小淡出 → 換字 → 彈出
                        Behavior on text {
                            SequentialAnimation {
                                ParallelAnimation {
                                    NumberAnimation { target: current; property: "opacity"; to: 0; duration: 120 }
                                    NumberAnimation { target: currentShift; property: "y"; to: -20; duration: 120 }
                                }
                                PropertyAction {}
                                ParallelAnimation {
                                    NumberAnimation { target: current; property: "opacity"; to: 1; duration: 220 }
                                    NumberAnimation { target: currentShift; property: "y"; from: 24; to: 0; duration: 260; easing.type: Easing.OutBack }
                                }
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: party.lines.length > 0
                            ? party.lineAt(party.idx + 1)
                            : (party.shellRoot ? party.shellRoot.mprisArtist : "")
                        color: Qt.rgba(1, 1, 1, 0.45)
                        font { family: party.shellRoot ? party.shellRoot.fontFamily : ""; pixelSize: 28; bold: true }
                    }
                }
            }
        }
    }
}
