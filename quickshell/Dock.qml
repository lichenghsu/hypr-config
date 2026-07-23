import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: rootWindow

    property bool show: false
    property var shellRoot
    property real animHeight: animRect.height
    property int selectedIndex: 0

    readonly property var pinnedApps: [
        { name: "Firefox", exec: "firefox", icon: "org.mozilla.FirefoxDevEdition" },
        { name: "tabularis", exec: "/usr/bin/tabularis", icon: "tabularis" },
        { name: "Discord", exec: "/usr/bin/discord", icon: "discord" },
        { name: "Zed", exec: "/home/miles/.local/zed.app/bin/zed", icon: "/home/miles/.local/zed.app/share/icons/hicolor/512x512/apps/zed.png" },
        { name: "Brave", exec: "/usr/bin/brave-browser-stable", icon: "brave-browser" },
        { name: "Virtual Machine Manager", exec: "virt-manager", icon: "virt-manager" },
        { name: "Dolphin", exec: "dolphin", icon: "org.kde.dolphin"}
    ]

    function iconSource(icon) {
        return icon.startsWith("/") ? "file://" + icon : Quickshell.iconPath(icon, "application-x-executable")
    }

    function launch(index) {
        var app = pinnedApps[index];
        pExec.command = ["sh", "-c", app.exec + " > /dev/null 2>&1 &"];
        pExec.running = true;
        show = false;
    }

    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    visible: show || animRect.opacity > 0

    onShowChanged: {
        if (show) {
            selectedIndex = 0;
            focusTimer.start();
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: dockContent.forceActiveFocus()
    }

    Process { id: pExec }

    Item {
        id: dockContent
        anchors.fill: parent
        focus: show
        Keys.onEscapePressed: show = false
        Keys.onLeftPressed: selectedIndex = Math.max(0, selectedIndex - 1)
        Keys.onRightPressed: selectedIndex = Math.min(rootWindow.pinnedApps.length - 1, selectedIndex + 1)
        Keys.onReturnPressed: rootWindow.launch(selectedIndex)

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

            width: show ? (layout.implicitWidth + 48) : (shellRoot ? shellRoot.notchWidth + 32 : 120)
            height: show ? (layout.implicitHeight + 48) : 32

            color: Qt.rgba(0.08, 0.08, 0.08, 0.95)
            radius: 0
            border.color: Qt.rgba(1, 0.42, 0, 0.5)
            border.width: show ? 1 : 0

            opacity: (!show && height <= 36) ? 0.0 : 1.0

            Rectangle {
                visible: show
                width: 3
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                color: "#FF6A00"
            }

            Behavior on radius { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }
            Behavior on width { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }
            Behavior on height { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }
            Behavior on anchors.topMargin { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }

            Item {
                anchors.fill: parent
                opacity: show ? 1.0 : 0.0
                clip: true
                Behavior on opacity { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 300 : 100; easing.type: Easing.InOutQuad } }

                RowLayout {
                    id: layout
                    anchors.centerIn: parent
                    spacing: 16

                    Repeater {
                        model: rootWindow.pinnedApps

                        Rectangle {
                            required property var modelData
                            required property int index

                            width: 64; height: 64; radius: 0
                            border.color: Qt.rgba(1, 0.42, 0, 0.5); border.width: 1
                            color: (dockMa.containsMouse || rootWindow.selectedIndex === index) ? Qt.rgba(1, 0.42, 0, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                            scale: (dockMa.containsMouse || rootWindow.selectedIndex === index) ? 1.12 : 1.0
                            Behavior on scale { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : 150; easing.type: Easing.OutBack; easing.overshoot: 2.0 } }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 4

                                IconImage {
                                    Layout.alignment: Qt.AlignHCenter
                                    implicitSize: 32
                                    source: rootWindow.iconSource(modelData.icon)
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.maximumWidth: 60
                                    elide: Text.ElideRight
                                    text: modelData.name
                                    color: shellRoot ? shellRoot.colFg : "white"
                                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                    font.pixelSize: 9
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }

                            MouseArea {
                                id: dockMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    rootWindow.selectedIndex = index;
                                    rootWindow.launch(index);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
