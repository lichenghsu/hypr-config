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
    property var btItems: []
    property real animHeight: animRect.height
    
    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    
    visible: show || animRect.opacity > 0

    Process {
        id: pListBt
        command: ["bash", "-c", "for dev in $(bluetoothctl devices | awk '{print $2}'); do info=$(bluetoothctl info $dev); name=$(echo \"$info\" | awk -F'Name: ' '/Name:/ {print $2}'); connected=$(echo \"$info\" | awk -F'Connected: ' '/Connected:/ {print $2}'); echo \"$dev|$name|$connected\"; done"]
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line === "") return;
                var parts = line.split('|');
                if (parts.length >= 3) {
                    var mac = parts[0];
                    var name = parts[1];
                    var connected = (parts[2] === "yes");
                    if (name !== "") {
                        if (connected) {
                            btItems.unshift({mac: mac, name: name, connected: connected});
                        } else {
                            btItems.push({mac: mac, name: name, connected: connected});
                        }
                    }
                }
            }
        }
        onRunningChanged: {
            if (!running) {
                btModel.clear();
                for (var i = 0; i < btItems.length; i++) {
                    btModel.append(btItems[i]);
                }
            }
        }
    }

    Process {
        id: pConnect
        property string targetMac: ""
        command: targetMac !== "" ? ["bluetoothctl", "connect", targetMac] : ["echo"]
    }

    Process {
        id: pDisconnect
        property string targetMac: ""
        command: targetMac !== "" ? ["bluetoothctl", "disconnect", targetMac] : ["echo"]
    }

    onShowChanged: {
        if (show) {
            btItems = [];
            btModel.clear();
            pListBt.running = true;
            focusTimer.start();
        }
    }
    
    Timer {
        id: focusTimer
        interval: 50
        onTriggered: btMenuContent.forceActiveFocus()
    }
    
    Item {
        id: btMenuContent
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: {
            show = false;
        }

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
            
            width: show ? 360 : (shellRoot ? shellRoot.notchWidth + 32 : 120)
            height: show ? 280 : 32
            
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
            
            Behavior on radius { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }
            Behavior on width { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }
            Behavior on height { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }
            Behavior on anchors.topMargin { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }
            
            Item {
                anchors.fill: parent
                opacity: show ? 1.0 : 0.0
                clip: true
                Behavior on opacity { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 300 : 100; easing.type: Easing.InOutQuad } }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    
                    Text {
                        text: "BLUETOOTH DEVICES"
                        color: "#FF6A00"
                        font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                        font.pixelSize: 14
                        font.bold: true
                        font.letterSpacing: 1
                        Layout.alignment: Qt.AlignHCenter
                    }

                    ListView {
                        id: listView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: ListModel { id: btModel }
                        spacing: 4
                        
                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 48
                            radius: 0
                            color: listView.currentIndex === index || ma.containsMouse ? Qt.rgba(1, 0.42, 0, 0.15) : "transparent"
                            border.color: model.connected ? Qt.rgba(0.11, 0.7, 0.33, 0.5) : "transparent"
                            border.width: 1

                            Rectangle {
                                visible: model.connected
                                width: 3
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                color: "#1DB954"
                            }
                            
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12
                                Text {
                                    text: "BT"
                                    color: model.connected ? "#1DB954" : "#FF6A00"
                                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                                Text {
                                    text: model.name.toUpperCase() + (model.connected ? " [CONNECTED]" : "")
                                    color: model.connected ? "#1DB954" : (shellRoot ? shellRoot.colFg : "white")
                                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                    font.pixelSize: 12
                                    font.bold: model.connected
                                    font.letterSpacing: 1
                                    Layout.fillWidth: true
                                }
                            }
                            
                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    listView.currentIndex = index;
                                    var mac = model.mac;
                                    if (model.connected) {
                                        pDisconnect.targetMac = mac;
                                        pDisconnect.running = true;
                                    } else {
                                        pConnect.targetMac = mac;
                                        pConnect.running = true;
                                    }
                                    show = false;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
