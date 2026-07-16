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
    property var wifiItems: []
    property string selectedSsid: ""
    property var seenSsids: ({})
    property bool loading: false

    function signalIcon(sig) {
        if (sig >= 75) return "SIG:HIGH";
        if (sig >= 50) return "SIG:MED";
        if (sig >= 25) return "SIG:LOW";
        return "SIG:WEAK";
    }
    function signalColor(sig) {
        if (sig >= 60) return "#4CAF50";
        if (sig >= 35) return "#FFC107";
        return "#FF5722";
    }

    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    visible: show || animRect.opacity > 0

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: selectedSsid !== "" ? passInput.forceActiveFocus() : listView.forceActiveFocus()
    }

    onShowChanged: {
        if (show) {
            selectedSsid = "";
            wifiModel.clear();
            wifiItems = [];
            seenSsids = {};
            loading = true;
            pGetWifi.running = true;
            focusTimer.start();
        }
    }

    Process {
        id: pGetWifi
        command: ["sh", "-c", "nmcli -f IN-USE,SSID,SIGNAL,SECURITY -t dev wifi list | sort -r"]
        stdout: SplitParser {
            onRead: data => {
                var d = data.trim();
                if (d.length === 0) return;
                var parts = d.split(":");
                if (parts.length < 3) return;
                var inUse = parts[0];
                var security = parts[parts.length - 1];
                var signal = parseInt(parts[parts.length - 2]) || 0;
                var ssid = parts.slice(1, parts.length - 2).join(":");
                if (ssid === "") return;
                var secure = (security !== "" && security !== "--");
                var connected = (inUse === "*");
                if (!seenSsids[ssid]) {
                    seenSsids[ssid] = true;
                    wifiItems.push({ ssid: ssid, secure: secure, connected: connected, signal: signal });
                }
            }
        }
        onRunningChanged: {
            if (!running) {
                loading = false;
                if (rootWindow.show) {
                    for (var i = 0; i < wifiItems.length; i++)
                        wifiModel.append(wifiItems[i]);
                }
            }
        }
    }

    Process { id: pConnect }
    Process { id: pDisconnect }

    Item {
        anchors.fill: parent
        focus: show
        Keys.onEscapePressed: {
            if (selectedSsid !== "") {
                selectedSsid = "";
                focusTimer.start();
            } else {
                show = false;
            }
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
            height: show ? 320 : 32

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

            Behavior on radius   { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }
            Behavior on width    { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }
            Behavior on height   { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }
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

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: selectedSsid !== "" ? "CONNECT TO " + selectedSsid.toUpperCase() : "WI-FI"
                            color: shellRoot ? shellRoot.colFg : "white"
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 14
                            font.bold: true
                            font.letterSpacing: 1
                            Layout.fillWidth: true
                        }
                        // Refresh button
                        Rectangle {
                            visible: selectedSsid === ""
                            width: 60; height: 28
                            radius: 0
                            border.color: Qt.rgba(1, 0.42, 0, 0.3)
                            border.width: 1
                            color: refreshMa.containsMouse ? Qt.rgba(1,1,1,0.12) : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: loading ? "..." : "REFRESH"
                                color: loading ? Qt.rgba(1,1,1,0.3) : Qt.rgba(1,1,1,0.6)
                                font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                font.pixelSize: 9
                                font.bold: true
                            }
                            MouseArea {
                                id: refreshMa
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !loading
                                onClicked: {
                                    wifiModel.clear();
                                    wifiItems = [];
                                    seenSsids = {};
                                    loading = true;
                                    pGetWifi.running = true;
                                }
                            }
                        }
                    }

                    // Password entry view
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: selectedSsid !== ""
                        spacing: 10

                        TextField {
                            id: passInput
                            Layout.fillWidth: true
                            placeholderText: "Password"
                            echoMode: showPass.checked ? TextInput.Normal : TextInput.Password
                            color: shellRoot ? shellRoot.colFg : "white"
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 13
                            leftPadding: 12; rightPadding: 48
                            background: Rectangle {
                                color: Qt.rgba(1,1,1,0.07)
                                radius: 0
                                border.color: passInput.activeFocus ? Qt.rgba(1, 0.42, 0, 0.5) : Qt.rgba(1,1,1,0.1)
                                border.width: 1
                            }
                            Keys.onReturnPressed: doConnect()
                            Keys.onEscapePressed: { selectedSsid = ""; passInput.text = ""; focusTimer.start(); }

                            // Show/hide password toggle
                            CheckBox {
                                id: showPass
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.rightMargin: 8
                                indicator: Text {
                                    text: showPass.checked ? "HIDE" : "SHOW"
                                    color: Qt.rgba(1,1,1,0.5)
                                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                    font.pixelSize: 9
                                    font.bold: true
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true; height: 38; radius: 0
                                color: cancelMa.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.07)
                                border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                                Text { anchors.centerIn: parent; text: "CANCEL"; color: Qt.rgba(1,1,1,0.7); font.pixelSize: 13; font.bold: true; font.letterSpacing: 1; font.family: shellRoot ? shellRoot.fontFamily : "sans-serif" }
                                MouseArea { id: cancelMa; anchors.fill: parent; hoverEnabled: true; onClicked: { selectedSsid = ""; passInput.text = ""; focusTimer.start(); } }
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 38; radius: 0
                                color: connectMa.containsMouse ? Qt.rgba(1, 0.5, 0.1, 0.9) : Qt.rgba(1, 0.42, 0, 0.8)
                                Text { anchors.centerIn: parent; text: "CONNECT"; color: "white"; font.pixelSize: 13; font.bold: true; font.letterSpacing: 1; font.family: shellRoot ? shellRoot.fontFamily : "sans-serif" }
                                MouseArea { id: connectMa; anchors.fill: parent; hoverEnabled: true; onClicked: doConnect() }
                            }
                        }
                    }

                    // Network list
                    ListView {
                        id: listView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        visible: selectedSsid === ""
                        model: ListModel { id: wifiModel }
                        spacing: 3

                        // Loading / empty states
                        Item {
                            anchors.centerIn: parent
                            visible: loading || (!loading && wifiModel.count === 0)
                            Text {
                                anchors.centerIn: parent
                                text: loading ? "Scanning..." : "No networks found"
                                color: Qt.rgba(1,1,1,0.35)
                                font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                font.pixelSize: 13
                            }
                        }

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 44
                            radius: 0
                            color: model.connected
                                ? Qt.rgba(0.1, 0.7, 0.3, ma.containsMouse ? 0.18 : 0.12)
                                : (ma.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent")

                            // Left accent bar for connected
                            Rectangle {
                                visible: model.connected
                                width: 3; height: 22; radius: 2
                                anchors.left: parent.left
                                anchors.leftMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                color: "#4CAF50"
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: model.connected ? 16 : 12
                                anchors.rightMargin: 10
                                anchors.topMargin: 0
                                anchors.bottomMargin: 0
                                spacing: 10

                                // Signal indicator
                                Text {
                                    text: rootWindow.signalIcon(model.signal)
                                    color: model.connected ? "#4CAF50" : rootWindow.signalColor(model.signal)
                                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                    font.pixelSize: 9
                                    font.bold: true
                                }

                                // SSID + lock icon
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    RowLayout {
                                        spacing: 5
                                        Text {
                                            text: model.ssid
                                            color: model.connected ? "#6EF09A" : (shellRoot ? shellRoot.colFg : "white")
                                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                            font.pixelSize: 13
                                            font.bold: model.connected
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                        Text {
                                            visible: model.secure && !model.connected
                                            text: "[SEC]"
                                            color: Qt.rgba(1,1,1,0.3)
                                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                            font.pixelSize: 9
                                            font.bold: true
                                        }
                                    }
                                    Text {
                                        visible: model.connected
                                        text: "CONNECTED"
                                        color: "#4CAF50"
                                        font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                        font.pixelSize: 10
                                        font.bold: true
                                        font.letterSpacing: 1
                                    }
                                }

                                // Disconnect button (only for connected)
                                Rectangle {
                                    visible: model.connected
                                    width: 74; height: 26; radius: 0
                                    color: discMa.containsMouse ? Qt.rgba(1,0.2,0.2,0.4) : Qt.rgba(1,0.2,0.2,0.2)
                                    border.color: Qt.rgba(1,0.3,0.3,0.4); border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: "DISCONNECT"
                                        color: "#FF6B6B"
                                        font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                    MouseArea {
                                        id: discMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            pDisconnect.command = ["sh", "-c", "nmcli dev disconnect \"$(nmcli -t -f DEVICE,TYPE dev | awk -F: '/wifi/ {print $1; exit}')\""];
                                            pDisconnect.running = true;
                                            rootWindow.show = false;
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                // Don't intercept clicks on the disconnect button area
                                onClicked: {
                                    if (model.connected) return;
                                    listView.currentIndex = index;
                                    if (model.secure) {
                                        selectedSsid = model.ssid;
                                        passInput.text = "";
                                        focusTimer.start();
                                    } else {
                                        pConnect.command = ["nmcli", "dev", "wifi", "connect", model.ssid];
                                        pConnect.running = true;
                                        rootWindow.show = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function doConnect() {
        var p = passInput.text;
        pConnect.command = p === ""
            ? ["nmcli", "dev", "wifi", "connect", selectedSsid]
            : ["nmcli", "dev", "wifi", "connect", selectedSsid, "password", p];
        pConnect.running = true;
        rootWindow.show = false;
    }
}
