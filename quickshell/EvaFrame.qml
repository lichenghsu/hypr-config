import QtQuick

// 人類補完計畫（shellRoot.evaMode）開啟時疊在各彈出視窗上的 EVA / NERV 外框：
// 紅色暗角 + NERV logo 浮水印 + 掃描線、四角括號、左上 NERV 標籤、右上危險斜紋、右下 MAGI 標記。
// 放在容器的第一個子元件，畫在背景之上、內容之下；不吃滑鼠事件。
Item {
    id: evaFrame
    anchors.fill: parent

    property var shellRoot
    property bool active: true
    property string label: ""            // 例："POWER"
    property string labelJp: ""          // 例："電源"（可留空）
    property bool showStripes: true
    property bool showBrackets: true
    property bool showMagi: true
    property bool showLogo: true          // 中央 NERV logo 浮水印（太小的容器自動不顯示）

    readonly property bool on: !!(shellRoot && shellRoot.evaMode) && active
    readonly property color red: "#FF1A1A"
    readonly property color orange: "#FF6A00"
    readonly property string mono: shellRoot ? shellRoot.fontFamily : "monospace"
    readonly property bool noAnim: !!(shellRoot && shellRoot.batteryMode)

    visible: opacity > 0
    opacity: on ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: evaFrame.noAnim ? 0 : 200 } }

    // 紅色暗角
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.5, 0, 0, 0.12)
    }

    // NERV logo 浮水印
    Image {
        readonly property real side: Math.min(evaFrame.width, evaFrame.height) * 0.85
        visible: evaFrame.showLogo && evaFrame.width > 200 && evaFrame.height > 150
        width: side; height: side
        anchors.centerIn: parent
        opacity: 0.06
        source: visible ? Qt.resolvedUrl("assets/nerv_logo.png") : ""
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }

    // 掃描線
    Canvas {
        id: scan
        anchors.fill: parent
        opacity: 0.08
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const c = getContext("2d"); c.reset()
            c.fillStyle = evaFrame.red
            for (let y = 0; y < height; y += 3) c.fillRect(0, y, width, 1)
        }
    }

    // 四角括號
    Repeater {
        model: evaFrame.showBrackets ? 4 : 0
        Item {
            readonly property bool isRight: index % 2 === 1
            readonly property bool isBottom: index >= 2
            width: 16; height: 16
            x: isRight ? evaFrame.width - width - 3 : 3
            y: isBottom ? evaFrame.height - height - 3 : 3
            Rectangle { width: parent.width; height: 2; color: evaFrame.red; y: parent.isBottom ? parent.height - 2 : 0 }
            Rectangle { width: 2; height: parent.height; color: evaFrame.red; x: parent.isRight ? parent.width - 2 : 0 }
        }
    }

    // 左上 NERV 標籤
    Row {
        x: 24; y: 4
        spacing: 6
        visible: evaFrame.label !== "" && evaFrame.width > 220
        Rectangle {
            width: nervTxt.implicitWidth + 8; height: 12
            color: evaFrame.red
            Text {
                id: nervTxt
                anchors.centerIn: parent
                text: "NERV"
                color: "black"
                font { family: evaFrame.mono; pixelSize: 8; bold: true; letterSpacing: 1.5 }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: evaFrame.label
            color: evaFrame.red
            font { family: evaFrame.mono; pixelSize: 8; bold: true; letterSpacing: 1.5 }
            SequentialAnimation on opacity {
                running: evaFrame.on && !evaFrame.noAnim
                loops: Animation.Infinite
                NumberAnimation { to: 0.45; duration: 700 }
                NumberAnimation { to: 1.0; duration: 700 }
            }
        }
        Text {
            visible: evaFrame.labelJp !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: evaFrame.labelJp
            color: evaFrame.red
            font { family: "Noto Serif CJK JP"; pixelSize: 11; weight: Font.Black; letterSpacing: 2 }
        }
    }

    // 右上危險斜紋
    Canvas {
        visible: evaFrame.showStripes && evaFrame.width > 220
        width: 72; height: 6
        x: evaFrame.width - width - 24; y: 7
        onPaint: {
            const c = getContext("2d"); c.reset()
            c.fillStyle = evaFrame.orange
            for (let x = -height; x < width; x += 8) {
                c.beginPath()
                c.moveTo(x, height); c.lineTo(x + height, 0); c.lineTo(x + height + 4, 0); c.lineTo(x + 4, height)
                c.closePath(); c.fill()
            }
        }
    }

    // 右下 MAGI 標記
    Text {
        visible: evaFrame.showMagi && evaFrame.height > 90 && evaFrame.width > 260
        anchors { right: parent.right; bottom: parent.bottom; rightMargin: 24; bottomMargin: 5 }
        text: "MAGI // MELCHIOR-1 BALTHASAR-2 CASPER-3"
        color: Qt.rgba(1, 0.1, 0.1, 0.45)
        font { family: evaFrame.mono; pixelSize: 7; bold: true; letterSpacing: 1 }
    }
}
