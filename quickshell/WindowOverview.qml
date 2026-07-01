import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland

PanelWindow {
    id: rootWindow

    property bool show: false
    property var shellRoot
    property int currentWs: 1
    property string searchText: ""

    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: show

    onShowChanged: {
        if (show) {
            currentWs = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
            searchText = ""
            focusTimer.start()
        } else {
            contextMenu.close()
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: searchInput.forceActiveFocus()
    }

    Process { id: pMoveWs }
    function moveWindowToWorkspace(win, wsId) {
        if (!win || !win.address) return
        pMoveWs.command = ["hyprctl", "dispatch", "movetoworkspacesilent", wsId + ",address:" + win.address]
        pMoveWs.running = true
    }

    function matchesSearch(win) {
        if (searchText.length === 0) return true
        var q = searchText.toLowerCase()
        var t = (win.title || "").toLowerCase()
        var a = (win.wayland && win.wayland.appId ? win.wayland.appId : "").toLowerCase()
        return t.indexOf(q) !== -1 || a.indexOf(q) !== -1
    }

    function activateFirstMatch() {
        if (searchText.length === 0) return
        if (!Hyprland.toplevels || !Hyprland.toplevels.values) return
        var list = Hyprland.toplevels.values
        for (var i = 0; i < list.length; i++) {
            var w = list[i]
            if (w.wayland && !w.wayland.minimized && matchesSearch(w)) {
                rootWindow.show = false
                w.wayland.activate()
                return
            }
        }
    }

    Item {
        id: overviewRoot
        anchors.fill: parent
        focus: show

        Keys.onEscapePressed: {
            if (contextMenu.visible) contextMenu.close()
            else rootWindow.show = false
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.80)
            MouseArea {
                anchors.fill: parent
                onClicked: rootWindow.show = false
            }
        }

        // workspace dot bar
        Row {
            id: dotBar
            z: 5
            anchors.top: parent.top
            anchors.topMargin: 24
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            Repeater {
                model: 10

                delegate: Rectangle {
                    id: dot
                    property int wsId: index + 1
                    property var wsData: Hyprland.workspaces.values.find(w => w.id === wsId)

                    width: 34
                    height: 34
                    radius: 17
                    color: rootWindow.currentWs === wsId
                           ? (shellRoot ? shellRoot.colAccent : "#007AFF")
                           : dropArea.containsDrag
                             ? Qt.rgba(1, 1, 1, 0.30)
                             : dotMa.containsMouse
                               ? Qt.rgba(1, 1, 1, 0.18)
                               : Qt.rgba(1, 1, 1, wsData ? 0.10 : 0.05)
                    border.width: dropArea.containsDrag ? 2 : 0
                    border.color: shellRoot ? shellRoot.colAccent : "#007AFF"
                    scale: dropArea.containsDrag ? 1.15 : 1.0

                    Behavior on scale { NumberAnimation { duration: shellRoot && shellRoot.batteryMode ? 0 : 120 } }
                    Behavior on color { ColorAnimation { duration: shellRoot && shellRoot.batteryMode ? 0 : 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: dot.wsId
                        font.bold: true
                        font.pixelSize: 13
                        font.family: shellRoot ? shellRoot.fontFamily : "monospace"
                        color: rootWindow.currentWs === dot.wsId ? "#000" : (shellRoot ? shellRoot.colFg : "#fff")
                    }

                    MouseArea {
                        id: dotMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: rootWindow.currentWs = dot.wsId
                    }

                    DropArea {
                        id: dropArea
                        anchors.fill: parent
                        keys: ["window"]
                        onDropped: (drop) => {
                            if (drop.source && drop.source.winRef) {
                                rootWindow.moveWindowToWorkspace(drop.source.winRef, dot.wsId)
                            }
                        }
                    }
                }
            }
        }

        // search bar — filters windows by title/appId across all workspaces
        Rectangle {
            id: searchBar
            z: 5
            anchors.top: dotBar.bottom
            anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            width: 360
            height: 44
            radius: 22
            color: Qt.rgba(0.08, 0.08, 0.08, 0.92)
            border.color: searchInput.activeFocus ? (shellRoot ? shellRoot.colAccent : "#007AFF") : Qt.rgba(1, 1, 1, 0.12)
            border.width: 1

            MouseArea {
                anchors.fill: parent
                onClicked: searchInput.forceActiveFocus()
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: "󰍉"
                color: shellRoot ? shellRoot.colMuted : "#888"
                font.family: shellRoot ? shellRoot.fontFamily : "monospace"
                font.pixelSize: 15
            }

            Text {
                visible: searchInput.text.length === 0
                anchors.left: parent.left
                anchors.leftMargin: 42
                anchors.verticalCenter: parent.verticalCenter
                text: "Search..."
                color: shellRoot ? shellRoot.colMuted : "#888"
                font.family: shellRoot ? shellRoot.fontFamily : "monospace"
                font.pixelSize: 13
            }

            TextInput {
                id: searchInput
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 42
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                color: shellRoot ? shellRoot.colFg : "#fff"
                font.family: shellRoot ? shellRoot.fontFamily : "monospace"
                font.pixelSize: 13
                focus: rootWindow.show
                text: rootWindow.searchText
                onTextChanged: rootWindow.searchText = text

                Keys.onEscapePressed: {
                    if (contextMenu.visible) contextMenu.close()
                    else if (text.length > 0) text = ""
                    else rootWindow.show = false
                }
                Keys.onReturnPressed: rootWindow.activateFirstMatch()
            }
        }

        Flow {
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                topMargin: 134
                leftMargin: 60
                rightMargin: 60
                bottomMargin: 60
            }
            spacing: 24

            Repeater {
                model: Hyprland.toplevels

                delegate: Rectangle {
                    id: card
                    required property var modelData

                    // when searching, match across all workspaces; otherwise show only the selected workspace
                    visible: modelData.wayland && !modelData.wayland.minimized
                             && (rootWindow.searchText.length > 0
                                 ? rootWindow.matchesSearch(modelData)
                                 : modelData.workspace && modelData.workspace.id === rootWindow.currentWs)
                    width: 400
                    height: visible ? 280 : 0
                    radius: 12
                    clip: true
                    opacity: ghost.visible && ghost.winRef === modelData ? 0.3 : 1.0
                    color: cardMa.containsMouse
                           ? Qt.rgba(1, 1, 1, 0.12)
                           : Qt.rgba(0.05, 0.05, 0.05, 0.92)
                    border.color: modelData.activated
                                  ? (shellRoot ? shellRoot.colAccent : "#007AFF")
                                  : Qt.rgba(1, 1, 1, 0.12)
                    border.width: modelData.activated ? 2 : 1

                    Behavior on color {
                        ColorAnimation { duration: shellRoot && shellRoot.batteryMode ? 0 : 150 }
                    }
                    scale: cardMa.containsPress ? 0.95 : 1.0
                    Behavior on scale {
                        NumberAnimation { duration: shellRoot && shellRoot.batteryMode ? 0 : 100 }
                    }

                    ScreencopyView {
                        id: scv
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: parent.height - 56
                        captureSource: modelData.wayland
                        live: false
                        // prevent ScreencopyView from swallowing pointer events
                        enabled: false
                    }

                    // fallback icon when screencopy has no content
                    Text {
                        visible: !scv.hasContent
                        anchors.centerIn: scv
                        text: "󰕹"
                        color: Qt.rgba(1, 1, 1, 0.2)
                        font.family: shellRoot ? shellRoot.fontFamily : "monospace"
                        font.pixelSize: 56
                    }

                    // workspace badge, shown while searching across all workspaces
                    Rectangle {
                        visible: rootWindow.searchText.length > 0 && modelData.workspace
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 8
                        width: 24
                        height: 24
                        radius: 12
                        color: Qt.rgba(0, 0, 0, 0.7)
                        border.color: shellRoot ? shellRoot.colAccent : "#007AFF"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData.workspace ? modelData.workspace.id : ""
                            color: shellRoot ? shellRoot.colFg : "#fff"
                            font.bold: true
                            font.pixelSize: 11
                            font.family: shellRoot ? shellRoot.fontFamily : "monospace"
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 56
                        color: Qt.rgba(0, 0, 0, 0.65)

                        ColumnLayout {
                            anchors {
                                left: parent.left
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                                margins: 10
                            }
                            spacing: 2

                            Text {
                                text: modelData.title
                                color: shellRoot ? shellRoot.colFg : "#fff"
                                font.family: shellRoot ? shellRoot.fontFamily : "monospace"
                                font.pixelSize: 14
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: modelData.wayland ? modelData.wayland.appId : ""
                                color: shellRoot ? shellRoot.colMuted : "#888"
                                font.family: shellRoot ? shellRoot.fontFamily : "monospace"
                                font.pixelSize: 11
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    MouseArea {
                        id: cardMa
                        anchors.fill: parent
                        z: 10
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        drag.target: ghost
                        drag.threshold: 8

                        onPressed: (mouse) => {
                            if (mouse.button !== Qt.LeftButton) return
                            var g = card.mapToItem(overviewRoot, 0, 0)
                            ghost.x = g.x
                            ghost.y = g.y
                            ghost.width = card.width
                            ghost.height = card.height
                            ghost.title = modelData.title
                            ghost.winRef = modelData
                            ghost.visible = true
                        }
                        onReleased: ghost.visible = false

                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton) {
                                var pos = card.mapToItem(overviewRoot, mouse.x, mouse.y)
                                contextMenu.openFor(modelData, pos)
                            } else {
                                rootWindow.show = false
                                if (modelData.wayland) modelData.wayland.activate()
                            }
                        }
                    }
                }
            }
        }

        // drag ghost proxy, lives outside the Flow so it can move freely
        Rectangle {
            id: ghost
            z: 50
            visible: false
            radius: 12
            color: Qt.rgba(0.05, 0.05, 0.05, 0.92)
            border.color: shellRoot ? shellRoot.colAccent : "#007AFF"
            border.width: 2

            property var winRef: null
            property string title: ""

            Drag.active: visible
            Drag.keys: ["window"]
            Drag.hotSpot: Qt.point(width / 2, height / 2)

            Text {
                anchors.centerIn: parent
                anchors.margins: 8
                width: parent.width - 16
                text: ghost.title
                color: shellRoot ? shellRoot.colFg : "#fff"
                font.family: shellRoot ? shellRoot.fontFamily : "monospace"
                font.pixelSize: 11
                font.bold: true
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }

        // right-click context menu
        Rectangle {
            id: contextMenu
            z: 100
            visible: false
            width: 200
            height: menuCol.implicitHeight + 16
            radius: 12
            color: Qt.rgba(0.08, 0.08, 0.08, 0.97)
            border.color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1

            property var targetWindow: null

            function openFor(win, pos) {
                targetWindow = win
                x = Math.min(pos.x, overviewRoot.width - width - 10)
                y = Math.min(pos.y, overviewRoot.height - height - 10)
                visible = true
            }
            function close() {
                visible = false
                targetWindow = null
            }

            MouseArea {
                // swallow clicks so the backdrop doesn't close the overview
                anchors.fill: parent
            }

            ColumnLayout {
                id: menuCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 8
                    color: closeMa.containsMouse ? Qt.rgba(1, 0.2, 0.2, 0.25) : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Close Window"
                        color: shellRoot ? shellRoot.colFg : "#fff"
                        font.family: shellRoot ? shellRoot.fontFamily : "monospace"
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: closeMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (contextMenu.targetWindow && contextMenu.targetWindow.wayland) {
                                contextMenu.targetWindow.wayland.close()
                            }
                            contextMenu.close()
                        }
                    }
                }

                Text {
                    text: "Move to workspace..."
                    color: shellRoot ? shellRoot.colMuted : "#888"
                    font.family: shellRoot ? shellRoot.fontFamily : "monospace"
                    font.pixelSize: 10
                    Layout.topMargin: 4
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: 10

                        delegate: Rectangle {
                            id: wsBtn
                            property int wsId: index + 1
                            width: 28
                            height: 28
                            radius: 14
                            color: wsMa.containsMouse
                                   ? (shellRoot ? shellRoot.colAccent : "#007AFF")
                                   : Qt.rgba(1, 1, 1, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: wsBtn.wsId
                                color: shellRoot ? shellRoot.colFg : "#fff"
                                font.family: shellRoot ? shellRoot.fontFamily : "monospace"
                                font.pixelSize: 11
                            }

                            MouseArea {
                                id: wsMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (contextMenu.targetWindow) {
                                        rootWindow.moveWindowToWorkspace(contextMenu.targetWindow, wsBtn.wsId)
                                    }
                                    contextMenu.close()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
