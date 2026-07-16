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
            pWarmCache.running = true;
        }
    }

    Process {
        id: pScan
        command: ["sh", "-c", "find ~/.config/hypr/wallpaper -type f \\( -name '*.jpg' -o -name '*.jpeg' -o -name '*.png' \\) | sort | while read -r p; do h=$(sha1sum \"$p\" | cut -d' ' -f1); t=\"$HOME/.cache/wallpaper/thumbs/$h.sqre\"; [ -f \"$t\" ] && echo \"$p|$t\" || echo \"$p|$p\"; done"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line.length > 0) {
                    var parts = line.split("|");
                    var p = parts[0];
                    var thumb = parts[1] || p;
                    var name = p.split("/").pop().replace(/\.[^/.]+$/, "");
                    wallpaperModel.append({ path: p, thumb: thumb, name: name });
                }
            }
        }
    }

    Process {
        id: pWarmCache
        command: ["/home/miles/.local/bin/wallpaper_cache.sh", "--all"]
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
            radius: 0
            border.color: Qt.rgba(1, 0.42, 0, 0.5)
            border.width: show ? 1 : 0

            opacity: (!show && height <= 36) ? 0.0 : 1.0

            // NERV 終端機風格左側警示條
            Rectangle {
                visible: show
                width: 3
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                color: "#FF6A00"
            }

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
                            text: "WALLPAPERS"
                            color: "#FF6A00"
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 14
                            font.bold: true
                            font.letterSpacing: 1
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            width: 90; height: 22; radius: 0
                            color: rootWindow.matugenMode ? Qt.rgba(1, 0.42, 0, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                            border.color: rootWindow.matugenMode ? "#FF6A00" : Qt.rgba(1, 1, 1, 0.15)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : 200 } }

                            Text {
                                anchors.centerIn: parent
                                text: rootWindow.matugenMode ? "MATUGEN" : "STATIC"
                                color: rootWindow.matugenMode ? "#FF6A00" : (shellRoot ? shellRoot.colMuted : "#888")
                                font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                font.pixelSize: 9
                                font.bold: true
                                font.letterSpacing: 1
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
                                radius: 0
                                color: ma.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                                border.color: ma.containsMouse ? Qt.rgba(1, 0.42, 0, 0.6) : Qt.rgba(1, 0.42, 0, 0.2)
                                border.width: 1
                                clip: true

                                Image {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 66
                                    source: "file://" + model.thumb
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    asynchronous: true
                                    sourceSize.width: 200
                                    sourceSize.height: 66
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
