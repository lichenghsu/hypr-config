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

    // Drag-to-move-workspace state: dragging a thumbnail from one grid cell
    // onto another moves that window to the dropped-on workspace.
    property bool dragging: false
    property var dragWin: null
    property real dragGhostX: 0
    property real dragGhostY: 0

    // 1. Helper to filter out helper/stray windows (like LINE's "explorer.exe")
    // these shouldn't be rendered as thumbnails in our workspace overview.
    function isHiddenWindow(w) {
        var appId = (w.wayland && w.wayland.appId ? w.wayland.appId : "").toLowerCase()
        var title = (w.title || "").toLowerCase()
        return appId.indexOf("explorer.exe") !== -1 || title.indexOf("explorer.exe") !== -1
    }

    // 2. Filters the global toplevels list for windows belonging to a specific normal workspace (1-10)
    function windowsForWorkspace(wsId, toplevelsList) {
        if (!toplevelsList) return []
            var result = []
            for (var i = 0; i < toplevelsList.length; i++) {
                var w = toplevelsList[i]
                if (!w.wayland || w.wayland.minimized) continue
                    if (!w.workspace || w.workspace.id !== wsId) continue
                        if (rootWindow.isHiddenWindow(w)) continue
                            result.push(w)
            }
            return result
    }

    // 3. Reactively binds and groups windows into workspaces 1-10.
    // Making this a 'readonly property' bound directly to 'Hyprland.toplevels.values' ensures
    // QML updates this model automatically whenever windows open, close, or move.
    readonly property var wsGroups: {
        var list = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        var result = []
        for (var wsId = 1; wsId <= 10; wsId++) {
            result.push({
                wsId: wsId,
                windows: rootWindow.windowsForWorkspace(wsId, list)
            })
        }
        return result
    }

    // 4. Reactively updates the list of windows in the special workspace (scratchpad).
    // Note: Hyprland uses negative IDs (e.g., -99) for special/scratchpad workspaces.
    readonly property var specialWindows: {
        var list = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : [];
        var result = []
        for (var i = 0; i < list.length; i++) {
            var w = list[i]
            if (!w.wayland || w.wayland.minimized) continue
                if (!w.workspace || w.workspace.id >= 0) continue // Skip normal workspaces
                    if (rootWindow.isHiddenWindow(w)) continue
                        result.push(w)
        }
        return result
    }

    // 5. Splits a list of windows into rows that dynamically scale and stretch
    // to fit the parent cell width, preventing single windows from expanding vertically.
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

    // 6. IPC Processes to safely dispatch commands to Hyprland via hyprctl.
    // Moving a window to another workspace silently (without switching user focus)
    Process { id: pMoveWs }
    function moveWindowToWorkspace(win, wsId) {
        if (!win || !win.address) return
            pMoveWs.command = ["hyprctl", "dispatch", "hl.dsp.window.move({workspace = " + wsId + ", follow = false, window = hl.get_window(\"address:" + win.address + "\")})"]
            pMoveWs.running = true
    }

    // Focuses the chosen workspace
    Process { id: pFocusWs }
    function focusWorkspace(wsId) {
        pFocusWs.command = ["hyprctl", "dispatch", "hl.dsp.focus({workspace = " + wsId + "})"]
        pFocusWs.running = true
    }

    // Restores keyboard focus to the window that was active before opening the overview overlay
    Process { id: pRestoreFocus }
    function restoreFocus() {
        if (!prevFocusAddr) return
            pRestoreFocus.command = ["hyprctl", "dispatch", "hl.dsp.focus({window = hl.get_window(\"address:" + prevFocusAddr + "\")})"]
            pRestoreFocus.running = true
            prevFocusAddr = ""
    }

    // Switches focus to a specific window (native Quickshell handle, no hyprctl round-trip needed)
    function activateWindow(win) {
        if (!win || !win.wayland) return
            win.wayland.activate()
    }

    // Resetting state and tracking focus when the overview window opens or closes
    onShowChanged: {
        if (show) {
            showSpecial = false
            var fw = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
            // Clamp current workspace index between 0 and 9 (corresponds to workspaces 1-10)
            selCell = Math.max(0, Math.min(9, fw - 1))
            prevFocusAddr = ""
            if (Hyprland.toplevels && Hyprland.toplevels.values) {
                var list = Hyprland.toplevels.values
                for (var i = 0; i < list.length; i++) {
                    if (list[i].activated) { prevFocusAddr = list[i].address; break }
                }
            }
        } else {
            commitTimer.stop()
            contextMenu.close()
            rootWindow.restoreFocus()
        }
    }

    // Pause-to-commit: Switches to the selected cell automatically after
    // keyboard navigation settles for a brief moment, eliminating the need to press Enter.
    Timer {
        id: commitTimer
        interval: 1000
        repeat: false
        onTriggered: rootWindow.activateSelectedCell()
    }

    // Keyboard cell selection navigation
    function moveSelCell(delta) {
        selCell = ((selCell + delta) % 10 + 10) % 10
        commitTimer.restart()
    }

    // Confirms and executes the action on the selected workspace cell
    function activateSelectedCell() {
        var cell = rootWindow.wsGroups[selCell]
        if (!cell) return
            prevFocusAddr = "" // Target window selected, override restoreFocus
            rootWindow.show = false
            if (cell.windows.length > 0 && cell.windows[0].wayland) {
                rootWindow.activateWindow(cell.windows[0])
            } else {
                rootWindow.focusWorkspace(cell.wsId)
            }
    }

    // 7. Window/Layer shell constraints (using overlay to capture shortcuts globally)
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

        // Global Keybindings
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

        // Backdrop tint (dim effect)
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.05)
        }

        // Click outside the panel to close
        MouseArea {
            anchors.fill: parent
            onClicked: rootWindow.show = false
        }

        // Main Grid Panel
        Rectangle {
            id: gridPanel
            anchors.centerIn: parent
            width: 1320
            height: 380
            radius: 36
            color: Qt.rgba(0.07, 0.07, 0.07, 0.55)
            border.color: Qt.rgba(1, 1, 1, 0.10)
            border.width: 1

            // Prevent backdrop mouse area from stealing clicks on the panel
            MouseArea { anchors.fill: parent }

            // Special Workspace Toggle Button (Top-Right)
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

            // Normal Workspaces Layout (1 to 10 in a 5x2 grid)
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
                        property bool dropHighlight: false
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 10
                        color: wsCell.dropHighlight
                        ? Qt.rgba(1, 1, 1, 0.14)
                        : wsCell.modelData.windows.length > 0 ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.03)
                        border.color: wsCell.dropHighlight
                        ? (shellRoot ? shellRoot.colAccent : "#007AFF")
                        : rootWindow.selCell === index ? "#ffffff" : Qt.rgba(1, 1, 1, 0.10)
                        border.width: wsCell.dropHighlight || rootWindow.selCell === index ? 2 : 1

                        // Accepts a dropped thumbnail (rootWindow.dragWin) and moves that window here.
                        DropArea {
                            anchors.fill: parent
                            onEntered: wsCell.dropHighlight = true
                            onExited: wsCell.dropHighlight = false
                            onDropped: {
                                wsCell.dropHighlight = false
                                if (rootWindow.dragWin) {
                                    rootWindow.moveWindowToWorkspace(rootWindow.dragWin, wsCell.modelData.wsId)
                                }
                            }
                        }

                        // Render empty workspace state (just display the workspace number)
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

                        // Render occupied workspace state (displaying live preview thumbnails)
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

                                                // Wayland Screencopy view for live window thumbnails
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
                                                    id: thumbMa
                                                    anchors.fill: parent
                                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                                    property real pressX: 0
                                                    property real pressY: 0
                                                    property bool didDrag: false

                                                    onPressed: (mouse) => {
                                                        pressX = mouse.x
                                                        pressY = mouse.y
                                                        didDrag = false
                                                    }
                                                    onPositionChanged: (mouse) => {
                                                        if (mouse.buttons !== Qt.LeftButton) return
                                                            var dx = mouse.x - pressX
                                                            var dy = mouse.y - pressY
                                                            if (!didDrag && Math.sqrt(dx * dx + dy * dy) > 8) {
                                                                didDrag = true
                                                                rootWindow.dragging = true
                                                                rootWindow.dragWin = modelData
                                                            }
                                                            if (rootWindow.dragging) {
                                                                var gp = thumbMa.mapToItem(overviewRoot, mouse.x, mouse.y)
                                                                rootWindow.dragGhostX = gp.x
                                                                rootWindow.dragGhostY = gp.y
                                                            }
                                                    }
                                                    onReleased: (mouse) => {
                                                        if (rootWindow.dragging) {
                                                            dragGhost.Drag.drop()
                                                            rootWindow.dragging = false
                                                            rootWindow.dragWin = null
                                                        }
                                                    }
                                                    onClicked: (mouse) => {
                                                        if (didDrag) { didDrag = false; return }
                                                            if (mouse.button === Qt.RightButton) {
                                                                var pos = thumb.mapToItem(overviewRoot, mouse.x, mouse.y)
                                                                contextMenu.openFor(modelData, pos)
                                                            } else {
                                                                rootWindow.prevFocusAddr = ""
                                                                rootWindow.show = false
                                                                rootWindow.activateWindow(modelData)
                                                            }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Small dot visual feedback to mark the currently focused workspace
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

            // Pinned/Special Workspace Panel
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
                                        rootWindow.activateWindow(modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                // Empty Special Workspace notice
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

        // Floating ghost thumbnail shown while dragging a window onto another workspace cell
        Rectangle {
            id: dragGhost
            z: 200
            visible: rootWindow.dragging
            width: 160
            height: 100
            x: rootWindow.dragGhostX - width / 2
            y: rootWindow.dragGhostY - height / 2
            radius: 8
            color: Qt.rgba(0.05, 0.05, 0.05, 0.85)
            border.width: 2
            border.color: shellRoot ? shellRoot.colAccent : "#007AFF"
            opacity: 0.85

            Drag.active: rootWindow.dragging
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2
        }

        // Right-Click Context Menu (For closing and moving windows)
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

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: menuCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4

                // Option: Close Window
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

                // Grid Flow of buttons (Workspaces 1 to 10) for window redirection
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
