import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
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
    // Snapshot of wsGroups taken when a drag starts. wsGroups rebuilds from
    // scratch (new arrays/objects) on every Hyprland.toplevels change, which
    // makes the Repeater below tear down and recreate all thumbnail delegates
    // - including the one currently grabbed by the mouse - so an unrelated
    // window-list update mid-drag can silently hand the gesture off to
    // whatever tile ends up under the cursor. Freezing the grid to this
    // snapshot while dragging keeps delegate identity (and the mouse grab)
    // stable until the drop completes.
    property var dragSnapshot: null

    // 1. Helper to filter out helper/stray windows (like LINE's "explorer.exe")
    function isHiddenWindow(w) {
        if (!w || !w.wayland) return true
            const appId = (w.wayland.appId || "").toLowerCase()
            const title = (w.title || "").toLowerCase()
            return appId.indexOf("explorer.exe") !== -1 || title.indexOf("explorer.exe") !== -1
    }

    // 2. Reactively binds and groups windows into workspaces 1-10.
    // Using Array.filter for better performance and readability.
    readonly property var wsGroups: {
        const list = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : []
        const result = []
        for (let wsId = 1; wsId <= 10; wsId++) {
            result.push({
                wsId: wsId,
                windows: list.filter(w =>
                w.workspace &&
                w.workspace.id === wsId &&
                w.wayland &&
                !w.wayland.minimized &&
                !rootWindow.isHiddenWindow(w)
                )
            })
        }
        return result
    }

    // Grid delegates bind to this instead of wsGroups directly, so the grid
    // stays frozen (see dragSnapshot above) while a drag is in progress.
    readonly property var displayWsGroups: (rootWindow.dragging && rootWindow.dragSnapshot) ? rootWindow.dragSnapshot : rootWindow.wsGroups

    // 3. Reactively updates the list of windows in the special workspace (scratchpad).
    readonly property var specialWindows: {
        const list = (Hyprland.toplevels && Hyprland.toplevels.values) ? Hyprland.toplevels.values : []
        return list.filter(w =>
        w.workspace &&
        w.workspace.id < 0 &&
        w.wayland &&
        !w.wayland.minimized &&
        !rootWindow.isHiddenWindow(w)
        )
    }

    // 4. Splits a list of windows into rows that dynamically scale and stretch
    function buildThumbRows(windows, cellW, cellH, maxItemH) {
        const n = windows.length
        if (n === 0 || cellW <= 0 || cellH <= 0) return []

            const targetRows = Math.min(n, Math.max(1, Math.ceil(cellH / maxItemH)))
            const itemH = Math.min(maxItemH, cellH / targetRows)
            const rows = []

            let remaining = n
            let idx = 0
            for (let r = 0; r < targetRows; r++) {
                const rowsLeft = targetRows - r
                const countInRow = Math.ceil(remaining / rowsLeft)
                rows.push({
                    items: windows.slice(idx, idx + countInRow),
                          itemW: cellW / countInRow,
                          itemH: itemH
                })
                idx += countInRow
                remaining -= countInRow
            }
            return rows
    }

    // 5. IPC Processes to safely dispatch commands to Hyprland via hyprctl.
    // Quickshell's HyprlandToplevel.address omits the "0x" prefix that
    // hyprctl's own address selectors require ("address:0x...") - without
    // it, hl.get_window() silently returns nil (no error) and the dispatcher
    // falls back to acting on whatever window currently has focus instead.
    function hyprAddress(addr) {
        return addr.indexOf("0x") === 0 ? addr : "0x" + addr
    }

    Process { id: pMoveWs }
    function moveWindowToWorkspace(win, wsId) {
        if (!win || !win.address) return
            pMoveWs.command = ["hyprctl", "dispatch", "hl.dsp.window.move({workspace = " + wsId + ", follow = false, window = hl.get_window(\"address:" + rootWindow.hyprAddress(win.address) + "\")})"]
            pMoveWs.running = true
    }

    Process { id: pFocusWs }
    function focusWorkspace(wsId) {
        pFocusWs.command = ["hyprctl", "dispatch", "hl.dsp.focus({workspace = " + wsId + "})"]
        pFocusWs.running = true
    }

    Process { id: pRestoreFocus }
    function restoreFocus() {
        if (!prevFocusAddr) return
            pRestoreFocus.command = ["hyprctl", "dispatch", "hl.dsp.focus({window = hl.get_window(\"address:" + rootWindow.hyprAddress(prevFocusAddr) + "\")})"]
            pRestoreFocus.running = true
            prevFocusAddr = ""
    }

    function activateWindow(win) {
        if (!win || !win.wayland) return
            win.wayland.activate()
    }

    // 6. Resetting state and tracking focus when the overview window opens or closes
    onShowChanged: {
        if (show) {
            showSpecial = false
            const fw = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
            selCell = Math.max(0, Math.min(9, fw - 1))
            prevFocusAddr = ""

            if (Hyprland.toplevels && Hyprland.toplevels.values) {
                const list = Hyprland.toplevels.values
                const activeWin = list.find(w => w.activated)
                if (activeWin) prevFocusAddr = activeWin.address
            }
        } else {
            commitTimer.stop()
            contextMenu.close()
            rootWindow.restoreFocus()
            rootWindow.dragging = false
            rootWindow.dragWin = null
            rootWindow.dragSnapshot = null
        }
    }

    Timer {
        id: commitTimer
        interval: 1000
        repeat: false
        onTriggered: rootWindow.activateSelectedCell()
    }

    function moveSelCell(delta) {
        selCell = ((selCell + delta) % 10 + 10) % 10
        commitTimer.restart()
    }

    function activateSelectedCell() {
        const cell = rootWindow.wsGroups[selCell]
        if (!cell) return

            prevFocusAddr = "" // Target window selected, override restoreFocus
            rootWindow.show = false

            if (cell.windows.length > 0 && cell.windows[0].wayland) {
                rootWindow.activateWindow(cell.windows[0])
            } else {
                rootWindow.focusWorkspace(cell.wsId)
            }
    }

    // 7. Window/Layer shell constraints
    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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

        // Backdrop tint
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.05)
        }

        MouseArea {
            anchors.fill: parent
            onClicked: rootWindow.show = false
        }

        // Main Grid Panel
        Rectangle {
            id: gridPanel
            anchors.centerIn: parent
            width: 1680
            height: 560
            radius: 2
            color: Qt.rgba(0.07, 0.07, 0.07, 0.55)
            border.color: Qt.rgba(1, 0.42, 0, 0.5)
            border.width: 1

            MouseArea { anchors.fill: parent }

            // Special Workspace Toggle Button
            Rectangle {
                id: pinBtn
                z: 5
                width: 50
                height: 28
                radius: 0
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 16
                color: rootWindow.showSpecial
                ? (shellRoot ? shellRoot.colAccent : "#FF6A00")
                : pinMa.containsMouse
                ? Qt.rgba(1, 1, 1, 0.18)
                : Qt.rgba(1, 1, 1, 0.08)

                Text {
                    anchors.centerIn: parent
                    text: "PIN"
                    font.pixelSize: 10
                    font.bold: true
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

            // Normal Workspaces Layout
            GridLayout {
                visible: !rootWindow.showSpecial
                anchors.fill: parent
                anchors.margins: 32
                columns: 5
                rows: 2
                columnSpacing: 20
                rowSpacing: 20

                Repeater {
                    model: rootWindow.displayWsGroups
                    delegate: Rectangle {
                        id: wsCell
                        required property var modelData
                        required property int index
                        property bool dropHighlight: false

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 0
                        color: wsCell.dropHighlight
                        ? Qt.rgba(1, 1, 1, 0.14)
                        : wsCell.modelData.windows.length > 0 ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(1, 1, 1, 0.03)
                        border.color: wsCell.dropHighlight
                        ? (shellRoot ? shellRoot.colAccent : "#FF6A00")
                        : rootWindow.selCell === index ? "#ffffff" : Qt.rgba(1, 1, 1, 0.10)
                        border.width: wsCell.dropHighlight || rootWindow.selCell === index ? 2 : 1

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                rootWindow.prevFocusAddr = ""
                                rootWindow.show = false
                                rootWindow.focusWorkspace(wsCell.modelData.wsId)
                            }
                        }

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

                        // Empty workspace state
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
                        }

                        // Occupied workspace state
                        Item {
                            id: thumbArea
                            visible: wsCell.modelData.windows.length > 0
                            anchors.fill: parent
                            anchors.margins: 8

                            property var rows: rootWindow.buildThumbRows(wsCell.modelData.windows, width, height, height)

                            Column {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                spacing: 6

                                Repeater {
                                    model: thumbArea.rows

                                    delegate: Row {
                                        id: rowItem
                                        required property var modelData
                                        width: thumbArea.width
                                        height: rowItem.modelData.itemH
                                        spacing: 6

                                        Repeater {
                                            model: rowItem.modelData.items

                                            delegate: Rectangle {
                                                id: thumb
                                                required property var modelData
                                                width: rowItem.modelData.itemW - 6
                                                height: rowItem.modelData.itemH
                                                radius: 0
                                                clip: true
                                                color: Qt.rgba(0.02, 0.02, 0.02, 0.9)
                                                border.color: modelData.activated
                                                ? (shellRoot ? shellRoot.colAccent : "#FF6A00")
                                                : Qt.rgba(1, 1, 1, 0.16)
                                                border.width: modelData.activated ? 2 : 1

                                                // 效能優化：僅在面板顯示時啟用 live 擷取
                                                ScreencopyView {
                                                    id: scv
                                                    captureSource: modelData.wayland
                                                    live: rootWindow.show
                                                    enabled: rootWindow.show

                                                    readonly property real srcAspect: sourceSize.height > 0 ? sourceSize.width / sourceSize.height : (thumb.width / thumb.height)
                                                    readonly property real dstAspect: thumb.width / thumb.height

                                                    anchors.centerIn: parent
                                                    width: srcAspect > dstAspect ? thumb.height * srcAspect : thumb.width
                                                    height: srcAspect > dstAspect ? thumb.height : thumb.width / srcAspect
                                                }

                                                Rectangle {
                                                    z: 5
                                                    visible: thumb.width > 60 && thumb.height > 44
                                                    width: iconImg.implicitSize + 8
                                                    height: iconImg.implicitSize + 8
                                                    radius: 0
                                                    anchors.left: parent.left
                                                    anchors.bottom: parent.bottom
                                                    anchors.margins: 5
                                                    color: Qt.rgba(0, 0, 0, 0.55)

                                                    IconImage {
                                                        id: iconImg
                                                        anchors.centerIn: parent
                                                        implicitSize: 20
                                                        source: Quickshell.iconPath(
                                                            modelData.wayland ? modelData.wayland.appId : "",
                                                            "application-x-executable"
                                                        )
                                                    }
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
                                                            const dx = mouse.x - pressX
                                                            const dy = mouse.y - pressY
                                                            if (!didDrag && Math.sqrt(dx * dx + dy * dy) > 8) {
                                                                didDrag = true
                                                                rootWindow.dragSnapshot = rootWindow.wsGroups
                                                                rootWindow.dragging = true
                                                                rootWindow.dragWin = modelData
                                                            }
                                                            if (rootWindow.dragging) {
                                                                const gp = thumbMa.mapToItem(overviewRoot, mouse.x, mouse.y)
                                                                rootWindow.dragGhostX = gp.x
                                                                rootWindow.dragGhostY = gp.y
                                                            }
                                                    }
                                                    onReleased: (mouse) => {
                                                        if (rootWindow.dragging) {
                                                            dragGhost.Drag.drop()
                                                            rootWindow.dragging = false
                                                            rootWindow.dragWin = null
                                                            rootWindow.dragSnapshot = null
                                                        }
                                                    }
                                                    onClicked: (mouse) => {
                                                        if (didDrag) { didDrag = false; return }
                                                        if (mouse.button === Qt.RightButton) {
                                                            const pos = thumb.mapToItem(overviewRoot, mouse.x, mouse.y)
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

                            Rectangle {
                                z: 6
                                visible: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === wsCell.modelData.wsId
                                width: 14
                                height: 14
                                radius: 2
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 6
                                color: shellRoot ? shellRoot.colAccent : "#FF6A00"
                                border.color: "#ffffff"
                                border.width: 2
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
                            radius: 0
                            clip: true
                            color: Qt.rgba(0.02, 0.02, 0.02, 0.9)
                            border.color: modelData.activated
                            ? (shellRoot ? shellRoot.colAccent : "#FF6A00")
                            : Qt.rgba(1, 1, 1, 0.12)
                            border.width: 1

                            // 效能優化
                            ScreencopyView {
                                id: specScv
                                captureSource: modelData.wayland
                                live: rootWindow.show
                                enabled: rootWindow.show

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
                                        const pos = specThumb.mapToItem(overviewRoot, mouse.x, mouse.y)
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

        // Floating ghost thumbnail
        Rectangle {
            id: dragGhost
            z: 200
            visible: rootWindow.dragging
            width: 160
            height: 100
            x: rootWindow.dragGhostX - width / 2
            y: rootWindow.dragGhostY - height / 2
            radius: 0
            color: Qt.rgba(0.05, 0.05, 0.05, 0.85)
            border.width: 2
            border.color: shellRoot ? shellRoot.colAccent : "#FF6A00"
            opacity: 0.85

            Drag.active: rootWindow.dragging
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2
        }

        // Right-Click Context Menu
        Rectangle {
            id: contextMenu
            z: 100
            visible: false
            width: 200
            height: menuCol.implicitHeight + 16
            radius: 0
            color: Qt.rgba(0.08, 0.08, 0.08, 0.97)
            border.color: Qt.rgba(1, 0.42, 0, 0.5)
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

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 0
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
                            radius: 0
                            color: wsMa.containsMouse
                            ? (shellRoot ? shellRoot.colAccent : "#FF6A00")
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
