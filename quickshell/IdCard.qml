import QtQuick
import QtQuick.Layouts

Rectangle {
    id: idCard
    width: 680
    height: 1080

    property var shellRoot
    // 人類補完計畫開啟時改成 NERV 職員證樣式（條碼維持白底黑條，載具仍可掃）
    readonly property bool eva: !!(shellRoot && shellRoot.evaMode)
    readonly property color evaRed: "#FF1A1A"
    readonly property color evaOrange: "#FF6A00"
    readonly property string serif: "Noto Serif CJK JP"
    readonly property bool noAnim: !!(shellRoot && shellRoot.batteryMode)

    radius: eva ? 0 : 32
    color: eva ? "#0a0202" : "#121214"
    border.color: eva ? evaRed : "#27272a"
    border.width: eva ? 3 : 2

    // EVA：浮水印大葉片 + 外框（掃描線 / 四角括號 / NERV 標籤）
    Canvas {
        id: watermark
        visible: idCard.eva
        width: 520; height: 640
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 40
        opacity: 0.06
        onVisibleChanged: requestPaint()
        onPaint: idCard.paintLeaf(getContext("2d"), width, height, idCard.evaRed)
    }
    EvaFrame { shellRoot: idCard.shellRoot; label: "PERSONNEL IDENTIFICATION"; labelJp: "職員証" }

    // NERV 風格半邊無花果葉：中軸在左，右側三段葉緣
    function paintLeaf(c, w, h, col) {
        c.reset()
        c.beginPath()
        c.moveTo(w * 0.12, h * 0.98)                       // 葉柄底
        c.lineTo(w * 0.12, h * 0.04)                       // 中軸
        c.bezierCurveTo(w * 0.55, h * 0.02, w * 0.80, h * 0.14, w * 0.66, h * 0.28)
        c.bezierCurveTo(w * 0.98, h * 0.30, w * 1.00, h * 0.50, w * 0.72, h * 0.56)
        c.bezierCurveTo(w * 0.94, h * 0.66, w * 0.80, h * 0.86, w * 0.40, h * 0.80)
        c.lineTo(w * 0.22, h * 0.86)
        c.lineTo(w * 0.22, h * 0.98)
        c.closePath()
        c.fillStyle = col; c.fill()
    }

    // -------------------------------------------------------------------------
    // Code 39 條碼動態生成函式
    // -------------------------------------------------------------------------
    function getCode39Pattern(text) {
        var code39 = {
            '0': "000110100", '1': "100100001", '2': "001100001", '3': "101100000",
            '4': "000110001", '5': "100110000", '6': "001110000", '7': "000100101",
            '8': "100100100", '9': "001100100", 'A': "100001001", 'B': "001001001",
            'C': "101001000", 'D': "000011001", 'E': "100011000", 'F': "001011000",
            'G': "000001101", 'H': "100001100", 'I': "001001100", 'J': "000011100",
            'K': "100000011", 'L': "001000011", 'M': "101000010", 'N': "000010011",
            'O': "100010010", 'P': "001010010", 'Q': "000000111", 'R': "100000110",
            'S': "001000110", 'T': "000010110", 'U': "110000001", 'V': "011000001",
            'W': "111000000", 'X': "010010001", 'Y': "110010000", 'Z': "011010000",
            '-': "010000101", '.': "110000100", ' ': "011000100", '*': "010010100",
            '$': "010101000", '/': "010100010", '+': "010001010", '%': "000101010"
        };

        var fullText = "*" + text.toUpperCase() + "*";
        var bars = [];

        for (var i = 0; i < fullText.length; i++) {
            var ch = fullText[i];
            var pattern = code39[ch];
            if (!pattern) continue;

            for (var j = 0; j < 9; j++) {
                var isBar = (j % 2 === 0);
                var isWide = (pattern[j] === '1');
                bars.push({
                    isBar: isBar,
                    width: isWide ? 3 : 1
                });
            }
            if (i < fullText.length - 1) {
                bars.push({ isBar: false, width: 1 });
            }
        }
        return bars;
    }

    // -------------------------------------------------------------------------
    // 1. 頂部掛繩孔
    // -------------------------------------------------------------------------
    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 24
        anchors.horizontalCenter: parent.horizontalCenter
        width: 100
        height: 20
        radius: idCard.eva ? 0 : 10
        color: "#09090b"
        border.color: idCard.eva ? idCard.evaRed : "#27272a"
        border.width: 2
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 72
        anchors.bottomMargin: 40
        anchors.leftMargin: 48
        anchors.rightMargin: 48
        spacing: 28

        // ---------------------------------------------------------------------
        // 2. 公司 / 組織 Logo 與名稱
        // ---------------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 16

            Rectangle {
                visible: !idCard.eva
                width: 48
                height: 48
                radius: 12
                color: "#ff6a00"

                Text {
                    anchors.centerIn: parent
                    text: "❖"
                    color: "#ffffff"
                    font.pixelSize: 28
                }
            }

            Canvas {
                visible: idCard.eva
                Layout.preferredWidth: 44
                Layout.preferredHeight: 56
                onVisibleChanged: requestPaint()
                onPaint: idCard.paintLeaf(getContext("2d"), width, height, idCard.evaRed)
            }

            ColumnLayout {
                spacing: -4
                Text {
                    text: idCard.eva ? "NERV" : "SKYGATE CORP."
                    color: idCard.eva ? idCard.evaRed : "#f4f4f5"
                    font.pixelSize: idCard.eva ? 40 : 28
                    font.family: idCard.eva ? idCard.serif : Qt.application.font.family
                    font.weight: idCard.eva ? Font.Black : Font.Bold
                    font.letterSpacing: idCard.eva ? 8 : 4
                }
                Text {
                    visible: idCard.eva
                    text: "特務機関ネルフ  //  SKYGATE BRANCH"
                    color: idCard.evaOrange
                    font.pixelSize: 15
                    font.family: idCard.serif
                    font.bold: true
                    font.letterSpacing: 2
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                color: idCard.eva ? idCard.evaRed : "transparent"
                implicitWidth: staffTxt.implicitWidth + (idCard.eva ? 16 : 0)
                implicitHeight: staffTxt.implicitHeight + (idCard.eva ? 6 : 0)
                Text {
                    id: staffTxt
                    anchors.centerIn: parent
                    text: idCard.eva ? "職員" : "STAFF"
                    color: idCard.eva ? "black" : "#ff6a00"
                    font.pixelSize: idCard.eva ? 24 : 20
                    font.bold: true
                    font.family: idCard.eva ? idCard.serif : Qt.application.font.family
                    font.letterSpacing: 2
                }
            }
        }

        Rectangle {
            visible: !idCard.eva
            Layout.fillWidth: true
            height: 2
            color: "#27272a"
        }

        Canvas {
            visible: idCard.eva
            Layout.fillWidth: true
            Layout.preferredHeight: 12
            onVisibleChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
                const c = getContext("2d"); c.reset()
                c.fillStyle = idCard.evaOrange
                for (let x = -height; x < width; x += 20) {
                    c.beginPath()
                    c.moveTo(x, height); c.lineTo(x + height, 0); c.lineTo(x + height + 10, 0); c.lineTo(x + 10, height)
                    c.closePath(); c.fill()
                }
            }
        }

        // ---------------------------------------------------------------------
        // 3. 大頭貼區域
        // ---------------------------------------------------------------------
        Rectangle {
            id: avatarFrame
            Layout.alignment: Qt.AlignHCenter
            width: 260
            height: 320
            radius: idCard.eva ? 0 : 24
            color: "#18181b"
            border.color: idCard.eva ? idCard.evaRed : "#3f3f46"
            border.width: 2
            clip: true

            Image {
                anchors.fill: parent
                anchors.margins: idCard.eva ? 2 : 0
                source: "file:///home/miles/Pictures/Memes/WHAT_EVER/DORA.jpg"
                fillMode: Image.PreserveAspectCrop
            }

            // EVA：照片紅色濾鏡 + 上下掃描線 + 準星 + 標籤
            Item {
                anchors.fill: parent
                visible: idCard.eva
                Rectangle { anchors.fill: parent; color: Qt.rgba(0.6, 0, 0, 0.18) }
                Rectangle {
                    id: photoScan
                    width: parent.width; height: 2
                    color: idCard.evaRed
                    opacity: 0.7
                    NumberAnimation on y {
                        running: idCard.eva && !idCard.noAnim
                        from: 0; to: avatarFrame.height; duration: 2600; loops: Animation.Infinite
                    }
                }
                Rectangle { anchors.centerIn: parent; width: 36; height: 1; color: idCard.evaRed; opacity: 0.6 }
                Rectangle { anchors.centerIn: parent; width: 1; height: 36; color: idCard.evaRed; opacity: 0.6 }
                Rectangle {
                    anchors { left: parent.left; bottom: parent.bottom; margins: 2 }
                    width: subjTxt.implicitWidth + 12; height: 20
                    color: idCard.evaRed
                    Text {
                        id: subjTxt
                        anchors.centerIn: parent
                        text: "IDENTITY CONFIRMED"
                        color: "black"
                        font { family: "monospace"; pixelSize: 11; bold: true; letterSpacing: 1 }
                    }
                }
            }
        }

        // ---------------------------------------------------------------------
        // 4. 個人詳細資料區
        // ---------------------------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "麥爾斯 / MILES HSU"
                color: "#ffffff"
                font.pixelSize: 40
                font.family: idCard.eva ? idCard.serif : Qt.application.font.family
                font.weight: idCard.eva ? Font.Black : Font.Bold
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Full Stack Software Engernior"
                color: idCard.eva ? idCard.evaOrange : "#a1a1aa"
                font.pixelSize: 24
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 16
            columnSpacing: 32

            Text { text: "DEPARTMENT"; color: idCard.eva ? idCard.evaOrange : "#71717a"; font.pixelSize: 18; font.bold: true }
            Text { text: "JAVA TEAM"; color: idCard.eva ? idCard.evaOrange : "#71717a"; font.pixelSize: 18; font.bold: true }

            Text { text: "Java 程式開發組"; color: "#e4e4e7"; font.pixelSize: 22; font.bold: true }
            Text { text: idCard.eva ? "SECURITY LEVEL 67" : "LEVEL 67"; color: idCard.eva ? idCard.evaRed : "#ff6a00"; font.pixelSize: 22; font.bold: true }

            Text { text: "EMPLOYEE ID"; color: idCard.eva ? idCard.evaOrange : "#71717a"; font.pixelSize: 18; font.bold: true }
            Text { text: "EXPIRY DATE"; color: idCard.eva ? idCard.evaOrange : "#71717a"; font.pixelSize: 18; font.bold: true }

            Text { text: "EMP-2025-0804"; color: "#e4e4e7"; font.pixelSize: 22; font.family: "monospace" }
            Text { text: "2077 / 06 / 07"; color: "#e4e4e7"; font.pixelSize: 22; font.family: "monospace" }
        }

        Item { Layout.fillHeight: true }

        // ---------------------------------------------------------------------
        // 5. 底部手機載具條碼 (/NRFKDSP)
        // ---------------------------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            height: 116
            color: "#ffffff"
            radius: idCard.eva ? 0 : 16
            border.color: idCard.eva ? idCard.evaRed : "transparent"
            border.width: idCard.eva ? 3 : 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 4

                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 0

                    Repeater {
                        model: idCard.getCode39Pattern("/NRFKDSP")
                        Rectangle {
                            width: modelData.width * 2.9
                            height: 60
                            color: modelData.isBar ? "#000000" : "transparent"
                        }
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "/NRFKDSP"
                    color: "#000000"
                    font.pixelSize: 22
                    font.bold: true
                    font.family: "monospace"
                    font.letterSpacing: 4
                }
            }
        }

        Text {
            visible: idCard.eva
            Layout.alignment: Qt.AlignHCenter
            text: "GOD'S IN HIS HEAVEN. ALL'S RIGHT WITH THE WORLD."
            color: idCard.evaRed
            font { family: idCard.serif; pixelSize: 14; bold: true; letterSpacing: 2 }
        }
    }
}
