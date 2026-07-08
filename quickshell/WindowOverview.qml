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
    property bool showSpecial: false
    property int selCell: 0
    property string prevFocusAddr: ""

    // hide LINE's stray "explorer.exe" helper window — shouldn't show up in the overview
    function isHiddenWindow(w) {
        var appId = (w.wayland && w.wayland.appId ? w.wayland.appId : "").toLowerCase()
        var title = (w.title || "").toLowerCase()
        return appId.indexOf("explorer.exe") !== -1 || title.indexOf("explorer.exe") !== -1
    }

    // windows for a single normal workspace (1-10)
    function windowsForWorkspace(wsId) {
        if (!Hyprland.toplevels || !Hyprland.toplevels.values) return []
        var list = Hyprland.toplevels.values
        var result = []
        for (var i = 0; i < list.length; i++) {
            var w = list[i]
            if (!w.wayland || w.wayland.minimized) continue
            if (!w.workspace || w.workspace.id !== wsId) continue
            if (rootWindow.isHiddenWindow(w)) continue
            result.push(w)
        }
        return result
    }

    // 10 fixed cells, workspace 1-10, laid out 5 across / 2 down
    property var wsGroups: {
        var result = []
        for (var wsId = 1; wsId <= 10; wsId++) {
            result.push({ wsId: wsId, windows: rootWindow.windowsForWorkspace(wsId) })
        }
        return result
    }

    property var specialWindows: {
        if (!Hyprland.toplevels || !Hyprland.toplevels.values) return []
        var list = Hyprland.toplevels.values
        var result = []
        for (var i = 0; i < list.length; i++) {
            var w = list[i]
            if (!w.wayland || w.wayland.minimized) continue
            if (!w.workspace || w.workspace.id >= 0) continue
            if (rootWindow.isHiddenWindow(w)) continue
            result.push(w)
        }
        return result
    }

    // split `windows` into rows that each stretch to fill the full cell width — every
    // row is completely used (no partial-row gap), and row height is capped so lone
    // windows don't blow up to fill the whole cell vertically
    function buildThumbRows(windows, cellW, cellH, maxItemH) {
        var n = windows.length
        if (n === 0 || cellW <= 0 || cellH <= 0) return []
        var targetRows = Math.min(n, Math.max(1, Math.ceil(cellH / maxItemH)))
        var itemH = Math.min(maxItemH, cellH / targetRows)
        var rows = []
        var remaining = n
        var idx = 0
        for (var r = 0; r < targetRows; r++) {
            var rowsLeft = targetRows - r
            var countInRow = Math.ceil(remaining / rowsLeft)
            rows.push({ items: windows.slice(idx, idx + countInRow), itemW: cellW / countInRow, itemH: itemH })
            idx += countInRow
            remaining -= countInRow
        }
        return rows
    }

    Process { id: pMoveWs }
    function moveWindowToWorkspace(win, wsId) {
        if (!win || !win.address) return
        pMoveWs.command = ["hyprctl", "dispatch", "movetoworkspacesilent", wsId + ",address:" + win.address]
        pMoveWs.running = true
    }

    Process { id: pFocusWs }
    function focusWorkspace(wsId) {
        pFocusWs.command = ["hyprctl", "dispatch", "workspace", String(wsId)]
        pFocusWs.running = true
    }

    // the qs-overview layer takes keyboard focus (WlrKeyboardFocus.OnDemand) while shown;
    // Hyprland doesn't always hand it back cleanly on close (e.g. Firefox stops receiving
    // keystrokes), so track and explicitly restore focus when the user backs out without
    // picking anything
    Process { id: pRestoreFocus }
    function restoreFocus() {
        if (!prevFocusAddr) return
        pRestoreFocus.command = ["hyprctl", "dispatch", "focuswindow", "address:" + prevFocusAddr]
        pRestoreFocus.running = true
        prevFocusAddr = ""
    }

    onShowChanged: {
        if (show) {
            showSpecial = false
            var fw = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
            selCell = Math.max(0, Math.min(9, fw - 1))
            prevFocusAddr = ""
            if (Hyprland.toplevels && Hyprland.toplevels.values) {
                var list = Hyprland.toplevels.values
                for (var i = 0; i < list.length; i++) {
                    if (list[i].activated) { prevFocusAddr = list[i].address; break }
                }
            }
        } else {
            contextMenu.close()
            rootWindow.restoreFocus()
        }
    }

    function moveSelCell(delta) {
        selCell = Math.max(0, Math.min(9, selCell + delta))
    }

    function activateSelectedCell() {
        var cell = rootWindow.wsGroups[selCell]
        if (!cell) return
        prevFocusAddr = "" // we're about to focus something specific, don't let onShowChanged undo it
        rootWindow.show = false
        if (cell.windows.length > 0 && cell.windows[0].wayland) {
            cell.windows[0].wayland.activate()
        } else {
            rootWindow.focusWorkspace(cell.wsId)
        }
    }

    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-overview"
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: show

    Item {
        id: overviewRoot
        anchors.fill: parent
        focus: show

        Keys.onEscapePressed: {
            if (contextMenu.visible) contextMenu.close()
            else rootWindow.show = false
        }
        Keys.onLeftPressed: rootWindow.moveSelCell(-1)
        Keys.onRightPressed: rootWindow.moveSelCell(1)
        Keys.onUpPressed: rootWindow.moveSelCell(-5)
        Keys.onDownPressed: rootWindow.moveSelCell(5)
        Keys.onReturnPressed: rootWindow.activateSelectedCell()
        Keys.onTabPressed: rootWindow.showSpecial = !rootWindow.showSpecial
        Keys.onBacktabPressed: rootWindow.showSpecial = !rootWindow.showSpecial

        // full-screen backdrop — blurred via the qs-overview layer_rule (see hypr/lua/windowrules.lua);
        // alpha kept low so it reads as a blur, not a dim
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.05)
        }

        // click-away backdrop
        MouseArea {
            anchors.fill: parent
            onClicked: rootWindow.show = false
        }

        Rectangle {
            id: gridPanel
            anchors.centerIn: parent
            width: 1320
            height: 380
            radius: 36
                color: Qt.rgba(0.07, 0.07, 0.07, 0.55)
                border.color: Qt.rgba(1, 1, 1, 0.10)
                border.width: 1

                // swallow clicks so the backdrop doesn't close the overview
                MouseArea { anchors.fill: parent }

                // pinned/special-workspace toggle (magic, note, keepass, line, kontact...)
                Rectangle {
                    id: pinBtn
                    z: 5
                    width: 42
                    height: 42
                    radius: 21
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 16
                    color: rootWindow.showSpecial
                           ? (shellRoot ? shellRoot.colAccent : "#007AFF")
                           : pinMa.containsMouse
                             ? Qt.rgba(1, 1, 1, 0.18)
                             : Qt.rgba(1, 1, 1, 0.08)

                    Text {
                        anchors.centerIn: parent
                        text: "󰐃"
                        font.pixelSize: 19
                        font.family: shellRoot ? shellRoot.fontFamily : "monospace"
                        color: rootWindow.showSpecial ? "#000" : (shellRoot ? shellRoot.colFg : "#fff")
                    }

                    MouseArea {
                        id: pinMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: rootWindow.showSpecial = !rootWindow.showSpecial
                    }
                }

                GridLayout {
                    visible: !rootWindow.showSpecial
                    anchors.fill: parent
                    anchors.margins: 32
                    columns: 5
                    rows: 2
                    columnSpacing: 20
                    rowSpacing: 20

                    Repeater {
                        model: rootWindow.wsGroups

                        delegate: Rectangle {
                            id: wsCell
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 10
                            color: wsCell.modelData.windows.length > 0 ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.03)
                            border.color: rootWindow.selCell === index ? "#ffffff" : Qt.rgba(1, 1, 1, 0.10)
                            border.width: rootWindow.selCell === index ? 2 : 1

                            // empty workspace — just the number, click to switch
                            Item {
                                anchors.fill: parent
                                visible: wsCell.modelData.windows.length === 0

                                Text {
                                    anchors.centerIn: parent
                                    text: wsCell.modelData.wsId
                                    color: shellRoot ? shellRoot.colMuted : "#888"
                                    font.family: shellRoot ? shellRoot.fontFamily : "monospace"
                                    font.pixelSize: 30
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        rootWindow.prevFocusAddr = ""
                                        rootWindow.show = false
                                        rootWindow.focusWorkspace(wsCell.modelData.wsId)
                                    }
                                }
                            }

                            // occupied workspace — live thumbnail(s)
                            Item {
                                id: thumbArea
                                visible: wsCell.modelData.windows.length > 0
                                anchors.fill: parent
                                anchors.margins: 3

                                property var rows: rootWindow.buildThumbRows(wsCell.modelData.windows, width, height, height)

                                Column {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    spacing: 3

                                    Repeater {
                                        model: thumbArea.rows

                                        delegate: Row {
                                            id: rowItem
                                            required property var modelData
                                            width: thumbArea.width
                                            height: rowItem.modelData.itemH
                                            spacing: 3

                                            Repeater {
                                                model: rowItem.modelData.items

                                                delegate: Rectangle {
                                                    id: thumb
                                                    required property var modelData
                                                    width: rowItem.modelData.itemW - 3
                                                    height: rowItem.modelData.itemH
                                                    radius: 6
                                                    clip: true
                                                    color: Qt.rgba(0.02, 0.02, 0.02, 0.9)
                                                    border.color: modelData.activated
                                                                  ? (shellRoot ? shellRoot.colAccent : "#007AFF")
                                                                  : Qt.rgba(1, 1, 1, 0.10)
                                                    border.width: 1

                                                    ScreencopyView {
                                                        id: scv
                                                        captureSource: modelData.wayland
                                                        live: false
                                                        enabled: false

                                                        readonly property real srcAspect: sourceSize.height > 0 ? sourceSize.width / sourceSize.height : (thumb.width / thumb.height)
                                                        readonly property real dstAspect: thumb.width / thumb.height

                                                        anchors.centerIn: parent
                                                        width: srcAspect > dstAspect ? thumb.height * srcAspect : thumb.width
                                                        height: srcAspect > dstAspect ? thumb.height : thumb.width / srcAspect
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                        onClicked: (mouse) => {
                                                            if (mouse.button === Qt.RightButton) {
                                                                var pos = thumb.mapToItem(overviewRoot, mouse.x, mouse.y)
                                                                contextMenu.openFor(modelData, pos)
                                                            } else {
                                                                rootWindow.prevFocusAddr = ""
                                                                rootWindow.show = false
                                                                if (modelData.wayland) modelData.wayland.activate()
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // small dot marking the currently active workspace's focused window
                                Rectangle {
                                    visible: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsCell.modelData.wsId
                                    width: 5
                                    height: 5
                                    radius: 2.5
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.bottomMargin: -2
                                    color: shellRoot ? shellRoot.colAccent : "#007AFF"
                                }
                            }
                        }
                    }
                }

                // pinned/special workspace content — fixed-size cards, wraps instead of resizing per count
                Item {
                    id: specialArea
                    visible: rootWindow.showSpecial
                    anchors.fill: parent
                    anchors.margins: 32

                    Flow {
                        anchors.centerIn: parent
                        width: specialArea.width
                        spacing: 12

                        Repeater {
                            model: rootWindow.specialWindows

                            delegate: Rectangle {
                                id: specThumb
                                required property var modelData
                                width: 240
                                height: 166
                                radius: 10
                                clip: true
                                color: Qt.rgba(0.02, 0.02, 0.02, 0.9)
                                border.color: modelData.activated
                                              ? (shellRoot ? shellRoot.colAccent : "#007AFF")
                                              : Qt.rgba(1, 1, 1, 0.12)
                                border.width: 1

                                ScreencopyView {
                                    id: specScv
                                    captureSource: modelData.wayland
                                    live: false
                                    enabled: false

                                    readonly property real srcAspect: sourceSize.height > 0 ? sourceSize.width / sourceSize.height : (specThumb.width / specThumb.height)
                                    readonly property real dstAspect: specThumb.width / specThumb.height

                                    anchors.centerIn: parent
                                    width: srcAspect > dstAspect ? specThumb.height * srcAspect : specThumb.width
                                    height: srcAspect > dstAspect ? specThumb.height : specThumb.width / srcAspect
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            var pos = specThumb.mapToItem(overviewRoot, mouse.x, mouse.y)
                                            contextMenu.openFor(modelData, pos)
                                        } else {
                                            rootWindow.prevFocusAddr = ""
                                            rootWindow.show = false
                                            if (modelData.wayland) modelData.wayland.activate()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: rootWindow.specialWindows.length === 0
                        anchors.centerIn: parent
                        text: "No pinned windows"
                        color: shellRoot ? shellRoot.colMuted : "#888"
                        font.family: shellRoot ? shellRoot.fontFamily : "monospace"
                        font.pixelSize: 16
                    }
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
