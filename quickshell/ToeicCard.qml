import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

// TOEIC 單字小卡：從 bar 上的 TOEIC 島往下展開。←/→ 切換、Esc 或點外面關閉
PopupWindow {
    id: card

    property bool show: false
    property var shellRoot
    property Item island
    readonly property var word: shellRoot ? shellRoot.toeicWord : null

    grabFocus: show
    visible: show

    HyprlandFocusGrab {
        windows: [card]
        active: card.show
        onCleared: () => card.show = false
    }

    anchor {
        window: card.shellRoot
        rect: Qt.rect(card.island ? card.island.x : 0, card.shellRoot && card.shellRoot.isBarMode ? 32 : 40,
                      card.island ? card.island.width : 1, 1)
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Right
    }
    color: "transparent"
    implicitWidth: 340
    implicitHeight: cardRect.implicitHeight

    Rectangle {
        id: cardRect
        width: 340
        implicitHeight: cardColumn.implicitHeight + 24
        radius: 0
        color: Qt.rgba(0.02, 0.02, 0.02, 0.97)
        border.color: Qt.rgba(1, 0.42, 0, 0.5)
        border.width: 1

        focus: card.show
        Keys.onEscapePressed: card.show = false
        Keys.onLeftPressed: card.shellRoot.toeicStep(-1)
        Keys.onRightPressed: card.shellRoot.toeicStep(1)

        Rectangle {
            width: 3
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            color: "#FF6A00"
        }

        ColumnLayout {
            id: cardColumn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            anchors.leftMargin: 16
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "TOEIC VOCAB"
                    color: "#FF6A00"
                    font { family: card.shellRoot.fontFamily; pixelSize: card.shellRoot.fontSize + 3; bold: true; letterSpacing: 1 }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: (card.shellRoot.toeicPos + 1) + " / " + card.shellRoot.toeicOrder.length
                    color: card.shellRoot.colMuted
                    font { family: card.shellRoot.fontFamily; pixelSize: card.shellRoot.fontSize + 1; bold: true }
                }
                Text {
                    text: "[X]"
                    color: card.shellRoot.colMuted
                    font { family: card.shellRoot.fontFamily; pixelSize: card.shellRoot.fontSize + 2; bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: card.show = false }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 0.42, 0, 0.25) }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: card.word ? card.word.w : ""
                    color: card.shellRoot.colFg
                    font { family: card.shellRoot.fontFamily; pixelSize: 22; bold: true }
                }
                Text {
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: 3
                    text: card.word ? card.word.pos : ""
                    color: "#FF6A00"
                    font { family: card.shellRoot.fontFamily; pixelSize: card.shellRoot.fontSize + 2; bold: true }
                }
            }

            Text {
                Layout.topMargin: -6
                visible: text !== ""
                text: card.word && card.word.ph ? "/" + card.word.ph + "/" : ""
                color: card.shellRoot.colMuted
                font { family: card.shellRoot.fontFamily; pixelSize: card.shellRoot.fontSize + 2 }
            }

            Text {
                Layout.fillWidth: true
                text: card.word ? card.word.zh : ""
                color: card.shellRoot.colFg
                wrapMode: Text.Wrap
                font { family: card.shellRoot.fontFamily; pixelSize: card.shellRoot.fontSize + 4; bold: true }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

            Text {
                Layout.fillWidth: true
                text: card.word ? card.word.ex : ""
                color: card.shellRoot.colFg
                wrapMode: Text.Wrap
                font { family: card.shellRoot.fontFamily; pixelSize: card.shellRoot.fontSize + 2; italic: true }
            }
            Text {
                Layout.fillWidth: true
                text: card.word ? card.word.exZh : ""
                color: card.shellRoot.colMuted
                wrapMode: Text.Wrap
                font { family: card.shellRoot.fontFamily; pixelSize: card.shellRoot.fontSize + 2 }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8

                Repeater {
                    model: [{ label: "< PREV", d: -1 }, { label: "NEXT >", d: 1 }]
                    MouseArea {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 26
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.shellRoot.toeicStep(modelData.d)
                        Rectangle {
                            anchors.fill: parent
                            color: parent.containsMouse ? Qt.rgba(1, 0.42, 0, 0.15) : "transparent"
                            border.color: Qt.rgba(1, 0.42, 0, 0.3)
                            border.width: 1
                        }
                        Text {
                            anchors.centerIn: parent
                            text: parent.modelData.label
                            color: card.shellRoot.colFg
                            font { family: card.shellRoot.fontFamily; pixelSize: card.shellRoot.fontSize + 1; bold: true }
                        }
                    }
                }
            }
        }
    }
}
