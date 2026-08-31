import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: rootWindow

    property bool show: false
    property var shellRoot
    property real animHeight: canvasBox.height
    property var monitors: []
    readonly property real canvasW: 700
    readonly property real canvasH: 380
    property real miniScaleActual: 0.1
    property int editingIndex: -1
    property string statusText: ""

    readonly property var scalePresets: ["1", "1.25", "1.5", "1.75", "2"]

    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    visible: show || canvasBox.opacity > 0

    onShowChanged: {
        if (show) {
            editingIndex = -1;
            statusText = "";
            pGetMonitors.running = true;
        }
    }

    Process {
        id: pGetMonitors
        command: ["sh", "-c", "hyprctl monitors -j | jq -c ."]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var raw = JSON.parse(data);
                    rootWindow.monitors = raw.map(m => ({
                        name: m.name,
                        mode: m.width + "x" + m.height + "@" + Math.round(m.refreshRate),
                        scale: String(m.scale),
                        x: m.x, y: m.y,
                        // layout coords are physical-pixel / scale
                        w: m.width / m.scale, h: m.height / m.scale,
                        dragX: 0, dragY: 0,
                        modePresets: rootWindow.buildModePresets(m)
                    }));
                    rootWindow.layoutMinis();
                } catch (e) {
                    rootWindow.statusText = "failed to read monitors: " + e;
                }
            }
        }
        stderr: SplitParser {
            onRead: data => { if (data.trim()) rootWindow.statusText = "hyprctl/jq error: " + data; }
        }
    }

    function buildModePresets(m) {
        // collapse to one entry per WxH (keep the highest refresh rate seen)
        // instead of every WxH@RR combo -- some panels report 20-30 modes
        // once you count every refresh-rate variant, which overflows the UI
        var bestByRes = {};
        (m.availableModes || []).forEach(raw => {
            var match = raw.match(/^(\d+x\d+)@([\d.]+)Hz$/);
            if (!match) return;
            var res = match[1], rr = Math.round(parseFloat(match[2]));
            if (!bestByRes[res] || rr > bestByRes[res]) bestByRes[res] = rr;
        });
        var presets = Object.keys(bestByRes).map(res => res + "@" + bestByRes[res]);
        [1.5, 2].forEach(divisor => {
            var pw = Math.round(m.width / divisor / 2) * 2;
            var ph = Math.round(m.height / divisor / 2) * 2;
            var res = pw + "x" + ph;
            if (!(res in bestByRes)) presets.push(res + "@60");
        });
        // standard resolutions matching this panel's aspect ratio (e.g. 2K on a
        // 16:9 main monitor). hyprland rejects any the panel can't do.
        var nativeRatio = m.width / m.height;
        [[3840, 2160], [2560, 1440], [1920, 1080], [1600, 900]].forEach(r => {
            if (Math.abs(r[0] / r[1] - nativeRatio) < 0.02) {
                var res = r[0] + "x" + r[1];
                if (!(res in bestByRes) && presets.indexOf(res + "@60") === -1)
                    presets.push(res + "@60");
            }
        });
        return presets;
    }

    function layoutMinis() {
        if (monitors.length === 0) return;
        var minX = Math.min(...monitors.map(m => m.x));
        var minY = Math.min(...monitors.map(m => m.y));
        var maxX = Math.max(...monitors.map(m => m.x + m.w));
        var maxY = Math.max(...monitors.map(m => m.y + m.h));
        var boundsW = Math.max(1, maxX - minX);
        var boundsH = Math.max(1, maxY - minY);
        var fit = Math.min((canvasW - 40) / boundsW, (canvasH - 40) / boundsH, 0.3);
        rootWindow.miniScaleActual = fit;
        for (var i = 0; i < monitors.length; i++) {
            monitors[i].dragX = 20 + (monitors[i].x - minX) * fit;
            monitors[i].dragY = 20 + (monitors[i].y - minY) * fit;
        }
        monitorsChanged();
    }

    function setMode(index, mode) { monitors[index].mode = mode; monitorsChanged(); }
    function setScale(index, scale) { monitors[index].scale = scale; monitorsChanged(); }

    function runOne(action, m, pos) {
        var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', rootWindow);
        proc.command = ["/home/miles/.local/bin/monitor_tui.py", action, m.name, m.mode, pos, String(m.scale)];
        proc.exited.connect((code, status) => {
            if (code !== 0) {
                rootWindow.statusText = m.name + ": " + action + " failed (exit " + code + ")";
            } else if (!rootWindow.statusText.includes("failed")) {
                rootWindow.statusText = m.name + ": " + action + " ok (" + m.mode + " @" + m.scale + "x, " + pos + ")";
            }
        });
        proc.running = true;
    }

    function applyAll(persistToo) {
        // snap every rect's top-left to the nearest other rect's edge within
        // a small threshold so dropped screens actually touch, then convert
        // back to real layout coordinates and fire one process per monitor
        var threshold = 14;
        for (var i = 0; i < monitors.length; i++) {
            var a = monitors[i];
            for (var j = 0; j < monitors.length; j++) {
                if (i === j) continue;
                var b = monitors[j];
                if (Math.abs(a.dragX - (b.dragX + b.w * miniScaleActual)) < threshold) a.dragX = b.dragX + b.w * miniScaleActual;
                if (Math.abs((a.dragX + a.w * miniScaleActual) - b.dragX) < threshold) a.dragX = b.dragX - a.w * miniScaleActual;
                if (Math.abs(a.dragY - b.dragY) < threshold) a.dragY = b.dragY;
            }
        }
        monitorsChanged();

        statusText = "applying...";
        var minX = Math.min(...monitors.map(m => m.dragX));
        var minY = Math.min(...monitors.map(m => m.dragY));
        for (var k = 0; k < monitors.length; k++) {
            var m = monitors[k];
            var realX = Math.round((m.dragX - minX) / miniScaleActual);
            var realY = Math.round((m.dragY - minY) / miniScaleActual);
            var pos = realX + "x" + realY;
            runOne("--apply", m, pos);
            if (persistToo) runOne("--persist", m, pos);
        }
    }

    Item {
        id: dockContent
        anchors.fill: parent
        focus: show
        Keys.onEscapePressed: show = false

        MouseArea {
            anchors.fill: parent
            enabled: show
            onClicked: show = false
        }

        Rectangle {
            id: canvasBox
            anchors.centerIn: parent
            width: show ? (canvasW + 48) : 0
            height: show ? (popupContent.implicitHeight + 48) : 0
            color: Qt.rgba(0.08, 0.08, 0.08, 0.95)
            border.color: Qt.rgba(1, 0.42, 0, 0.5)
            border.width: show ? 1 : 0
            opacity: show ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            MouseArea {
                anchors.fill: parent
                onClicked: {} // swallow clicks so they don't close the popup
            }

            ColumnLayout {
                id: popupContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 24
                spacing: 10

                Text {
                    text: "Drag to rearrange · click a monitor to edit resolution/scale"
                    color: shellRoot ? shellRoot.colFg : "white"
                    font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"
                    font.pixelSize: 13
                    font.bold: true
                }

                Item {
                    id: canvas
                    Layout.preferredWidth: canvasW
                    Layout.preferredHeight: canvasH
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        color: Qt.rgba(1, 1, 1, 0.03)
                        border.color: Qt.rgba(1, 1, 1, 0.1)
                        border.width: 1
                    }

                    Repeater {
                        model: rootWindow.monitors

                        Rectangle {
                            required property var modelData
                            required property int index

                            x: modelData.dragX
                            y: modelData.dragY
                            width: modelData.w * rootWindow.miniScaleActual
                            height: modelData.h * rootWindow.miniScaleActual
                            radius: 0
                            color: dragMa.drag.active ? Qt.rgba(1, 0.42, 0, 0.35)
                                : rootWindow.editingIndex === index ? Qt.rgba(1, 0.42, 0, 0.2)
                                : Qt.rgba(1, 1, 1, 0.08)
                            border.color: Qt.rgba(1, 0.42, 0, 0.7)
                            border.width: 2

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 2
                                Text {
                                    text: modelData.name
                                    color: "white"
                                    font.pixelSize: 11
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    text: modelData.mode + " @" + modelData.scale + "x"
                                    color: Qt.rgba(1, 1, 1, 0.6)
                                    font.pixelSize: 9
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            MouseArea {
                                id: dragMa
                                anchors.fill: parent
                                drag.target: parent
                                drag.axis: Drag.XAndYAxis
                                onReleased: {
                                    modelData.dragX = parent.x;
                                    modelData.dragY = parent.y;
                                }
                                onClicked: {
                                    rootWindow.editingIndex = (rootWindow.editingIndex === index) ? -1 : index;
                                }
                            }
                        }
                    }
                }

                // inline mode/scale editor for the currently clicked monitor
                Rectangle {
                    Layout.preferredWidth: canvasW
                    implicitHeight: editorCol.implicitHeight + 16
                    visible: rootWindow.editingIndex >= 0 && rootWindow.editingIndex < rootWindow.monitors.length
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(1, 0.42, 0, 0.4)
                    border.width: 1

                    ColumnLayout {
                        id: editorCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        spacing: 4

                        RowLayout {
                            spacing: 6
                            Text { text: "mode:"; color: "white"; font.pixelSize: 10 }
                        }
                        Flow {
                            Layout.preferredWidth: canvasW - 16
                            spacing: 4
                            Repeater {
                                model: rootWindow.editingIndex >= 0 ? rootWindow.monitors[rootWindow.editingIndex].modePresets : []
                                Rectangle {
                                    required property string modelData
                                    width: label.implicitWidth + 12; height: 22
                                    color: (rootWindow.editingIndex >= 0 && rootWindow.monitors[rootWindow.editingIndex].mode === modelData)
                                        ? Qt.rgba(1, 0.42, 0, 0.5) : Qt.rgba(1, 1, 1, 0.08)
                                    border.color: Qt.rgba(1, 1, 1, 0.3); border.width: 1
                                    Text { id: label; anchors.centerIn: parent; text: parent.modelData; color: "white"; font.pixelSize: 9 }
                                    MouseArea { anchors.fill: parent; onClicked: rootWindow.setMode(rootWindow.editingIndex, parent.modelData) }
                                }
                            }
                        }
                        RowLayout {
                            spacing: 6
                            Text { text: "scale:"; color: "white"; font.pixelSize: 10 }
                            Repeater {
                                model: rootWindow.scalePresets
                                Rectangle {
                                    required property string modelData
                                    width: 36; height: 22
                                    color: (rootWindow.editingIndex >= 0 && rootWindow.monitors[rootWindow.editingIndex].scale === modelData)
                                        ? Qt.rgba(1, 0.42, 0, 0.5) : Qt.rgba(1, 1, 1, 0.08)
                                    border.color: Qt.rgba(1, 1, 1, 0.3); border.width: 1
                                    Text { anchors.centerIn: parent; text: parent.modelData; color: "white"; font.pixelSize: 9 }
                                    MouseArea { anchors.fill: parent; onClicked: rootWindow.setScale(rootWindow.editingIndex, parent.modelData) }
                                }
                            }
                        }
                    }
                }

                Text {
                    text: rootWindow.statusText
                    color: rootWindow.statusText.includes("failed") || rootWindow.statusText.includes("error") ? "#ff5555" : Qt.rgba(1, 1, 1, 0.7)
                    font.pixelSize: 10
                    Layout.preferredWidth: canvasW
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 16

                    Rectangle {
                        width: 140; height: 36
                        color: applyMa.containsMouse ? Qt.rgba(1, 0.42, 0, 0.35) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(1, 0.42, 0, 0.7); border.width: 1
                        Text { anchors.centerIn: parent; text: "Apply (temporary)"; color: "white"; font.pixelSize: 12 }
                        MouseArea { id: applyMa; anchors.fill: parent; hoverEnabled: true; onClicked: rootWindow.applyAll(false) }
                    }
                    Rectangle {
                        width: 160; height: 36
                        color: saveMa.containsMouse ? Qt.rgba(1, 0.42, 0, 0.35) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(1, 0.42, 0, 0.7); border.width: 1
                        Text { anchors.centerIn: parent; text: "Apply & Save"; color: "white"; font.pixelSize: 12 }
                        MouseArea { id: saveMa; anchors.fill: parent; hoverEnabled: true; onClicked: rootWindow.applyAll(true) }
                    }
                    Rectangle {
                        width: 100; height: 36
                        color: closeMa.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.08)
                        border.color: Qt.rgba(1, 1, 1, 0.3); border.width: 1
                        Text { anchors.centerIn: parent; text: "Close"; color: "white"; font.pixelSize: 12 }
                        MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; onClicked: rootWindow.show = false }
                    }
                }
            }
        }
    }
}
