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
    property var clipItems: []
    property real animHeight: animRect.height
    
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
        onTriggered: searchInput.forceActiveFocus()
    }

    onShowChanged: {
        if (show) {
            searchInput.text = "";
            appModel.clear();
            pGetClips.running = true;
            focusTimer.start();
        }
    }
    
    function filterClips(query) {
        appModel.clear();
        var q = query.toLowerCase();
        var max = 50; 
        var count = 0;
        for (var i = 0; i < clipItems.length; i++) {
            if (clipItems[i].text.toLowerCase().includes(q)) {
                appModel.append(clipItems[i]);
                count++;
                if (count >= max) break;
            }
        }
        listView.currentIndex = 0;
    }
    
    Process {
        id: pGetClips
        command: ["cliphist", "list"]
        stdout: SplitParser {
            onRead: data => {
                var d = data.trim();
                if (d.length > 0) {
                    var idx = d.indexOf("\t");
                    if (idx > -1) {
                        var id = d.substring(0, idx);
                        var content = d.substring(idx + 1);
                        clipItems.push({"id": id, "text": content});
                    }
                }
            }
        }
        onRunningChanged: {
            if (!running && rootWindow.show) {
                rootWindow.filterClips("");
            }
        }
        onStarted: { clipItems = []; }
    }


    Process {
        id: pClearClips
        command: ["cliphist", "wipe"]

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                rootWindow.clipItems = []
                appModel.clear()
                listView.currentIndex = -1
            } else {
                console.error("Failed to clear cliphist, exit code:", exitCode)
            }
        }
    }

    
    Process { id: pExec }
    
    Item {
        anchors.fill: parent
        
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
            
            width: show ? 400 : (shellRoot ? shellRoot.notchWidth + 32 : 120)
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
            
            Behavior on radius { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }
            Behavior on width { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }
            Behavior on height { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }
            Behavior on anchors.topMargin { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }
            
            Item {
                anchors.fill: parent
                anchors.margins: 16
                opacity: show ? 1.0 : 0.0
                clip: true
                Behavior on opacity { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 300 : 100; easing.type: Easing.InOutQuad } }


                ColumnLayout {
                    anchors.fill: parent
                    spacing: 16

                    // 第一列：搜尋框 + 清除按鈕
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        TextField {
                            id: searchInput
                            Layout.fillWidth: true
                            placeholderText: "SEARCH CLIPBOARD..."
                            color: shellRoot ? shellRoot.colFg : "white"
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 14
                            font.bold: true

                            background: Rectangle {
                                color: Qt.rgba(1, 1, 1, 0.05)
                                radius: 0
                                border.color: searchInput.activeFocus
                                ? Qt.rgba(1, 0.42, 0, 0.5)
                                : "transparent"
                                border.width: 1
                            }

                            onTextEdited: filterClips(text)
                            Keys.onDownPressed: listView.incrementCurrentIndex()
                            Keys.onUpPressed: listView.decrementCurrentIndex()
                            Keys.onEscapePressed: show = false

                            Keys.onReturnPressed: {
                                if (listView.currentIndex >= 0
                                    && listView.currentIndex < appModel.count) {
                                    var clip = appModel.get(listView.currentIndex)
                                    pExec.command = [
                                        "sh", "-c",
                                        "printf '%s' \"$1\" | cliphist decode | wl-copy",
                                        "sh", clip.id
                                    ]
                                    pExec.running = true
                                    show = false
                                    }
                            }
                        }

                        Button {
                            id: clearButton
                            text: "CLEAN UP"
                            implicitWidth: 68
                            implicitHeight: 40
                            enabled: !pClearClips.running

                            onClicked: pClearClips.running = true

                            contentItem: Text {
                                text: clearButton.text
                                color: clearButton.hovered ? "#080808" : "#FF6A00"
                                font.family: shellRoot ? shellRoot.fontFamily : "monospace"
                                font.pixelSize: 11
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                color: clearButton.hovered
                                ? "#FF6A00"
                                : Qt.rgba(1, 0.42, 0, 0.08)
                                border.color: "#FF6A00"
                                border.width: 1
                                radius: 0
                            }
                        }
                    }


                    ListView {
                        id: listView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: ListModel { id: appModel }
                        spacing: 4

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 48
                            radius: 0

                            color: listView.currentIndex === index || ma.containsMouse
                            ? Qt.rgba(1, 0.42, 0, 0.15)
                            : "transparent"

                            border.color: listView.currentIndex === index
                            ? Qt.rgba(1, 0.42, 0, 0.5)
                            : "transparent"
                            border.width: 1

                            Rectangle {
                                visible: listView.currentIndex === index
                                width: 3
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                color: "#FF6A00"
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12

                                Text {
                                    text: model.text
                                    color: shellRoot ? shellRoot.colFg : "white"
                                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true

                                onClicked: {
                                    listView.currentIndex = index

                                    pExec.command = [
                                        "sh", "-c",
                                        "printf '%s' \"$1\" | cliphist decode | wl-copy",
                                        "sh", model.id
                                    ]

                                    pExec.running = true
                                    show = false
                                }
                            }
                        }
                    }

                }

            }
        }
    }
}
