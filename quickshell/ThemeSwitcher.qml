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
    property var themes: []
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
            themeModel.clear();
            pGetThemes.running = true;
            focusTimer.start();
        }
    }
    
    function filterThemes(query) {
        themeModel.clear();
        var q = query.toLowerCase();
        for (var i = 0; i < themes.length; i++) {
            if (themes[i].toLowerCase().includes(q)) {
                themeModel.append({"name": themes[i]});
            }
        }
        listView.currentIndex = 0;
    }
    
    Process {
        id: pGetThemes
        command: ["sh", "-c", "ls ~/.config/hypr/themes/*.conf 2>/dev/null | xargs -n 1 basename | sed 's/\\.conf//'"]
        stdout: SplitParser {
            onRead: data => {
                var d = data.trim();
                if (d.length > 0) {
                    themes.push(d);
                }
            }
        }
        onRunningChanged: {
            if (!running && rootWindow.show) {
                rootWindow.filterThemes("");
            }
        }
        onStarted: { themes = []; }
    }
    
    Process { id: pExec }
    
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
                anchors.margins: 16
                opacity: show ? 1.0 : 0.0
                clip: true
                Behavior on opacity { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 300 : 100; easing.type: Easing.InOutQuad } }

                ColumnLayout {
                    anchors.fill: parent
                spacing: 16
                
                TextField {
                    id: searchInput
                    Layout.fillWidth: true
                    placeholderText: "SEARCH THEMES..."
                    color: shellRoot ? shellRoot.colFg : "white"
                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                    font.pixelSize: 14
                    font.bold: true
                    background: Rectangle {
                        color: Qt.rgba(1,1,1,0.05)
                        radius: 0
                        border.color: searchInput.activeFocus ? Qt.rgba(1, 0.42, 0, 0.5) : "transparent"
                        border.width: 1
                    }
                    onTextEdited: filterThemes(text)
                    Keys.onDownPressed: listView.incrementCurrentIndex()
                    Keys.onUpPressed: listView.decrementCurrentIndex()
                    Keys.onReturnPressed: {
                        if (listView.currentIndex >= 0 && listView.currentIndex < themeModel.count) {
                            var t = themeModel.get(listView.currentIndex).name;
                            pExec.command = ["/home/miles/.config/hypr/scripts/switch_theme.sh", t];
                            pExec.running = true;
                            show = false;
                        }
                    }
                    Keys.onEscapePressed: show = false
                }
                
                ListView {
                    id: listView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: ListModel { id: themeModel }
                    spacing: 4
                    
                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 48
                        radius: 0
                        color: listView.currentIndex === index || ma.containsMouse ? Qt.rgba(1, 0.42, 0, 0.15) : "transparent"
                        border.color: listView.currentIndex === index ? Qt.rgba(1, 0.42, 0, 0.5) : "transparent"
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
                                text: model.name.toUpperCase()
                                color: shellRoot ? shellRoot.colFg : "white"
                                font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                font.pixelSize: 12
                                font.bold: true
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
                                pExec.command = ["/home/miles/.config/hypr/scripts/switch_theme.sh", model.name];
                                pExec.running = true;
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
