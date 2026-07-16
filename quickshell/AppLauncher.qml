import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: rootWindow

    property bool show: false
    property var shellRoot
    property var allApps: []
    property string activeTab: "apps" // "apps" | "files"
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

    Timer {
        id: fileSearchDebounce
        interval: 150
        onTriggered: {
            if (searchInput.text.length > 0) {
                pGetFiles.command = ["python3", "/home/miles/.config/quickshell/get_files.py", searchInput.text]
                pGetFiles.running = true
            } else {
                fileModel.clear()
            }
        }
    }

    onShowChanged: {
        if (show) {
            activeTab = "apps";
            searchInput.text = "";
            filterApps("");
            fileModel.clear();
            if (allApps.length === 0) {
                pGetApps.running = true;
            }
            focusTimer.start();
        }
    }

    onActiveTabChanged: {
        if (activeTab === "files") fileSearchDebounce.restart()
    }

    function currentModel() { return activeTab === "apps" ? appModel : fileModel }

    function filterApps(query) {
        appModel.clear();
        var q = query.toLowerCase();
        var max = 50; // show max 50 for performance
        var count = 0;
        for (var i = 0; i < allApps.length; i++) {
            if (allApps[i].name.toLowerCase().includes(q)) {
                appModel.append(allApps[i]);
                count++;
                if (count >= max) break;
            }
        }
        listView.currentIndex = 0;
    }

    function onSearchTextChanged(text) {
        if (activeTab === "apps") {
            filterApps(text);
        } else {
            fileSearchDebounce.restart();
        }
    }

    function activateCurrent() {
        var model = currentModel();
        if (listView.currentIndex < 0 || listView.currentIndex >= model.count) return;
        var item = model.get(listView.currentIndex);
        if (activeTab === "apps") {
            pExec.command = ["sh", "-c", item.exec + " &"];
        } else {
            pExec.command = ["sh", "-c", "xdg-open " + JSON.stringify(item.path) + " &"];
        }
        pExec.running = true;
        show = false;
    }

    Process {
        id: pGetApps
        command: ["python3", "/home/miles/.config/quickshell/get_apps.py"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    rootWindow.allApps = JSON.parse(data);
                    if (rootWindow.show && rootWindow.activeTab === "apps") rootWindow.filterApps(searchInput.text);
                } catch(e) {
                    console.log("Error parsing apps: " + e);
                }
            }
        }
    }

    Process {
        id: pGetFiles
        stdout: SplitParser {
            onRead: data => {
                try {
                    var files = JSON.parse(data);
                    fileModel.clear();
                    for (var i = 0; i < files.length; i++) fileModel.append(files[i]);
                    if (rootWindow.activeTab === "files") listView.currentIndex = fileModel.count > 0 ? 0 : -1;
                } catch(e) {
                    console.log("Error parsing files: " + e);
                }
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

            width: show ? 440 : (shellRoot ? shellRoot.notchWidth + 32 : 120)
            height: show ? 420 : 32

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
                    spacing: 12

                    // search bar
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        radius: 0
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: searchInput.activeFocus ? Qt.rgba(1, 0.42, 0, 0.5) : "transparent"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 8

                            Text {
                                text: "SEARCH"
                                color: shellRoot ? shellRoot.colMuted : "#888"
                                font.family: shellRoot ? shellRoot.fontFamily : "monospace"
                                font.pixelSize: 10
                                font.bold: true
                                font.letterSpacing: 1
                            }

                            TextInput {
                                id: searchInput
                                Layout.fillWidth: true
                                color: shellRoot ? shellRoot.colFg : "white"
                                font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                font.pixelSize: 14
                                clip: true

                                Text {
                                    visible: searchInput.text.length === 0
                                    text: rootWindow.activeTab === "apps" ? "Search apps..." : "Search files..."
                                    color: shellRoot ? shellRoot.colMuted : "#888"
                                    font: searchInput.font
                                }

                                onTextEdited: rootWindow.onSearchTextChanged(text)
                                Keys.onDownPressed: listView.incrementCurrentIndex()
                                Keys.onUpPressed: listView.decrementCurrentIndex()
                                Keys.onReturnPressed: rootWindow.activateCurrent()
                                Keys.onTabPressed: {
                                    rootWindow.activeTab = rootWindow.activeTab === "apps" ? "files" : "apps"
                                }
                                Keys.onEscapePressed: show = false
                            }
                        }
                    }

                    // tab bar
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: 0
                            color: rootWindow.activeTab === "apps" ? Qt.rgba(1, 0.42, 0, 0.15) : "transparent"
                            border.color: rootWindow.activeTab === "apps" ? Qt.rgba(1, 0.42, 0, 0.5) : "transparent"
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "APPS"
                                    color: rootWindow.activeTab === "apps" ? "#FF6A00" : (shellRoot ? shellRoot.colFg : "white")
                                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.letterSpacing: 1
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: rootWindow.activeTab = "apps"
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            radius: 0
                            color: rootWindow.activeTab === "files" ? Qt.rgba(1, 0.42, 0, 0.15) : "transparent"
                            border.color: rootWindow.activeTab === "files" ? Qt.rgba(1, 0.42, 0, 0.5) : "transparent"
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    text: "FILES"
                                    color: rootWindow.activeTab === "files" ? "#FF6A00" : (shellRoot ? shellRoot.colFg : "white")
                                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.letterSpacing: 1
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    rootWindow.activeTab = "files"
                                    fileSearchDebounce.restart()
                                }
                            }
                        }
                    }

                    ListView {
                        id: listView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: rootWindow.currentModel()
                        spacing: 4

                        delegate: Rectangle {
                            width: ListView.view.width
                            height: 48
                            radius: 0
                            color: listView.currentIndex === index || ma.containsMouse ? Qt.rgba(1, 0.42, 0, 0.15) : "transparent"
                            border.color: listView.currentIndex === index ? Qt.rgba(1, 0.42, 0, 0.5) : "transparent"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 12

                                IconImage {
                                    Layout.preferredWidth: 26
                                    Layout.preferredHeight: 26
                                    implicitSize: 26
                                    source: Quickshell.iconPath(model.icon, "application-x-executable")
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text {
                                        text: model.name
                                        color: shellRoot ? shellRoot.colFg : "white"
                                        font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        visible: rootWindow.activeTab === "files"
                                        text: model.path ? model.path : ""
                                        color: shellRoot ? shellRoot.colMuted : "#888"
                                        font.family: shellRoot ? shellRoot.fontFamily : "monospace"
                                        font.pixelSize: 10
                                        elide: Text.ElideMiddle
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    listView.currentIndex = index;
                                    rootWindow.activateCurrent();
                                }
                            }
                        }

                        Text {
                            visible: listView.count === 0 && rootWindow.activeTab === "files" && searchInput.text.length > 0
                            anchors.centerIn: parent
                            text: "No files found"
                            color: shellRoot ? shellRoot.colMuted : "#888"
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }
    }

    ListModel { id: appModel }
    ListModel { id: fileModel }
}
