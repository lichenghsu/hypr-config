import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: rootWindow

    property bool show: false
    property var shellRoot
    property real animHeight: animRect.height
    property bool matugenMode: false

    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    visible: show || animRect.opacity > 0

    onShowChanged: {
        if (show) {
            wallpaperModel.clear();
            pScan.running = true;
        }
    }

    Process {
        id: pScan
        command: ["sh", "-c", "find ~/.config/hypr/wallpaper -maxdepth 1 -type f \\( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' \\) | sort"]
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim();
                if (p.length > 0) {
                    var name = p.split("/").pop().replace(/\.[^/.]+$/, "");
                    wallpaperModel.append({ path: p, name: name });
                }
            }
        }
    }

    Process { id: pApply }

    Item {
        anchors.fill: parent
        focus: show
        Keys.onEscapePressed: show = false

        MouseArea {
            anchors.fill: parent
            enabled: show
            onClicked: show = false
        }

        Rectangle {
            id: animRect
            anchors.top: parent.top
            anchors.topMargin: show ? 16 : (shellRoot && shellRoot.isBarMode ? 0 : 4)
            anchors.horizontalCenter: parent.horizontalCenter

            width: show ? 520 : (shellRoot ? shellRoot.notchWidth + 32 : 120)
            height: show ? 380 : 32

            color: Qt.rgba(0.08, 0.08, 0.08, 0.95)
            radius: show ? 24 : (shellRoot && shellRoot.isBarMode ? 0 : 16)
            border.color: Qt.rgba(1, 1, 1, 0.1)
            border.width: show ? 1 : 0

            opacity: (!show && height <= 36) ? 0.0 : 1.0

            Behavior on radius    { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }
            Behavior on width     { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }
            Behavior on height    { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }
            Behavior on anchors.topMargin { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }

            Item {
                anchors.fill: parent
                anchors.margins: 16
                opacity: show ? 1.0 : 0.0
                clip: true
                Behavior on opacity { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 300 : 100; easing.type: Easing.InOutQuad } }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Wallpapers"
                            color: shellRoot ? shellRoot.colFg : "white"
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 14
                            font.bold: true
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            width: 90; height: 22; radius: 8
                            color: rootWindow.matugenMode ? Qt.rgba(1, 0.6, 0, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                            border.color: rootWindow.matugenMode ? "#FF9500" : Qt.rgba(1, 1, 1, 0.15)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : 200 } }

                            Text {
                                anchors.centerIn: parent
                                text: rootWindow.matugenMode ? "󰏘 Matugen" : "󰏘 Static"
                                color: rootWindow.matugenMode ? "#FF9500" : (shellRoot ? shellRoot.colMuted : "#888")
                                font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                font.pixelSize: 10
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: rootWindow.matugenMode = !rootWindow.matugenMode
                            }
                        }
                    }

                    GridView {
                        id: gridView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        cellWidth: 116
                        cellHeight: 94

                        model: ListModel { id: wallpaperModel }

                        delegate: Item {
                            width: GridView.view.cellWidth
                            height: GridView.view.cellHeight

                            Rectangle {
                                id: card
                                anchors.fill: parent
                                anchors.margins: 4
                                radius: 8
                                color: ma.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                                border.color: Qt.rgba(1, 1, 1, 0.1)
                                border.width: 1
                                clip: true

                                Image {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 66
                                    source: "file://" + model.path
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    asynchronous: true
                                }

                                Text {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottomMargin: 5
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: 4
                                    text: model.name
                                    color: shellRoot ? shellRoot.colFg : "white"
                                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                    font.pixelSize: 9
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: ma
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        pApply.command = rootWindow.matugenMode
                                            ? ["/home/miles/.local/bin/matugen_theme.sh", model.path]
                                            : ["/home/miles/.local/bin/set_wallpaper.sh", model.path];
                                        pApply.running = true;
                                        rootWindow.show = false;
                                    }
                                }

                                scale: ma.containsPress ? 0.94 : 1.0
                                Behavior on scale { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : 100 } }
                            }
                        }
                    }
                }
            }
        }
    }
}
