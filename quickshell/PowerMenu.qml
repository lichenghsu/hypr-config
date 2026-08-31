import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: rootWindow
    
    property bool show: false
    property var shellRoot // Reference to the main shell root for colors/fonts
    property real animHeight: animRect.height
    property int selectedIndex: 0
    
    WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    
    visible: show || animRect.opacity > 0
    
    onShowChanged: {
        if (show) focusTimer.start();
    }
    
    Timer {
        id: focusTimer
        interval: 50
        onTriggered: powerMenuContent.forceActiveFocus()
    }

    Item {
        id: powerMenuContent
        anchors.fill: parent
        focus: show
        Keys.onEscapePressed: show = false
        Keys.onLeftPressed: selectedIndex = Math.max(0, selectedIndex - 1)
        Keys.onRightPressed: selectedIndex = Math.min(5, selectedIndex + 1)
        Keys.onReturnPressed: {
            show = false;
            if (selectedIndex === 0) pShutdown.running = true;
            else if (selectedIndex === 1) pReboot.running = true;
            else if (selectedIndex === 2) pLock.running = true;
            else if (selectedIndex === 3) pSuspend.running = true;
            else if (selectedIndex === 4) pLogout.running = true;
            else if (selectedIndex === 5) pTextMode.running = true;
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
            
            width: show ? (layout.implicitWidth + 48) : (shellRoot ? shellRoot.notchWidth + 32 : 120)
            height: show ? (layout.implicitHeight + 48) : 32
            
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
                opacity: show ? 1.0 : 0.0
                clip: true
                Behavior on opacity { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : show ? 300 : 100; easing.type: Easing.InOutQuad } }

                RowLayout {
                id: layout
                anchors.centerIn: parent
                spacing: 24
                
                // Shutdown
                Rectangle {
                    width: 92; height: 48; radius: 0
                    border.color: Qt.rgba(1, 0.42, 0, 0.5); border.width: 1
                    color: (sdMouse.containsMouse || selectedIndex === 0) ? Qt.rgba(1, 0.2, 0.2, 0.8) : Qt.rgba(1, 1, 1, 0.1)
                    scale: (sdMouse.containsMouse || selectedIndex === 0) ? 1.1 : 1.0
                    Behavior on scale { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : 150 } }
                    Text { anchors.centerIn: parent; text: "SHUTDOWN"; color: shellRoot ? shellRoot.colFg : "white"; font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1 }
                    MouseArea { id: sdMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { show = false; pShutdown.running = true } }
                }
                // Reboot
                Rectangle {
                    width: 92; height: 48; radius: 0
                    border.color: Qt.rgba(1, 0.42, 0, 0.5); border.width: 1
                    color: (rbMouse.containsMouse || selectedIndex === 1) ? Qt.rgba(0.2, 0.8, 0.2, 0.8) : Qt.rgba(1, 1, 1, 0.1)
                    scale: (rbMouse.containsMouse || selectedIndex === 1) ? 1.1 : 1.0
                    Behavior on scale { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : 150 } }
                    Text { anchors.centerIn: parent; text: "REBOOT"; color: shellRoot ? shellRoot.colFg : "white"; font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1 }
                    MouseArea { id: rbMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { show = false; pReboot.running = true } }
                }
                // Lock
                Rectangle {
                    width: 92; height: 48; radius: 0
                    border.color: Qt.rgba(1, 0.42, 0, 0.5); border.width: 1
                    color: (lkMouse.containsMouse || selectedIndex === 2) ? Qt.rgba(0.8, 0.2, 0.8, 0.8) : Qt.rgba(1, 1, 1, 0.1)
                    scale: (lkMouse.containsMouse || selectedIndex === 2) ? 1.1 : 1.0
                    Behavior on scale { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : 150 } }
                    Text { anchors.centerIn: parent; text: "LOCK"; color: shellRoot ? shellRoot.colFg : "white"; font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1 }
                    MouseArea { id: lkMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { show = false; pLock.running = true } }
                }
                // Suspend
                Rectangle {
                    width: 92; height: 48; radius: 0
                    border.color: Qt.rgba(1, 0.42, 0, 0.5); border.width: 1
                    color: (spMouse.containsMouse || selectedIndex === 3) ? Qt.rgba(0.35, 0.61, 0.84, 0.8) : Qt.rgba(1, 1, 1, 0.1)
                    scale: (spMouse.containsMouse || selectedIndex === 3) ? 1.1 : 1.0
                    Behavior on scale { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : 150 } }
                    Text { anchors.centerIn: parent; text: "SUSPEND"; color: shellRoot ? shellRoot.colFg : "white"; font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1 }
                    MouseArea { id: spMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { show = false; pSuspend.running = true } }
                }
                // Logout
                Rectangle {
                    width: 92; height: 48; radius: 0
                    border.color: Qt.rgba(1, 0.42, 0, 0.5); border.width: 1
                    color: (loMouse.containsMouse || selectedIndex === 4) ? Qt.rgba(0.8, 0.8, 0.2, 0.8) : Qt.rgba(1, 1, 1, 0.1)
                    scale: (loMouse.containsMouse || selectedIndex === 4) ? 1.1 : 1.0
                    Behavior on scale { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : 150 } }
                    Text { anchors.centerIn: parent; text: "LOGOUT"; color: shellRoot ? shellRoot.colFg : "white"; font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1 }
                    MouseArea { id: loMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { show = false; pLogout.running = true } }
                }
                // Text Mode (drop to multi-user.target, reverts on next reboot)
                Rectangle {
                    width: 92; height: 48; radius: 0
                    border.color: Qt.rgba(1, 0.42, 0, 0.5); border.width: 1
                    color: (tmMouse.containsMouse || selectedIndex === 5) ? Qt.rgba(0.2, 0.7, 0.7, 0.8) : Qt.rgba(1, 1, 1, 0.1)
                    scale: (tmMouse.containsMouse || selectedIndex === 5) ? 1.1 : 1.0
                    Behavior on scale { NumberAnimation { duration: (shellRoot && shellRoot.batteryMode) ? 0 : 150 } }
                    Text { anchors.centerIn: parent; text: "TEXT MODE"; color: shellRoot ? shellRoot.colFg : "white"; font.family: shellRoot ? shellRoot.fontFamily : "sans-serif"; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1 }
                    MouseArea { id: tmMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { show = false; pTextMode.running = true } }
                }
                }
            }
        }
    }
    
    Process { id: pShutdown; command: ["systemctl", "poweroff"] }
    Process { id: pReboot; command: ["systemctl", "reboot"] }
    Process { id: pLock; command: ["/home/miles/.local/bin/qs-lock"] }
    Process { id: pSuspend; command: ["systemctl", "suspend"] }
    Process { id: pLogout; command: ["pkill", "-x", "Hyprland"] }
    Process { id: pTextMode; command: ["/home/miles/.local/bin/qs-textmode"] }
}
