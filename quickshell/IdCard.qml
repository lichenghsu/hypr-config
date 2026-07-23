import QtQuick
import QtQuick.Layouts

Rectangle {
    id: idCard
    width: 680
    height: 1080
    radius: 32
    color: "#121214"
    border.color: "#27272a"
    border.width: 2

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
        radius: 10
        color: "#09090b"
        border.color: "#27272a"
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

            Text {
                text: "SKYGATE CORP."
                color: "#f4f4f5"
                font.pixelSize: 28
                font.bold: true
                font.letterSpacing: 4
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "STAFF"
                color: "#ff6a00"
                font.pixelSize: 20
                font.bold: true
                font.letterSpacing: 2
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 2
            color: "#27272a"
        }

        // ---------------------------------------------------------------------
        // 3. 大頭貼區域
        // ---------------------------------------------------------------------
        Rectangle {
            id: avatarFrame
            Layout.alignment: Qt.AlignHCenter
            width: 260
            height: 320
            radius: 24
            color: "#18181b"
            border.color: "#3f3f46"
            border.width: 2
            clip: true

            Image {
                anchors.fill: parent
                source: "file:///home/miles/Pictures/Memes/WHAT_EVER/DORA.jpg"
                fillMode: Image.PreserveAspectCrop
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
                font.bold: true
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Full Stack Software Engernior"
                color: "#a1a1aa"
                font.pixelSize: 24
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 16
            columnSpacing: 32

            Text { text: "DEPARTMENT"; color: "#71717a"; font.pixelSize: 18; font.bold: true }
            Text { text: "JAVA TEAM"; color: "#71717a"; font.pixelSize: 18; font.bold: true }

            Text { text: "Java 程式開發組"; color: "#e4e4e7"; font.pixelSize: 22; font.bold: true }
            Text { text: "LEVEL 67"; color: "#ff6a00"; font.pixelSize: 22; font.bold: true }

            Text { text: "EMPLOYEE ID"; color: "#71717a"; font.pixelSize: 18; font.bold: true }
            Text { text: "EXPIRY DATE"; color: "#71717a"; font.pixelSize: 18; font.bold: true }

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
            radius: 16

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
    }
}
