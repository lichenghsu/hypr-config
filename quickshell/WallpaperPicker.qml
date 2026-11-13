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
    readonly property color chrome: shellRoot ? shellRoot.colChrome : "#FF6A00"
    function chromeA(a) { return Qt.rgba(chrome.r, chrome.g, chrome.b, a) }
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

    // Every scanned wallpaper; wallpaperModel holds only the ones matching the search query.
    property var allWallpapers: []

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: searchInput.forceActiveFocus()
    }

    onShowChanged: {
        if (show) {
            searchInput.text = "";
            allWallpapers = [];
            wallpaperModel.clear();
            pScan.running = true;
            pWarmCache.running = true;
            focusTimer.start();
        }
    }

    // Every whitespace-separated term must appear in the name; "-" and "_" count as spaces.
    function matches(name, query) {
        var hay = name.toLowerCase().replace(/[-_]/g, " ");
        var terms = query.toLowerCase().trim().split(/\s+/);
        for (var i = 0; i < terms.length; i++) {
            if (terms[i].length > 0 && hay.indexOf(terms[i]) < 0) return false;
        }
        return true;
    }

    function applyFilter() {
        var q = searchInput.text;
        wallpaperModel.clear();
        for (var i = 0; i < allWallpapers.length; i++) {
            if (matches(allWallpapers[i].name, q)) wallpaperModel.append(allWallpapers[i]);
        }
        gridView.currentIndex = wallpaperModel.count > 0 ? 0 : -1;
    }

    function applyWallpaper(path) {
        pApply.command = matugenMode
            ? ["/home/miles/.local/bin/matugen_theme.sh", path]
            : ["/home/miles/.local/bin/set_wallpaper.sh", path];
        pApply.running = true;
        show = false;
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
                    var entry = { path: p, thumb: thumb, name: name };
                    rootWindow.allWallpapers.push(entry);
                    if (rootWindow.matches(name, searchInput.text)) {
                        wallpaperModel.append(entry);
                        if (gridView.currentIndex < 0) gridView.currentIndex = 0;
                    }
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
            EvaFrame { shellRoot: rootWindow.shellRoot; active: rootWindow.show; label: "WALLPAPER"; labelJp: "背景" }
            anchors.top: parent.top
            anchors.topMargin: show ? 24 : (shellRoot && shellRoot.isBarMode ? 0 : 4)
            anchors.horizontalCenter: parent.horizontalCenter

            // 1.5 倍放大尺寸：520 -> 780, 380 -> 570
            width: show ? 780 : (shellRoot ? shellRoot.notchWidth + 32 : 120)
            height: show ? 570 : 32

            color: Qt.rgba(0.08, 0.08, 0.08, 0.95)
            radius: 0
            border.color: rootWindow.chromeA(0.5)
            border.width: show ? 1 : 0

            opacity: (!show && height <= 36) ? 0.0 : 1.0

            // NERV 終端機風格左側警示條 (放大至 5px)
            Rectangle {
                visible: show
                width: 5
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                color: rootWindow.chrome
            }

            Behavior on radius    { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }
            Behavior on width     { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }
            Behavior on height    { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }
            Behavior on anchors.topMargin { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 450 : 300; easing.type: show ? Easing.OutBack : Easing.OutExpo; easing.overshoot: show ? 1.2 : 0 } }

            Item {
                anchors.fill: parent
                anchors.margins: 24
                opacity: show ? 1.0 : 0.0
                clip: true
                Behavior on opacity { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 300 : 100; easing.type: Easing.InOutQuad } }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 18

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "WALLPAPERS"
                            color: rootWindow.chrome
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 21
                            font.bold: true
                            font.letterSpacing: 2
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            width: 135; height: 33; radius: 0
                            color: rootWindow.matugenMode ? rootWindow.chromeA(0.18) : Qt.rgba(1, 1, 1, 0.08)
                            border.color: rootWindow.matugenMode ? rootWindow.chrome : Qt.rgba(1, 1, 1, 0.15)
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : 200 } }

                            Text {
                                anchors.centerIn: parent
                                text: rootWindow.matugenMode ? "MATUGEN" : "STATIC"
                                color: rootWindow.matugenMode ? rootWindow.chrome : (shellRoot ? shellRoot.colMuted : "#888")
                                font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                font.pixelSize: 14
                                font.bold: true
                                font.letterSpacing: 1
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: rootWindow.matugenMode = !rootWindow.matugenMode
                            }
                        }
                    }

                    TextField {
                        id: searchInput
                        Layout.fillWidth: true
                        placeholderText: "SEARCH WALLPAPERS..."
                        color: shellRoot ? shellRoot.colFg : "white"
                        placeholderTextColor: shellRoot ? shellRoot.colMuted : "#888"
                        font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                        font.pixelSize: 14
                        font.bold: true

                        background: Rectangle {
                            color: Qt.rgba(1, 1, 1, 0.05)
                            radius: 0
                            border.color: searchInput.activeFocus ? rootWindow.chromeA(0.5) : "transparent"
                            border.width: 1
                        }

                        function applyCurrent() {
                            if (gridView.currentIndex >= 0 && gridView.currentIndex < wallpaperModel.count)
                                rootWindow.applyWallpaper(wallpaperModel.get(gridView.currentIndex).path);
                        }

                        onTextEdited: rootWindow.applyFilter()
                        Keys.onRightPressed: gridView.moveCurrentIndexRight()
                        Keys.onLeftPressed: gridView.moveCurrentIndexLeft()
                        Keys.onDownPressed: gridView.moveCurrentIndexDown()
                        Keys.onUpPressed: gridView.moveCurrentIndexUp()
                        Keys.onEscapePressed: rootWindow.show = false
                        Keys.onReturnPressed: applyCurrent()
                        Keys.onEnterPressed: applyCurrent()
                    }

                    GridView {
                        id: gridView
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        cellWidth: 174
                        cellHeight: 141
                        keyNavigationWraps: true
                        onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, GridView.Contain)

                        Text {
                            anchors.centerIn: parent
                            visible: wallpaperModel.count === 0 && searchInput.text.length > 0
                            text: "NO MATCH"
                            color: shellRoot ? shellRoot.colMuted : "#888"
                            font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                            font.pixelSize: 14
                            font.bold: true
                            font.letterSpacing: 2
                        }

                        model: ListModel { id: wallpaperModel }

                        delegate: Item {
                            width: GridView.view.cellWidth
                            height: GridView.view.cellHeight

                            Rectangle {
                                id: card
                                anchors.fill: parent
                                anchors.margins: 6
                                radius: 0
                                readonly property bool selected: index === gridView.currentIndex
                                color: (ma.containsMouse || selected) ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                                border.color: selected ? rootWindow.chrome : ma.containsMouse ? rootWindow.chromeA(0.6) : rootWindow.chromeA(0.2)
                                border.width: 1
                                clip: true

                                Image {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    height: 99
                                    source: "file://" + model.thumb
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    asynchronous: true
                                    sourceSize.width: 300
                                    sourceSize.height: 99
                                }

                                Text {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottomMargin: 8
                                    anchors.leftMargin: 6
                                    anchors.rightMargin: 6
                                    text: model.name
                                    color: shellRoot ? shellRoot.colFg : "white"
                                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                                    font.pixelSize: 14
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: ma
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: rootWindow.applyWallpaper(model.path)
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
