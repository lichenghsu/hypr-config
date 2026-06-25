import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: rootWindow

    property bool show: false
    property var shellRoot

    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: show

    // fallback hyprctl focus
    Process { id: pFocus }

    Item {
        anchors.fill: parent
        focus: show

        Keys.onEscapePressed: rootWindow.show = false

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.80)
            MouseArea {
                anchors.fill: parent
                onClicked: rootWindow.show = false
            }
        }

        Flow {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: 60
            }
            spacing: 16

            Repeater {
                model: ToplevelManager.toplevels

                delegate: Rectangle {
                    required property Toplevel modelData

                    // hide minimized windows but keep in layout as 0-height
                    visible: !modelData.minimized
                    width: 240
                    height: visible ? 160 : 0
                    radius: 12
                    clip: true
                    color: cardMa.containsMouse
                           ? Qt.rgba(1, 1, 1, 0.12)
                           : Qt.rgba(0.05, 0.05, 0.05, 0.92)
                    border.color: modelData.activated
                                  ? (shellRoot ? shellRoot.colAccent : "#007AFF")
                                  : Qt.rgba(1, 1, 1, 0.12)
                    border.width: modelData.activated ? 2 : 1

                    Behavior on color {
                        ColorAnimation { duration: shellRoot && shellRoot.batteryMode ? 0 : 150 }
                    }
                    scale: cardMa.containsPress ? 0.95 : 1.0
                    Behavior on scale {
                        NumberAnimation { duration: shellRoot && shellRoot.batteryMode ? 0 : 100 }
                    }

                    ScreencopyView {
                        id: scv
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: parent.height - 48
                        captureSource: modelData
                        live: false
                        // prevent ScreencopyView from swallowing pointer events
                        enabled: false
                    }

                    // fallback icon when screencopy has no content
                    Text {
                        visible: !scv.hasContent
                        anchors.centerIn: scv
                        text: "󰕹"
                        color: Qt.rgba(1, 1, 1, 0.2)
                        font.family: shellRoot ? shellRoot.fontFamily : "monospace"
                        font.pixelSize: 36
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 48
                        color: Qt.rgba(0, 0, 0, 0.65)

                        ColumnLayout {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                margins: 8
                            }
                            spacing: 2

                            Text {
                                text: modelData.title
                                color: shellRoot ? shellRoot.colFg : "#fff"
                                font.family: shellRoot ? shellRoot.fontFamily : "monospace"
                                font.pixelSize: 11
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: modelData.appId
                                color: shellRoot ? shellRoot.colMuted : "#888"
                                font.family: shellRoot ? shellRoot.fontFamily : "monospace"
                                font.pixelSize: 9
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    MouseArea {
                        id: cardMa
                        anchors.fill: parent
                        z: 10
                        hoverEnabled: true
                        onClicked: {
                            rootWindow.show = false
                            modelData.activate()
                        }
                    }
                }
            }
        }
    }
}
