import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

// LIA_ROC 連線方式選單：原本 NetworkManager SSL (openconnect) 或 FortiClient 官方 F44 版
PanelWindow {
    id: rootWindow

    property bool show: false
    property var shellRoot
    property string target: ""
    property int selectedIndex: 0

    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    visible: show || animRect.opacity > 0

    function choose(i) {
        show = false;
        if (i === 0) shellRoot.vpnConnectNm(target);
        else shellRoot.vpnConnectForti();
    }

    onShowChanged: {
        if (show) { selectedIndex = 0; focusTimer.start(); }
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: chooserContent.forceActiveFocus()
    }

    Item {
        id: chooserContent
        anchors.fill: parent
        focus: show
        Keys.onEscapePressed: show = false
        Keys.onLeftPressed: selectedIndex = 0
        Keys.onRightPressed: selectedIndex = 1
        Keys.onReturnPressed: rootWindow.choose(selectedIndex)

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

            // 吃掉點擊，避免點到選單本身就關閉
            MouseArea { anchors.fill: parent; enabled: show }

            Rectangle {
                visible: show
                width: 3
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                color: "#FF6A00"
            }

            Behavior on width { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }
            Behavior on height { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }
            Behavior on anchors.topMargin { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }

            Item {
                anchors.fill: parent
                opacity: show ? 1.0 : 0.0
                clip: true
                Behavior on opacity { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 300 : 100; easing.type: Easing.InOutQuad } }

                ColumnLayout {
                    id: layout
                    anchors.centerIn: parent
                    spacing: 16

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "CONNECT " + rootWindow.target + " VIA"
                        color: shellRoot ? shellRoot.colFg : "white"
                        font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                        font.pixelSize: 12
                        font.bold: true
                        font.letterSpacing: 2
                    }

                    RowLayout {
                        spacing: 24

                        Repeater {
                            model: [
                                { label: "SSL", sub: "NetworkManager" },
                                { label: "FORTICLIENT", sub: "F44" }
                            ]
                            delegate: Rectangle {
                                width: 140; height: 56; radius: 0
                                border.color: Qt.rgba(1, 0.42, 0, 0.5); border.width: 1
                                color: (optMouse.containsMouse || selectedIndex === index) ? Qt.rgba(1, 0.42, 0, 0.7) : Qt.rgba(1, 1, 1, 0.1)
                                scale: (optMouse.containsMouse || selectedIndex === index) ? 1.1 : 1.0
                                Behavior on scale { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : 150 } }
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: shellRoot ? shellRoot.colFg : "white"; font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1 }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.sub; color: shellRoot ? shellRoot.colMuted : "gray"; font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"; font.pixelSize: 9 }
                                }
                                MouseArea {
                                    id: optMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: selectedIndex = index
                                    onClicked: rootWindow.choose(index)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
