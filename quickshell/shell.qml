import Quickshell
import QtQuick
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io

ShellRoot {
    PanelWindow {
    id: root

    property color colBg: "#000000"
    property color colFg: "#ffffff"
    property color colAccent: "#ffffff"
    property color colMuted: Qt.rgba(1, 1, 1, 0.4)
    property color colHover: Qt.rgba(1, 1, 1, 0.1)
    property color colCrit: "#ff0000"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 10 // Reduced font size to match waybar 9px
    property int windowCount: 0
    property bool isBarMode: windowCount === 1
    property real notchWidth: notchLayout.implicitWidth
    
    property bool isAnyPopupOpen: controlCenter.show || appLauncherPopup.show || clipboardManagerPopup.show || themeSwitcherPopup.show || wifiMenuPopup.show || powerMenuPopup.show || bluetoothMenuPopup.show || wallpaperPickerPopup.show
    property bool isAnyPopupAnimActive: isAnyPopupOpen || controlCenter.animHeight > 36 || appLauncherPopup.animHeight > 36 || clipboardManagerPopup.animHeight > 36 || themeSwitcherPopup.animHeight > 36 || wifiMenuPopup.animHeight > 36 || powerMenuPopup.animHeight > 36 || bluetoothMenuPopup.animHeight > 36 || wallpaperPickerPopup.animHeight > 36

    Process {
        command: ["/home/miles/.config/quickshell/count_tiled.sh"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var c = parseInt(data.trim())
                if (!isNaN(c)) root.windowCount = c
            }
        }
    }

    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: root.isBarMode ? 32 : 36
    color: "transparent"

    // State properties
    property string powerDraw: "0.0"
    property string temperature: "0"
    property string updates: "0"
    property string batteryCap: "100"
    property string brightnessLevel: "0%"
    property string kbdBrightnessLevel: "0"
    property int cpuWattage: 15
    property bool batteryCharging: false
    property string gpuMode: "Unknown"
    property int batLimit: 80
    property string volumeOut: "0%"
    property bool volumeMuted: false
    property string volumeMic: "0%"
    property bool micMuted: false
    property string bluetoothStatus: "off"
    property string vpnDisconnectTarget: ""
    property bool audioSinkExpanded: false
    property bool audioSourceExpanded: false
    property string defaultSink: ""
    property string defaultSource: ""

    ListModel { id: vpnModel }
    ListModel { id: audioSinkModel }
    ListModel { id: audioSourceModel }

    function vpnSetActive(name, active) {
        for (var i = 0; i < vpnModel.count; i++) {
            if (vpnModel.get(i).name === name) {
                vpnModel.setProperty(i, "active", active);
                if (active) vpnModel.setProperty(i, "connecting", false);
                return;
            }
        }
    }
    property bool remminaExpanded: false
    property bool batteryMode: false

    property bool showBatteryModeIndicator: false
    
    onBatteryModeChanged: {
        showBatteryModeIndicator = true;
        batteryModeTimer.restart();
    }
    
    Timer {
        id: batteryModeTimer
        interval: 1000
        repeat: false
        onTriggered: root.showBatteryModeIndicator = false
    }

    property bool showMicIndicator: false
    
    onMicMutedChanged: {
        showMicIndicator = true;
        micIndicatorTimer.restart();
    }
    
    Timer {
        id: micIndicatorTimer
        interval: 1000
        repeat: false
        onTriggered: root.showMicIndicator = false
    }

    property int claudeRemainPct: 0
    property string claudeResetIn: "--"
    property string claudeWeekCost: "0.00"

    property string spotifyStatus: "offline"
    property string spotifyText: ""

    property string mprisPlayer: ""
    property string mprisStatus: "offline"
    property string mprisTitle: ""
    property string mprisArtist: ""
    property string mprisArtUrl: ""
    property int    mprisLength: 0
    property int    mprisPosition: 0
    property real   mprisProgress: 0.0

    property string wifiIcon: "󰤯"
    property string wifiText: "Disconnected"

    property bool showOsd: false
    property string osdText: "0%"
    property string osdIcon: "󰕾"
    property real osdValue: 0
    property bool showPowerMenu: false
    property bool showAppLauncher: false
    property bool showClipboard: false

    // Stopwatch & Timer state
    property bool stopwatchRunning: false
    property int stopwatchSeconds: 0
    property string stopwatchText: "00:00"
    
    property bool timerRunning: false
    property int timerSeconds: 0
    property int timerTotal: 300 // 5 minutes default
    property string timerText: "05:00"
    
    property int pomodoroState: 0 // 0 = off, 1 = work, 2 = break
    property int pomodoroWorkTotal: 1500 // 25 minutes
    property int pomodoroBreakTotal: 300 // 5 minutes
    
    function formatTime(s) {
        var m = Math.floor(s / 60);
        var sec = s % 60;
        return (m < 10 ? "0" + m : m) + ":" + (sec < 10 ? "0" + sec : sec);
    }

    // Click Actions
    Process { id: pPavu; command: ["pavucontrol"] }
    Process { id: pMicMute; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"] }
    Process { id: pVolMute; command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"] }
    Process { id: pVolSet } // Dynamic volume setter
    Process { id: pBatLimitSet }
    Process { id: pBlueberry; command: ["blueberry"] }

    Process { id: pWifiToggle; command: ["sh", "-c", "if [ \"$(nmcli radio wifi)\" = \"enabled\" ]; then nmcli radio wifi off; else nmcli radio wifi on; fi"] }
    Process { id: pBtToggle; command: ["sh", "-c", "if bluetoothctl show | grep -q 'Powered: yes'; then rfkill block bluetooth; else rfkill unblock bluetooth; fi"] }
    Process { id: pWifiOn; command: ["nmcli", "radio", "wifi", "on"] }
    Process { id: pWifiOff; command: ["nmcli", "radio", "wifi", "off"] }
    Process { id: pBtOn; command: ["rfkill", "unblock", "bluetooth"] }
    Process { id: pBtOff; command: ["rfkill", "block", "bluetooth"] }
    Process { id: pVpnUp }
    Process { id: pVpnDown }

    Process {
        id: pGetDefaultSink
        command: ["sh", "-c", "pactl get-default-sink 2>/dev/null"]
        stdout: SplitParser { onRead: data => { root.defaultSink = data.trim() } }
    }
    Process {
        id: pGetDefaultSource
        command: ["sh", "-c", "pactl get-default-source 2>/dev/null"]
        stdout: SplitParser { onRead: data => { root.defaultSource = data.trim() } }
    }
    Process {
        id: pGetSinks
        command: ["sh", "-c", "pactl list sinks | awk '/\\tName:/{name=$2} /\\tDescription:/{line=$0; sub(/^\\tDescription:[ \\t]*/, \"\", line); print name\"|\"line}'"]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.split("|");
                if (parts.length >= 2)
                    audioSinkModel.append({ name: parts[0].trim(), displayName: parts.slice(1).join("|").trim() });
            }
        }
        onRunningChanged: {
            if (running) { audioSinkModel.clear(); pGetDefaultSink.running = true; }
        }
    }
    Process {
        id: pGetSources
        command: ["sh", "-c", "pactl list sources | awk '/\\tName:/{name=$2} /\\tDescription:/{line=$0; sub(/^\\tDescription:[ \\t]*/, \"\", line); if (line !~ /Monitor of/) print name\"|\"line}'"]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.split("|");
                if (parts.length >= 2)
                    audioSourceModel.append({ name: parts[0].trim(), displayName: parts.slice(1).join("|").trim() });
            }
        }
        onRunningChanged: {
            if (running) { audioSourceModel.clear(); pGetDefaultSource.running = true; }
        }
    }
    Process {
        id: pSetDefaultSink
        property string sinkName: ""
        onRunningChanged: {
            if (running) command = ["pactl", "set-default-sink", sinkName];
        }
    }
    Process {
        id: pSetDefaultSource
        property string sourceName: ""
        onRunningChanged: {
            if (running) command = ["pactl", "set-default-source", sourceName];
        }
    }
    Process { id: pPowerShutdown; command: ["systemctl", "poweroff"] }
    Process { id: pPowerReboot;   command: ["systemctl", "reboot"] }

    Process { id: pPowerLock;     command: ["swaylock"] }
    Process { id: pPowerSuspend;  command: ["systemctl", "suspend"] }
    Process { id: pPowerLogout;   command: ["pkill", "-x", "Hyprland"] }

    Process {
        id: pVpnScan
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE con show | awk -F: '$2==\"vpn\"{print $1}' | sort"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var name = data.trim();
                if (name !== "") vpnModel.append({ name: name, active: false, connecting: false });
            }
        }
    }

    Process { id: pRemmina }

    ListModel { id: remminaModel }

    Process {
        id: pRemminaScan
        command: ["sh", "-c", "find ~/.local/share/remmina -name '*.remmina' | sort | while read f; do name=$(grep -m1 '^name=' \"$f\" | cut -d= -f2-); group=$(grep -m1 '^group=' \"$f\" | cut -d= -f2-); proto=$(grep -m1 '^protocol=' \"$f\" | cut -d= -f2-); echo \"$group|$name|$proto|$f\"; done | sort"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("|");
                if (parts.length === 4)
                    remminaModel.append({ group: parts[0], name: parts[1], proto: parts[2], filePath: parts[3] });
            }
        }
        onRunningChanged: { if (!running) {} }
    }
    Process {
        id: pCheckBatteryMode
        command: ["sh", "-c", "grep -q '^#animations' /home/miles/.config/hypr/modules/look_and_feel.conf && echo 'false' || echo 'true'"]
        running: true
        stdout: SplitParser { onRead: data => { root.batteryMode = (data.trim() === 'true'); } }
    }
    Process {
        id: pToggleBatteryMode
        command: ["/home/miles/.local/bin/battery_mode.sh"]
    }

    Process { id: pSpotPrev; command: ["playerctl", "previous"] }

    Process {
        id: pBright
        command: ["bash", "-c", "brightnessctl -m | awk -F, '{print $4}'"]
        running: true
        stdout: SplitParser { onRead: text => root.brightnessLevel = text.trim() }
    }
    Timer { interval: 1000; running: true; repeat: true; onTriggered: pBright.running = true }


    Timer {
        id: osdTimer
        interval: 2000
        repeat: false
        onTriggered: root.showOsd = false
    }

    Timer {
        id: stopwatchTimer
        interval: 1000
        running: root.stopwatchRunning
        repeat: true
        onTriggered: {
            root.stopwatchSeconds++;
            root.stopwatchText = root.formatTime(root.stopwatchSeconds);
        }
    }

    Timer {
        id: timerTimer
        interval: 1000
        running: root.timerRunning
        repeat: true
        onTriggered: {
            if (root.timerSeconds > 0) {
                root.timerSeconds--;
                root.timerText = root.formatTime(root.timerSeconds);
            } else {
                if (root.pomodoroState === 1) {
                    root.pomodoroState = 2;
                    root.timerTotal = root.pomodoroBreakTotal;
                    root.timerSeconds = root.timerTotal;
                    root.timerText = root.formatTime(root.timerTotal);
                    pNotify.command = ["notify-send", "-u", "critical", "-i", "timer", "Pomodoro", "Work session finished! Time for a break."];
                    pNotify.running = true;
                } else if (root.pomodoroState === 2) {
                    root.pomodoroState = 1;
                    root.timerTotal = root.pomodoroWorkTotal;
                    root.timerSeconds = root.timerTotal;
                    root.timerText = root.formatTime(root.timerTotal);
                    pNotify.command = ["notify-send", "-u", "normal", "-i", "timer", "Pomodoro", "Break finished! Back to work."];
                    pNotify.running = true;
                } else {
                    root.timerRunning = false;
                }
            }
        }
    }
    
    Process { id: pNotify }

    Process {
        id: pBrightSet
        command: ["brightnessctl", "s", "50%"]
    }

    Process { id: pKbdBrightSet }

    Process { id: pWattSet }



    Process { id: pSpotPlay; command: ["playerctl", "play-pause"] }
    Process { id: pSpotNext; command: ["playerctl", "next"] }
    Process { id: pGpu; command: ["sh", "-c", "supergfxctl -m Hybrid; hyprctl dispatch \"hl.dsp.exit()\""] }

    Process { id: pGpuInt; command: ["sh", "-c", "supergfxctl -m Integrated; hyprctl dispatch \"hl.dsp.exit()\""] }
    Process { id: pGpuHyb; command: ["sh", "-c", "supergfxctl -m Hybrid; hyprctl dispatch \"hl.dsp.exit()\""] }
    
    Process { id: pNoteHyprland; command: ["kate", "/home/miles/.config/hypr"] }
    Process { id: pNoteWaybar; command: ["kate", "/home/miles/.config/waybar/"] }
    Process { id: pNoteTofi; command: ["kate", "/home/miles/.config/tofi/"] }
    Process { id: pNoteKitty; command: ["kate", "/home/miles/.config/kitty"] }
    Process { id: pNoteFoot; command: ["kate", "/home/miles/.config/foot"] }
    Process { id: pNoteGhostty; command: ["kate", "/home/miles/.config/ghostty"] }
    Process { id: pNoteFish; command: ["kate", "/home/miles/.config/fish"] }
    Process { id: pNoteFastfetch; command: ["kate", "/home/miles/.config/fastfetch"] }
    Process { id: pNoteQuickshell; command: ["kate", "/home/miles/.config/quickshell"] }

    

    // Background Process Loops
    Process {
        command: ["sh", "-c", "while true; do status=$(cat /sys/class/power_supply/BAT1/status 2>/dev/null); if [ \"$status\" = \"Discharging\" ]; then awk '{line[NR]=$1} END {printf \"%.1f\", (line[1] * line[2]) / 1000000000000}' /sys/class/power_supply/BAT1/current_now /sys/class/power_supply/BAT1/voltage_now 2>/dev/null; else echo \"AC\"; fi; echo; sleep 3; done"]
        running: true; stdout: SplitParser { onRead: data => root.powerDraw = data.trim() }
    }
    Process {
        command: ["sh", "-c", "while true; do temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo 0); echo $((temp / 1000)); sleep 3; done"]
        running: true; stdout: SplitParser { onRead: data => root.temperature = data.trim() }
    }
    Process {
        command: ["sh", "-c", "while true; do checkupdates 2>/dev/null | wc -l; sleep 3600; done"]
        running: true; stdout: SplitParser { onRead: data => root.updates = data.trim() }
    }
    Process {
        command: ["sh", "-c", "while true; do cap=$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || echo 0); acad=$(cat /sys/class/power_supply/ACAD/online 2>/dev/null || echo 0); echo \"$cap $acad\"; sleep 5; done"]
        running: true; stdout: SplitParser { 
            onRead: data => {
                var parts = data.trim().split(" ");
                root.batteryCap = parts[0];
                root.batteryCharging = (parts[1] === "1");
            }
        }
    }
    Process {
        command: ["sh", "-c", "while true; do asusctl battery info 2>/dev/null; sleep 10; done"]
        running: true; stdout: SplitParser { 
            onRead: data => {
                var d = data.trim();
                if (d.includes("Current battery charge limit:")) {
                    var m = d.match(/(\d+)%/);
                    if (m) root.batLimit = parseInt(m[1]);
                }
            }
        }
    }
    Process {
        command: ["sh", "-c", "while true; do sudo ryzenadj -i 2>/dev/null | awk -F'|' '/STAPM LIMIT/ {print int($3)}'; sleep 10; done"]
        running: true; stdout: SplitParser { 
            onRead: data => {
                var d = parseInt(data.trim());
                if (!isNaN(d) && d > 0) root.cpuWattage = d;
            }
        }
    }
    Process {
        command: ["sh", "-c", "while true; do supergfxctl -g 2>/dev/null || echo '?'; sleep 3; done"]
        running: true; stdout: SplitParser { onRead: data => root.gpuMode = data.trim() }
    }
    Process {
        command: ["sh", "-c", "while true; do wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null; sleep 0.5; done"]
        running: true; stdout: SplitParser { 
            onRead: data => {
                var d = data.trim();
                root.volumeMuted = d.includes("[MUTED]");
                var m = d.match(/[0-9.]+/);
                if (m) root.volumeOut = Math.round(parseFloat(m[0]) * 100) + "%";
            }
        }
    }
    Process {
        command: ["sh", "-c", "while true; do wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null; sleep 0.5; done"]
        running: true; stdout: SplitParser { 
            onRead: data => {
                var d = data.trim();
                root.micMuted = d.includes("[MUTED]");
                var m = d.match(/[0-9.]+/);
                if (m) root.volumeMic = Math.round(parseFloat(m[0]) * 100) + "%";
            }
        }
    }
    Process {
        command: ["sh", "-c", "while true; do bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo 'on' || echo 'off'; sleep 3; done"]
        running: true; stdout: SplitParser { onRead: data => root.bluetoothStatus = data.trim() }
    }
    Process {
        id: pVpnPoll
        command: ["sh", "-c", "while true; do nmcli -t -f NAME,TYPE,STATE con show --active 2>/dev/null | awk -F: '$2==\"vpn\"&&$3==\"activated\"{print $1}'; echo \"---\"; sleep 2; done"]
        running: true
        property var activeBatch: []
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim();
                if (line === "---") {
                    for (var i = 0; i < vpnModel.count; i++) {
                        var n = vpnModel.get(i).name;
                        root.vpnSetActive(n, pVpnPoll.activeBatch.indexOf(n) !== -1);
                    }
                    pVpnPoll.activeBatch = [];
                } else if (line !== "") {
                    pVpnPoll.activeBatch = pVpnPoll.activeBatch.concat([line]);
                }
            }
        }
    }
    Process {
        command: ["sh", "-c", "while true; do sig=$(LC_ALL=C nmcli -t -f active,signal dev wifi | grep '^yes' | cut -d: -f2); if [ -z \"$sig\" ]; then echo 'disc'; else echo \"$sig\"; fi; sleep 3; done"]
        running: true; stdout: SplitParser { 
            onRead: data => {
                var d = data.trim();
                if (d === 'disc') { root.wifiIcon = "󰤮"; root.wifiText = "Disconnected"; }
                else {
                    var s = parseInt(d);
                    root.wifiText = s + "%";
                    if (s > 80) root.wifiIcon = "󰤨";
                    else if (s > 60) root.wifiIcon = "󰤥";
                    else if (s > 40) root.wifiIcon = "󰤢";
                    else if (s > 20) root.wifiIcon = "󰤟";
                    else root.wifiIcon = "󰤯";
                }
            }
        }
    }
    Process {
        command: ["sh", "-c", "while true; do out=$(playerctl metadata --format '{{playerName}}|{{status}}|{{title}}|{{artist}}|{{mpris:artUrl}}|{{mpris:length}}' 2>/dev/null); [ -z \"$out\" ] && echo 'offline||||0' || echo \"$out\"; sleep 0.5; done"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var p = data.split("|");
                if (p[0].trim() === "offline" || p.length < 5) {
                    root.mprisStatus = "offline"; root.spotifyStatus = "offline";
                    root.mprisPlayer = root.mprisTitle = root.mprisArtist = root.mprisArtUrl = "";
                    root.mprisLength = 0;
                    return;
                }
                root.mprisPlayer   = p[0].trim();
                root.mprisStatus   = p[1].trim();
                root.mprisTitle    = p[2].trim();
                root.mprisArtist   = p[3].trim();
                root.mprisArtUrl   = p[4].trim();
                root.mprisLength   = parseInt(p[5].trim()) || 0;
                if (root.mprisPlayer === "spotify") {
                    root.spotifyStatus = root.mprisStatus;
                    root.spotifyText   = root.mprisTitle + (root.mprisArtist ? " — " + root.mprisArtist : "");
                } else {
                    root.spotifyStatus = "offline";
                }
            }
        }
    }
    Timer {
        interval: 1000; running: root.mprisStatus === "Playing"; repeat: true
        onTriggered: {
            if (root.mprisLength > 0) {
                root.mprisPosition = Math.min(root.mprisPosition + 1000000, root.mprisLength);
                root.mprisProgress = root.mprisPosition / root.mprisLength;
            }
        }
    }
    Process {
        command: ["sh", "-c", "while true; do playerctl position 2>/dev/null || echo 0; sleep 5; done"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var pos = parseFloat(data.trim());
                if (!isNaN(pos) && root.mprisLength > 0) {
                    root.mprisPosition = Math.round(pos * 1000000);
                    root.mprisProgress = root.mprisPosition / root.mprisLength;
                }
            }
        }
    }

    Process {
        command: ["sh", "-c", "while true; do asusctl leds get 2>/dev/null | awk '{print $NF}'; sleep 3; done"]
        running: true; stdout: SplitParser {
            onRead: data => {
                var d = data.trim().toLowerCase();
                if (d === 'off') root.kbdBrightnessLevel = "0";
                else if (d === 'low') root.kbdBrightnessLevel = "1";
                else if (d === 'med') root.kbdBrightnessLevel = "2";
                else if (d === 'high') root.kbdBrightnessLevel = "3";
            }
        }
    }

    Process {
        id: pClaudeUsage
        command: ["python3", "/home/miles/.config/quickshell/claude_usage.sh"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var parts = data.trim().split("|");
                if (parts.length === 3) {
                    root.claudeRemainPct = parseInt(parts[0]) || 0;
                    root.claudeResetIn = parts[1];
                    root.claudeWeekCost = parts[2];
                }
            }
        }
    }
    Timer { interval: 60000; running: true; repeat: true; onTriggered: { if (!pClaudeUsage.running) pClaudeUsage.running = true } }


    // A helper to make clickable modules easily
    component Mod: MouseArea {
        id: modRoot
        property string text
        property color textColor: root.colFg
        property color bgColor: "transparent"
        property bool blink: false
        property bool show: true
        property real customWidth: 0
        default property alias customContent: contentBox.data
        
        Layout.fillHeight: true
        Layout.preferredWidth: show ? (customWidth > 0 ? customWidth + 16 : modText.implicitWidth + 16) : 0
        Behavior on Layout.preferredWidth { 
            NumberAnimation { duration: root.batteryMode ? 0 : 300; easing.type: Easing.OutExpo } 
        }
        
        visible: Layout.preferredWidth > 0
        clip: true
        hoverEnabled: true

        Rectangle {
            anchors.fill: parent
            color: parent.bgColor
            Behavior on color { ColorAnimation { duration: root.batteryMode ? 0 : 200 } }
            
            SequentialAnimation on opacity {
                running: modRoot.blink
                loops: Animation.Infinite
                NumberAnimation { to: 0.1; duration: root.batteryMode ? 0 : 500 }
                NumberAnimation { to: 1.0; duration: root.batteryMode ? 0 : 500 }
            }
        }

        Item {
            anchors.centerIn: parent
            width: modText.width
            height: modText.height
            scale: parent.containsPress ? 0.85 : (parent.containsMouse ? 1.1 : 1.0)
            Behavior on scale { 
                NumberAnimation { duration: root.batteryMode ? 0 : 200; easing.type: Easing.OutBack; easing.overshoot: 2.0 } 
            }
            
            Text {
                id: modText
                text: parent.parent.text
                color: parent.parent.textColor
                font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
                anchors.centerIn: parent
                Behavior on color { ColorAnimation { duration: root.batteryMode ? 0 : 200 } }
            }
            Item {
                id: contentBox
                anchors.centerIn: parent
            }
        }
    }

    Rectangle {
        id: notchRect
        opacity: (!root.isAnyPopupAnimActive) || root.isBarMode ? 1.0 : 0.0
        
        anchors.top: parent.top
        anchors.topMargin: root.isBarMode ? 0 : 4
        anchors.horizontalCenter: parent.horizontalCenter
        height: 32
        width: root.isBarMode ? parent.width : notchLayout.implicitWidth + 32
        color: Qt.rgba(0.02, 0.02, 0.02, 0.95)
        radius: root.isBarMode ? 0 : 16
        
        Behavior on width { NumberAnimation { duration: root.batteryMode ? 0 : 400; easing.type: Easing.OutExpo } }
        Behavior on radius { NumberAnimation { duration: root.batteryMode ? 0 : 400; easing.type: Easing.OutExpo } }
        Behavior on anchors.topMargin { NumberAnimation { duration: root.batteryMode ? 0 : 400; easing.type: Easing.OutExpo } }
        border.color: Qt.rgba(1, 1, 1, 0.1)
        border.width: root.isBarMode ? 0 : 1
        
        RowLayout {
            id: notchLayout
            opacity: root.isAnyPopupOpen ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: root.batteryMode ? 0 : 150 } }
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            height: parent.height
            spacing: 8
            
            Repeater {
                model: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
                Mod {
                    property var ws: Hyprland.workspaces.values.find(w => w.id === modelData)
                    property bool isActive: Hyprland.focusedWorkspace != null && Hyprland.focusedWorkspace.id === modelData
                    
                    text: modelData
                    textColor: isActive ? root.colFg : root.colMuted
                    bgColor: "transparent"
                    show: (ws !== undefined || isActive) && !root.showOsd
                    onClicked: Hyprland.dispatch("workspace " + modelData)
                }
            }
            
            Mod { 
                property int cap: parseInt(root.batteryCap)
                property bool isCrit: cap <= 15 && !root.batteryCharging
                property bool isWarn: cap <= 30 && cap > 15 && !root.batteryCharging
                
                text: {
                    if (root.batteryCharging) return "";
                    if (cap > 80) return "";
                    if (cap > 60) return "";
                    if (cap > 40) return "";
                    if (cap > 20) return "";
                    return "";
                }
                textColor: {
                    if (isCrit) return root.colCrit;
                    if (isWarn) return "#FFA500";
                    if (root.batteryCharging) return "#76B900";
                    return root.colFg;
                }
                bgColor: "transparent"
                blink: isCrit
                show: !controlCenter.show && !root.showOsd
                onClicked: controlCenter.show = true
            }

            Mod {
                property bool isActive: root.stopwatchRunning || root.stopwatchSeconds > 0
                text: "󱎫 " + root.stopwatchText
                textColor: root.stopwatchRunning ? "#FFA500" : root.colFg
                bgColor: "transparent"
                show: isActive && !controlCenter.show && !root.showOsd
                onClicked: controlCenter.show = true
            }
            
            Mod {
                property bool isActive: root.timerRunning || (root.timerSeconds > 0 && root.timerSeconds < root.timerTotal)
                text: "󰔛 " + root.timerText
                textColor: root.timerRunning ? "#FFA500" : root.colFg
                bgColor: "transparent"
                show: isActive && !controlCenter.show && !root.showOsd
                onClicked: controlCenter.show = true
            }
            
            Mod {
                text: root.batteryMode ? "  Power Saver" : "  Performance"
                textColor: root.batteryMode ? "#FFCC00" : "#76B900"
                bgColor: "transparent"
                show: root.showBatteryModeIndicator && !controlCenter.show && !root.showOsd
            }

            Mod {
                text: ""
                textColor: root.micMuted ? root.colMuted : "#FFA500"
                bgColor: "transparent"
                show: root.showMicIndicator && !controlCenter.show && !root.showOsd
            }

            Mod {
                text: ""
                textColor: root.colFg
                bgColor: "transparent"
                show: root.showOsd
                customWidth: 140
                
                Item {
                    anchors.centerIn: parent
                    width: 140
                    height: 16
                    RowLayout {
                        anchors.fill: parent
                        spacing: 8
                        Text {
                            text: root.osdIcon
                            color: root.colFg
                            font { family: root.fontFamily; pixelSize: root.fontSize + 2 }
                        }
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 4
                                radius: 2
                                color: root.colMuted
                                Rectangle {
                                    height: parent.height
                                    width: parent.width * (root.osdValue / 100)
                                    radius: 2
                                    color: root.colFg
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}


    component ModernBatteryIcon: Item {
        id: battIcon
        property real level: 1.0
        property bool charging: false
        property color colFg: root.colFg
        
        implicitWidth: 32
        implicitHeight: 14
        
        Rectangle {
            id: outline
            width: 26
            height: 12
            anchors.verticalCenter: parent.verticalCenter
            color: "transparent"
            border.color: battIcon.colFg
            border.width: 1.5
            radius: 4
            opacity: 0.7
            
            Rectangle {
                id: fill
                x: 2
                y: 2
                width: Math.max(0, (parent.width - 4) * battIcon.level)
                height: parent.height - 4
                radius: 2
                color: {
                    if (battIcon.charging) return "#76B900";
                    if (battIcon.level <= 0.2) return "#FF3B30";
                    return battIcon.colFg;
                }
                Behavior on width { NumberAnimation { duration: root.batteryMode ? 0 : 300; easing.type: Easing.OutCubic } }
            }
        }
        
        // The nub
        Rectangle {
            width: 3
            height: 6
            anchors.left: outline.right
            anchors.leftMargin: 1
            anchors.verticalCenter: parent.verticalCenter
            color: battIcon.colFg
            opacity: 0.7
            radius: 1.5
        }
        
        // Charging bolt
        Text {
            visible: battIcon.charging
            text: ""
            font.pixelSize: 9
            color: "#ffffff"
            anchors.centerIn: outline
        }
    }


    component ModernSplitButton: Item {
        id: mbtn
        property string text
        property string iconText
        property bool isActive: false
        property color accent: root.colFg
        
        signal mainClicked()
        signal iconClicked()
        signal rightIconClicked()
        signal scrolled(int angle)
        
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: mainMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.1)
            border.color: "transparent"
            Behavior on color { ColorAnimation { duration: root.batteryMode ? 0 : 150 } }
        }
        
        MouseArea {
            id: mainMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: mbtn.mainClicked()
            onWheel: wheel => mbtn.scrolled(wheel.angleDelta.y)
        }
        
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 12
            spacing: 8
            
            // Icon Circle Box
            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 16
                color: mbtn.isActive ? mbtn.accent : Qt.rgba(1, 1, 1, 0.15)
                
                Text {
                    anchors.centerIn: parent
                    text: mbtn.iconText
                    color: mbtn.isActive ? "#ffffff" : root.colFg
                    font.family: root.fontFamily
                    font.pixelSize: 16
                }
                
                MouseArea {
                    id: iconMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: mbtn.iconClicked()
                }
                
                scale: iconMouse.containsPress ? 0.9 : (iconMouse.containsMouse ? 1.05 : 1.0)
                Behavior on scale { NumberAnimation { duration: root.batteryMode ? 0 : 150 } }
                Behavior on color { ColorAnimation { duration: root.batteryMode ? 0 : 150 } }
            }
            
            Text { 
                text: mbtn.text
                color: root.colFg
                font.family: root.fontFamily
                font.pixelSize: 14
                font.bold: true
                Layout.fillWidth: true
            }
            
            Item {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                
                Text {
                    anchors.centerIn: parent
                    text: ""
                    color: rightIconMouse.containsMouse ? root.colFg : Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.3)
                    font.family: root.fontFamily
                    font.pixelSize: 16
                    Behavior on color { ColorAnimation { duration: root.batteryMode ? 0 : 150 } }
                }
                
                MouseArea {
                    id: rightIconMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: mbtn.rightIconClicked()
                }
            }
        }
        
        scale: mainMouse.containsPress ? 0.98 : 1.0
        Behavior on scale { NumberAnimation { duration: root.batteryMode ? 0 : 150; easing.type: Easing.OutBack } }
    }

    component ModernButton: MouseArea {
        id: mbtn
        property string text
        property string iconText
        property bool isActive: false
        property color accent: root.colFg
        
        Layout.fillWidth: true
        Layout.preferredHeight: 40
        hoverEnabled: true
        
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: mbtn.isActive ? Qt.rgba(mbtn.accent.r, mbtn.accent.g, mbtn.accent.b, 0.15) 
                                 : (mbtn.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.1))
            border.color: mbtn.isActive ? Qt.rgba(mbtn.accent.r, mbtn.accent.g, mbtn.accent.b, 0.3) : "transparent"
            border.width: 1
            Behavior on color { ColorAnimation { duration: root.batteryMode ? 0 : 150 } }
        }
        
        RowLayout {
            anchors.centerIn: parent
            spacing: 4
            Text { text: mbtn.iconText; color: mbtn.isActive ? mbtn.accent : root.colFg; font.family: root.fontFamily; font.pixelSize: 14 }
            Text { text: mbtn.text; color: mbtn.isActive ? mbtn.accent : root.colFg; font.family: root.fontFamily; font.pixelSize: 11; font.bold: true }
        }
        
        scale: containsPress ? 0.95 : 1.0
        Behavior on scale { NumberAnimation { duration: root.batteryMode ? 0 : 150; easing.type: Easing.OutBack } }
    }

    component ModernSlider: Slider {
        id: mSlider
        Layout.fillWidth: true
        from: 0; to: 1.0
        
        background: Rectangle {
            x: mSlider.leftPadding
            y: mSlider.topPadding + mSlider.availableHeight / 2 - height / 2
            implicitWidth: 200
            implicitHeight: 8
            width: mSlider.availableWidth
            height: implicitHeight
            radius: 4
            color: Qt.rgba(1, 1, 1, 0.1)
            Rectangle {
                width: mSlider.visualPosition * parent.width
                height: parent.height
                color: root.colFg
                radius: 4
            }
        }
        
        handle: Rectangle {
            x: mSlider.leftPadding + mSlider.visualPosition * (mSlider.availableWidth - width)
            y: mSlider.topPadding + mSlider.availableHeight / 2 - height / 2
            implicitWidth: 16
            implicitHeight: 16
            radius: 8
            color: mSlider.pressed ? Qt.rgba(0.8, 0.8, 0.8, 1) : "#ffffff"
            scale: mSlider.pressed || mSlider.hovered ? 1.2 : 1.0
            Behavior on scale { NumberAnimation { duration: root.batteryMode ? 0 : 100 } }
            
        }
    }

    PanelWindow {
        id: controlCenter
        
        WlrLayershell.keyboardFocus: show ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        
        exclusionMode: ExclusionMode.Ignore
        


        property bool show: false
        property real animHeight: animRect.height
        


        
        // Fluid Animation Visibility Logic: Stay mapped until opacity is 0
        visible: show || animRect.opacity > 0
        
        // Increased size
        implicitWidth: 380
        implicitHeight: mainLayout.implicitHeight + 48 + root.height + 8
        color: "transparent"
        
        onShowChanged: {
            if (show) focusTimerCc.start();
            else {
                root.vpnDisconnectTarget = "";
                root.remminaExpanded = false;
                root.audioSinkExpanded = false;
                root.audioSourceExpanded = false;
            }
        }
        
        Timer {
            id: focusTimerCc
            interval: 50
            onTriggered: controlCenterContent.forceActiveFocus()
        }

        Item {
            id: controlCenterContent
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: {
                controlCenter.show = false;
                timerPopup.show = false;
                gpuPopup.show = false;
                notesPopup.show = false;
            }
            
            MouseArea {
                anchors.fill: parent
                enabled: controlCenter.show
                onClicked: {
                    controlCenter.show = false;
                    timerPopup.show = false;
                    gpuPopup.show = false;
                    notesPopup.show = false;
                }
            }
            
            Rectangle {
                id: animRect
                anchors.top: parent.top
                anchors.topMargin: controlCenter.show ? 16 : (root.isBarMode ? 0 : 4)
                anchors.horizontalCenter: parent.horizontalCenter
                
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                }
                
                width: controlCenter.show ? 380 : notchLayout.implicitWidth + 32
                height: controlCenter.show ? (mainLayout.implicitHeight + 32) : 32
                
                color: Qt.rgba(0.02, 0.02, 0.02, 0.95)
                radius: controlCenter.show ? 24 : (root.isBarMode ? 0 : 16)
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: (controlCenter.show || !root.isBarMode) ? 1 : 0
                
                // DYNAMIC ISLAND FLUID ANIMATION
                opacity: (!controlCenter.show && height <= 36) ? 0.0 : 1.0
                
                Behavior on radius { 
                    NumberAnimation { 
                        duration: root.batteryMode ? 0 : controlCenter.show ? 450 : 300
                        easing.type: controlCenter.show ? Easing.OutBack : Easing.OutExpo
                        easing.overshoot: controlCenter.show ? 1.2 : 0 
                    } 
                }
                
                Behavior on width { 
                    NumberAnimation { 
                        duration: root.batteryMode ? 0 : controlCenter.show ? 450 : 300
                        easing.type: controlCenter.show ? Easing.OutBack : Easing.OutExpo
                        easing.overshoot: controlCenter.show ? 1.2 : 0 
                    } 
                }
                Behavior on height { 
                    NumberAnimation { 
                        duration: root.batteryMode ? 0 : controlCenter.show ? 450 : 300
                        easing.type: controlCenter.show ? Easing.OutBack : Easing.OutExpo
                        easing.overshoot: controlCenter.show ? 1.2 : 0 
                    } 
                }
                Behavior on anchors.topMargin { 
                    NumberAnimation { 
                        duration: root.batteryMode ? 0 : controlCenter.show ? 450 : 300
                        easing.type: controlCenter.show ? Easing.OutBack : Easing.OutExpo
                        easing.overshoot: controlCenter.show ? 1.2 : 0 
                    } 
                }
                
                Item {
                    anchors.fill: parent
                    anchors.margins: 16
                    opacity: controlCenter.show ? 1.0 : 0.0
                    Behavior on opacity { 
                        NumberAnimation { 
                            duration: root.batteryMode ? 0 : controlCenter.show ? 300 : 100
                            easing.type: Easing.InOutQuad 
                        } 
                    }
                    clip: true

                    ColumnLayout {
                        id: mainLayout
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        
                    spacing: 8
                    
                    // Header: Clock & Date & Battery
                    RowLayout {
                        Layout.fillWidth: true
                        
                        ColumnLayout {
                            spacing: 4
                            Text {
                                id: clockText
                                color: root.colFg
                                font.family: root.fontFamily
                                font.pixelSize: 24
                                font.bold: true
                                text: Qt.formatDateTime(new Date(), "HH:mm")
                                Timer {
                                    interval: 1000; running: true; repeat: true
                                    onTriggered: clockText.text = Qt.formatDateTime(new Date(), "HH:mm")
                                }
                            }
                            Text {
                                color: root.colMuted
                                font.family: root.fontFamily
                                font.pixelSize: 13
                                text: Qt.formatDateTime(new Date(), "dddd, MMMM d")
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        // Battery Close Button
                        MouseArea {
                            property int cap: parseInt(root.batteryCap)
                            property bool isCrit: cap <= 15 && !root.batteryCharging
                            property bool isWarn: cap <= 30 && cap > 15 && !root.batteryCharging
                            
                            Layout.preferredHeight: 40
                            Layout.preferredWidth: battLayout.implicitWidth + 24
                            hoverEnabled: true
                            onClicked: { controlCenter.show = false }
                            
                            Rectangle {
                                anchors.fill: parent
                                radius: 12
                                color: parent.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.1)
                                Behavior on color { ColorAnimation { duration: root.batteryMode ? 0 : 150 } }
                            }
                            
                            RowLayout {
                                id: battLayout
                                anchors.centerIn: parent
                                spacing: 10
                                Text { 
                                    text: {
                                        let cap = parseInt(root.batteryCap);
                                        if (root.batteryCharging) return "";
                                        if (cap > 80) return "";
                                        if (cap > 60) return "";
                                        if (cap > 40) return "";
                                        if (cap > 20) return "";
                                        return "";
                                    }
                                    color: {
                                        let cap = parseInt(root.batteryCap);
                                        let isCrit = cap <= 15 && !root.batteryCharging;
                                        let isWarn = cap <= 30 && cap > 15 && !root.batteryCharging;
                                        return isCrit ? root.colCrit : (isWarn ? "#FFA500" : (root.batteryCharging ? "#76B900" : root.colFg));
                                    }
                                    font.family: root.fontFamily
                                    font.pixelSize: 18 
                                }
                                Text { 
                                    text: root.batteryCap + "%"
                                    color: root.colFg
                                    font.family: root.fontFamily
                                    font.pixelSize: 14
                                    font.bold: true 
                                }
                            }
                            
                            scale: containsPress ? 0.95 : 1.0
                            Behavior on scale { NumberAnimation { duration: root.batteryMode ? 0 : 150; easing.type: Easing.OutBack } }
                        }
                    }
                    
                    // System Stats (Moved under clock)
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text { text: "󱐋 " + root.powerDraw + (root.powerDraw === "AC" ? "" : "W"); color: root.colMuted; font.family: root.fontFamily; font.pixelSize: 12; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                        Text { text: " " + root.temperature + "°"; color: parseInt(root.temperature) >= 80 ? root.colCrit : root.colMuted; font.family: root.fontFamily; font.pixelSize: 12; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                        Text { text: "󰠯 " + root.updates; color: root.colMuted; font.family: root.fontFamily; font.pixelSize: 12; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; visible: parseInt(root.updates) > 0 }
                    }

                    // Claude Code session usage
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text { text: "󰀖"; color: "#CC785C"; font.family: root.fontFamily; font.pixelSize: 12 }
                        Text { text: "Claude"; color: root.colMuted; font.family: root.fontFamily; font.pixelSize: 12 }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: root.claudeRemainPct + "%"
                            color: root.claudeRemainPct < 20 ? root.colCrit : (root.claudeRemainPct < 40 ? "#FFA500" : root.colMuted)
                            font.family: root.fontFamily; font.pixelSize: 12; font.bold: true
                        }
                        Text { text: root.claudeResetIn; color: root.colMuted; font.family: root.fontFamily; font.pixelSize: 11 }
                        Text { text: "$" + root.claudeWeekCost + "/wk"; color: root.colMuted; font.family: root.fontFamily; font.pixelSize: 11 }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1,1,1,0.1) }
                    
                    // MPRIS Media Player (generic: Spotify, Firefox, etc.)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: root.mprisStatus !== "offline"

                        // Album art + track info
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Rectangle {
                                width: 56; height: 56; radius: 8
                                color: Qt.rgba(1, 1, 1, 0.08)
                                clip: true

                                Image {
                                    id: albumArt
                                    anchors.fill: parent
                                    source: (root.mprisArtUrl.startsWith("file://") || root.mprisArtUrl.startsWith("https://")) ? root.mprisArtUrl : ""
                                    fillMode: Image.PreserveAspectCrop
                                    smooth: true
                                    asynchronous: true
                                    visible: source !== "" && status === Image.Ready
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: albumArt.source === "" || albumArt.status !== Image.Ready
                                    text: root.mprisPlayer === "spotify" ? "" : "󰝚"
                                    color: root.mprisPlayer === "spotify" ? "#1DB954" : root.colMuted
                                    font.family: root.fontFamily
                                    font.pixelSize: 24
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: root.mprisTitle
                                    color: root.colFg
                                    font.family: root.fontFamily; font.pixelSize: 12; font.bold: true
                                    elide: Text.ElideRight; Layout.fillWidth: true
                                }
                                Text {
                                    text: root.mprisArtist
                                    color: root.colMuted
                                    font.family: root.fontFamily; font.pixelSize: 11
                                    elide: Text.ElideRight; Layout.fillWidth: true
                                }
                                Text {
                                    text: root.mprisPlayer
                                    color: root.mprisPlayer === "spotify" ? "#1DB954" : root.colMuted
                                    font.family: root.fontFamily; font.pixelSize: 9; font.bold: true
                                }
                            }
                        }

                        // Progress bar + time labels
                        Item {
                            Layout.fillWidth: true
                            height: 20

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: 4; radius: 2
                                color: Qt.rgba(1, 1, 1, 0.1)

                                Rectangle {
                                    width: parent.width * root.mprisProgress
                                    height: parent.height; radius: 2
                                    color: root.mprisPlayer === "spotify" ? "#1DB954" : root.colFg
                                    Behavior on width { NumberAnimation { duration: root.batteryMode ? 0 : 400 } }
                                }
                            }
                            Text {
                                anchors.left: parent.left; anchors.bottom: parent.bottom
                                text: {
                                    var s = Math.floor(root.mprisPosition / 1000000);
                                    return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + s % 60;
                                }
                                color: root.colMuted; font.family: root.fontFamily; font.pixelSize: 9
                            }
                            Text {
                                anchors.right: parent.right; anchors.bottom: parent.bottom
                                text: {
                                    var s = Math.floor(root.mprisLength / 1000000);
                                    return Math.floor(s / 60) + ":" + (s % 60 < 10 ? "0" : "") + s % 60;
                                }
                                color: root.colMuted; font.family: root.fontFamily; font.pixelSize: 9
                            }
                        }

                        // Controls
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Item { Layout.fillWidth: true }
                            ModernButton { Layout.preferredWidth: 48; Layout.preferredHeight: 40; iconText: "󰒮"; onClicked: { pSpotPrev.running = true } }
                            ModernButton {
                                Layout.preferredWidth: 64; Layout.preferredHeight: 40
                                iconText: root.mprisStatus === "Playing" ? "󰏤" : "󰐊"
                                isActive: root.mprisStatus === "Playing"
                                accent: root.mprisPlayer === "spotify" ? "#1DB954" : root.colFg
                                onClicked: { pSpotPlay.running = true }
                            }
                            ModernButton { Layout.preferredWidth: 48; Layout.preferredHeight: 40; iconText: "󰒭"; onClicked: { pSpotNext.running = true } }
                            Item { Layout.fillWidth: true }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1,1,1,0.1); visible: root.mprisStatus !== "offline" }

                    // Sliders
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        
                        // Volume
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                MouseArea {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    hoverEnabled: true
                                    onClicked: pVolMute.running = true
                                    scale: containsPress ? 0.9 : (containsMouse ? 1.1 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: root.batteryMode ? 0 : 150 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.volumeMuted ? "󰝟" : ""
                                        color: root.volumeMuted ? root.colMuted : root.colFg
                                        font.family: root.fontFamily
                                        font.pixelSize: 18
                                    }
                                }
                                ModernSlider {
                                    value: parseInt(root.volumeOut) / 100.0
                                    onMoved: {
                                        root.volumeOut = Math.round(value * 100) + "%"
                                        pVolSet.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", value.toFixed(2)]
                                        pVolSet.running = true
                                    }
                                }
                                MouseArea {
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 24
                                    hoverEnabled: true
                                    onClicked: {
                                        root.audioSinkExpanded = !root.audioSinkExpanded;
                                        if (root.audioSinkExpanded) pGetSinks.running = true;
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.audioSinkExpanded ? "󰅃" : "󰅀"
                                        color: root.audioSinkExpanded ? root.colFg : root.colMuted
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                    }
                                }
                            }
                            Repeater {
                                model: root.audioSinkExpanded ? audioSinkModel : null
                                delegate: MouseArea {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28
                                    hoverEnabled: true
                                    onClicked: {
                                        root.defaultSink = model.name;
                                        pSetDefaultSink.sinkName = model.name;
                                        pSetDefaultSink.running = true;
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 8
                                        color: parent.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                                    }
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 28
                                        anchors.rightMargin: 8
                                        spacing: 6
                                        Text {
                                            text: model.name === root.defaultSink ? "󰄪" : ""
                                            color: model.name === root.defaultSink ? "#007AFF" : root.colMuted
                                            font.family: root.fontFamily
                                            font.pixelSize: 10
                                        }
                                        Text {
                                            text: model.displayName
                                            color: model.name === root.defaultSink ? root.colFg : root.colMuted
                                            font.family: root.fontFamily
                                            font.pixelSize: 11
                                            font.bold: model.name === root.defaultSink
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }

                        // Mic
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                MouseArea {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    hoverEnabled: true
                                    onClicked: pMicMute.running = true
                                    scale: containsPress ? 0.9 : (containsMouse ? 1.1 : 1.0)
                                    Behavior on scale { NumberAnimation { duration: root.batteryMode ? 0 : 150 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.micMuted ? "" : ""
                                        color: root.micMuted ? root.colMuted : root.colFg
                                        font.family: root.fontFamily
                                        font.pixelSize: 18
                                    }
                                }
                                ModernSlider {
                                    value: parseInt(root.volumeMic) / 100.0
                                    onMoved: {
                                        root.volumeMic = Math.round(value * 100) + "%"
                                        pVolSet.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", value.toFixed(2)]
                                        pVolSet.running = true
                                    }
                                }
                                MouseArea {
                                    Layout.preferredWidth: 20
                                    Layout.preferredHeight: 24
                                    hoverEnabled: true
                                    onClicked: {
                                        root.audioSourceExpanded = !root.audioSourceExpanded;
                                        if (root.audioSourceExpanded) pGetSources.running = true;
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: root.audioSourceExpanded ? "󰅃" : "󰅀"
                                        color: root.audioSourceExpanded ? root.colFg : root.colMuted
                                        font.family: root.fontFamily
                                        font.pixelSize: 11
                                    }
                                }
                            }
                            Repeater {
                                model: root.audioSourceExpanded ? audioSourceModel : null
                                delegate: MouseArea {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28
                                    hoverEnabled: true
                                    onClicked: {
                                        root.defaultSource = model.name;
                                        pSetDefaultSource.sourceName = model.name;
                                        pSetDefaultSource.running = true;
                                    }
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 8
                                        color: parent.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                                    }
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 28
                                        anchors.rightMargin: 8
                                        spacing: 6
                                        Text {
                                            text: model.name === root.defaultSource ? "󰄪" : ""
                                            color: model.name === root.defaultSource ? "#007AFF" : root.colMuted
                                            font.family: root.fontFamily
                                            font.pixelSize: 10
                                        }
                                        Text {
                                            text: model.displayName
                                            color: model.name === root.defaultSource ? root.colFg : root.colMuted
                                            font.family: root.fontFamily
                                            font.pixelSize: 11
                                            font.bold: model.name === root.defaultSource
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                        // Brightness
                        RowLayout {
                            spacing: 8
                            Text { text: "󰃠"; color: root.colFg; font.family: root.fontFamily; font.pixelSize: 18 }
                            ModernSlider {
                                value: parseInt(root.brightnessLevel) / 100.0
                                onMoved: {
                                    root.brightnessLevel = Math.round(value * 100) + "%"
                                    pBrightSet.command = ["brightnessctl", "s", Math.round(value * 100) + "%"]
                                    pBrightSet.running = true
                                }
                            }
                            
                        }

                        // Keyboard Brightness
                        RowLayout {
                            spacing: 8
                            Text { text: "󰌌"; color: root.colFg; font.family: root.fontFamily; font.pixelSize: 18 }
                            ModernSlider {
                                value: parseInt(root.kbdBrightnessLevel) / 3.0
                                stepSize: 1.0 / 3.0
                                snapMode: Slider.SnapAlways
                                onMoved: {
                                    var levels = ["off", "low", "med", "high"];
                                    var idx = Math.round(value * 3);
                                    root.kbdBrightnessLevel = idx.toString();
                                    pKbdBrightSet.command = ["asusctl", "leds", "set", levels[idx]];
                                    pKbdBrightSet.running = true;
                                }
                            }
                        }

                        // Wattage
                        RowLayout {
                            spacing: 8
                            Text { text: "󱐋"; color: root.colFg; font.family: root.fontFamily; font.pixelSize: 18 }
                            ModernSlider {
                                value: (root.cpuWattage - 3) / 42.0
                                onMoved: {
                                    var watts = Math.round(3 + value * 42)
                                    root.cpuWattage = watts
                                    pWattSet.command = ["setwatt", watts.toString()]
                                    pWattSet.running = true
                                }
                            }
                            Text { 
                                text: root.cpuWattage + "W"
                                color: root.colFg
                                font.family: root.fontFamily
                                font.pixelSize: 12
                                Layout.minimumWidth: 24
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        // Battery Limit
                        RowLayout {
                            spacing: 8
                            Text { text: "󰁹"; color: root.colFg; font.family: root.fontFamily; font.pixelSize: 18 }
                            ModernSlider {
                                value: (root.batLimit - 20) / 80.0
                                onMoved: {
                                    var limit = Math.round(20 + value * 80)
                                    root.batLimit = limit
                                    pBatLimitSet.command = ["asusctl", "battery", "limit", limit.toString()]
                                    pBatLimitSet.running = true
                                }
                            }
                            Text {
                                text: root.batLimit + "%"
                                color: root.colFg
                                font.family: root.fontFamily
                                font.pixelSize: 12
                                Layout.minimumWidth: 24
                                horizontalAlignment: Text.AlignRight
                            }
                        }


                    }
                    
                    // Toggles Row 1
                    RowLayout {
                        spacing: 8
                        Layout.fillWidth: true
                        
                        ModernSplitButton {
                            text: "Bluetooth"
                            iconText: root.bluetoothStatus === "on" ? "" : "󰂲"
                            isActive: root.bluetoothStatus === "on"
                            accent: "#007AFF"
                            onMainClicked: { bluetoothMenuPopup.show = true; controlCenter.show = false }
                            onRightIconClicked: { bluetoothMenuPopup.show = true; controlCenter.show = false }
                            onIconClicked: { 
                                root.bluetoothStatus = (root.bluetoothStatus === "on") ? "off" : "on"
                                pBtToggle.running = true 
                            }
                        }
                        
                        ModernSplitButton {
                            text: root.wifiText === "Disconnected" ? "Wi-Fi" : root.wifiText
                            iconText: root.wifiIcon
                            isActive: root.wifiText !== "Disconnected"
                            accent: "#007AFF"
                            onMainClicked: { wifiMenuPopup.show = true; controlCenter.show = false }
                            onRightIconClicked: { wifiMenuPopup.show = true; controlCenter.show = false }
                            onIconClicked: { 
                                root.wifiText = (root.wifiText === "Disconnected") ? "Connecting..." : "Disconnected"
                                root.wifiIcon = (root.wifiText === "Connecting...") ? "󰤨" : "󰤮"
                                pWifiToggle.running = true 
                            }
                        }
                    }
                    
                    // VPN Row (dynamic)
                    Repeater {
                        model: vpnModel
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            ModernSplitButton {
                                Layout.fillWidth: true
                                text: model.connecting ? "Connecting..." : model.name
                                iconText: "󰖂"
                                isActive: model.active
                                accent: "#FF9500"
                                onIconClicked: {
                                    if (model.active) {
                                        root.vpnDisconnectTarget = model.name;
                                    } else {
                                        root.vpnDisconnectTarget = "";
                                        vpnModel.setProperty(index, "connecting", true);
                                        pVpnUp.command = ["nmcli", "con", "up", model.name];
                                        pVpnUp.running = true;
                                    }
                                }
                                onMainClicked: iconClicked()
                                onRightIconClicked: iconClicked()
                            }
                        }
                    }

                    // VPN Disconnect Confirmation
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        visible: root.vpnDisconnectTarget !== ""
                        radius: 12
                        color: Qt.rgba(1, 0.35, 0.2, 0.15)
                        border.color: Qt.rgba(1, 0.35, 0.2, 0.3)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            Text {
                                text: "Disconnect " + root.vpnDisconnectTarget + "?"
                                color: root.colFg
                                font.family: root.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            MouseArea {
                                Layout.preferredWidth: 72
                                Layout.preferredHeight: 32
                                hoverEnabled: true
                                onClicked: root.vpnDisconnectTarget = ""
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: parent.containsMouse ? Qt.rgba(1,1,1,0.15) : Qt.rgba(1,1,1,0.08)
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: "Cancel"
                                    color: root.colMuted
                                    font.family: root.fontFamily
                                    font.pixelSize: 12
                                }
                            }

                            MouseArea {
                                Layout.preferredWidth: 72
                                Layout.preferredHeight: 32
                                hoverEnabled: true
                                onClicked: {
                                    pVpnDown.command = ["nmcli", "con", "down", root.vpnDisconnectTarget];
                                    pVpnDown.running = true;
                                    root.vpnDisconnectTarget = "";
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: parent.containsMouse ? Qt.rgba(1, 0.35, 0.2, 0.5) : Qt.rgba(1, 0.35, 0.2, 0.3)
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: "Disconnect"
                                    color: "#ffffff"
                                    font.family: root.fontFamily
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                        }
                    }

                    // Remmina Section
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    MouseArea {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        hoverEnabled: true
                        onClicked: root.remminaExpanded = !root.remminaExpanded

                        Rectangle {
                            anchors.fill: parent
                            radius: 10
                            color: parent.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent"
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4
                            spacing: 6

                            Text {
                                text: "󰢹"
                                color: "#4A90D9"
                                font.family: root.fontFamily
                                font.pixelSize: 15
                            }
                            Text {
                                text: "Remmina"
                                color: root.colFg
                                font.family: root.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            Text {
                                text: remminaModel.count + " connections"
                                color: root.colMuted
                                font.family: root.fontFamily
                                font.pixelSize: 11
                            }
                            Text {
                                text: root.remminaExpanded ? "󰅃" : "󰅀"
                                color: root.colMuted
                                font.family: root.fontFamily
                                font.pixelSize: 13
                            }
                        }
                    }

                    // Remmina connection list
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        visible: root.remminaExpanded
                        clip: true

                        Repeater {
                            model: remminaModel
                            delegate: Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: (index === 0 || remminaModel.get(index - 1).group !== model.group) ? 50 : 34

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 0

                                    // Group header
                                    Text {
                                        visible: index === 0 || remminaModel.get(index - 1).group !== model.group
                                        text: model.group
                                        color: root.colMuted
                                        font.family: root.fontFamily
                                        font.pixelSize: 10
                                        font.bold: true
                                        leftPadding: 8
                                        topPadding: 6
                                        Layout.fillWidth: true
                                    }

                                    MouseArea {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 32
                                        hoverEnabled: true
                                        onClicked: {
                                            pRemmina.command = ["bash", "-c", "remmina \"$1\" &", "--", model.filePath];
                                            pRemmina.running = true;
                                            root.remminaExpanded = false;
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 8
                                            color: parent.containsMouse ? Qt.rgba(0.29, 0.56, 0.85, 0.2) : Qt.rgba(1,1,1,0.04)
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8

                                            Text {
                                                text: model.proto === "RDP" ? "󰢹" : "󰣀"
                                                color: model.proto === "RDP" ? "#4A90D9" : "#5CB85C"
                                                font.family: root.fontFamily
                                                font.pixelSize: 13
                                            }
                                            Text {
                                                text: model.name
                                                color: root.colFg
                                                font.family: root.fontFamily
                                                font.pixelSize: 12
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                text: model.proto
                                                color: model.proto === "RDP" ? "#4A90D9" : "#5CB85C"
                                                font.family: root.fontFamily
                                                font.pixelSize: 10
                                                font.bold: true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                        visible: root.remminaExpanded
                    }

                    // Toggles Row 3 (Timer and Stopwatch)
                    RowLayout {
                        spacing: 8
                        Layout.fillWidth: true
                        
                        ModernSplitButton {
                            text: root.stopwatchText
                            iconText: "󱎫"
                            isActive: root.stopwatchRunning || root.stopwatchSeconds > 0
                            accent: "#FFA500"
                            onMainClicked: {
                                if (root.stopwatchRunning) {
                                    root.stopwatchRunning = false;
                                } else {
                                    root.stopwatchRunning = true;
                                }
                            }
                            onRightIconClicked: {
                                if (root.stopwatchRunning) {
                                    root.stopwatchRunning = false;
                                } else {
                                    root.stopwatchRunning = true;
                                }
                            }
                            onIconClicked: { 
                                root.stopwatchRunning = false;
                                root.stopwatchSeconds = 0;
                                root.stopwatchText = "00:00";
                            }
                        }
                        
                        ModernSplitButton {
                            id: btnTimer
                            text: root.timerText
                            iconText: "󰔛"
                            isActive: root.timerRunning || (root.timerSeconds > 0 && root.timerSeconds < root.timerTotal)
                            accent: "#FFA500"
                            onMainClicked: {
                                root.pomodoroState = 0;
                                if (root.timerRunning) {
                                    root.timerRunning = false;
                                } else if (root.timerSeconds > 0) {
                                    root.timerRunning = true;
                                } else {
                                    root.timerSeconds = root.timerTotal;
                                    root.timerText = root.formatTime(root.timerTotal);
                                    root.timerRunning = true;
                                }
                            }
                            onIconClicked: { 
                                root.pomodoroState = 0;
                                root.timerRunning = false;
                                root.timerSeconds = 0;
                                root.timerText = root.formatTime(root.timerTotal);
                            }
                            onRightIconClicked: {
                                if (!timerPopup.show) {
                                    var pos = btnTimer.mapToItem(null, 0, 0);
                                    timerPopup.anchorRect = Qt.rect(pos.x, pos.y, btnTimer.width, btnTimer.height);
                                }
                                timerPopup.show = !timerPopup.show;
                                gpuPopup.show = false;
                                notesPopup.show = false;
                            }
                            onScrolled: angle => {
                                root.pomodoroState = 0;
                                if (angle > 0) {
                                    root.timerTotal += 60;
                                } else if (angle < 0 && root.timerTotal >= 120) {
                                    root.timerTotal -= 60;
                                }
                                root.timerRunning = false;
                                root.timerSeconds = 0;
                                root.timerText = root.formatTime(root.timerTotal);
                            }
                        }


                    }

                    // Toggles Row 2 (GPU, Configs, Power Saver)
                    RowLayout {
                        spacing: 8
                        Layout.fillWidth: true
                        
                        ModernButton {
                            id: btnGpu
                            text: root.gpuMode.charAt(0)
                            iconText: "󰢮"
                            isActive: root.gpuMode === "Hybrid" || root.gpuMode === "Nvidia"
                            accent: "#76B900"
                            onClicked: {
                                if (!gpuPopup.show) {
                                    var pos = mapToItem(null, 0, 0);
                                    gpuPopup.anchorRect = Qt.rect(pos.x, pos.y, width, height);
                                }
                                gpuPopup.show = !gpuPopup.show;
                                notesPopup.show = false;
                                timerPopup.show = false;
                            }
                        }
                        ModernButton {
                            id: btnNotes
                            text: ""
                            iconText: ""
                            onClicked: {
                                if (!notesPopup.show) {
                                    var pos = mapToItem(null, 0, 0);
                                    notesPopup.anchorRect = Qt.rect(pos.x, pos.y, width, height);
                                }
                                notesPopup.show = !notesPopup.show;
                                gpuPopup.show = false;
                                timerPopup.show = false;
                            }
                        }
                        ModernButton {
                            id: btnBatteryMode
                            text: ""
                            iconText: root.batteryMode ? "" : ""
                            isActive: root.batteryMode
                            accent: "#FFCC00"
                            onClicked: pToggleBatteryMode.running = true
                        }
                        ModernButton {
                            id: btnPomodoro
                            text: ""
                            iconText: "󰄉"
                            isActive: root.pomodoroState > 0
                            accent: root.pomodoroState === 1 ? "#FF4500" : "#00FA9A"
                            onClicked: {
                                if (root.pomodoroState === 0) {
                                    root.pomodoroState = 1; // Start work
                                    root.timerTotal = root.pomodoroWorkTotal;
                                    root.timerSeconds = root.timerTotal;
                                    root.timerText = root.formatTime(root.timerTotal);
                                    root.timerRunning = true;
                                } else {
                                    root.pomodoroState = 0; // Turn off
                                    root.timerRunning = false;
                                    root.timerSeconds = 0;
                                    root.timerTotal = 300; // Reset to 5m
                                    root.timerText = root.formatTime(root.timerTotal);
                                }
                            }
                        }
                        ModernButton {
                            id: btnOverview
                            iconText: "󱢈"
                            isActive: windowOverviewPopup.show
                            accent: "#007AFF"
                            onClicked: {
                                windowOverviewPopup.show = !windowOverviewPopup.show
                                controlCenter.show = false
                            }
                        }
                    }

                    // Power Row
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        ModernButton {
                            iconText: "󰌾"
                            accent: "#cc9900"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            onClicked: pPowerLock.running = true
                        }
                        ModernButton {
                            iconText: "󰒲"
                            accent: "#5B9BD5"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            onClicked: pPowerSuspend.running = true
                        }

                        ModernButton {
                            iconText: "󰍃"
                            accent: "#FF9500"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            onClicked: pPowerLogout.running = true
                        }
                        ModernButton {
                            iconText: "󰜉"
                            accent: "#5CB85C"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            onClicked: pPowerReboot.running = true
                        }
                        ModernButton {
                            iconText: "󰐥"
                            accent: "#FF3B30"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            onClicked: pPowerShutdown.running = true
                        }
                    }

                    } // End Item wrapper
            }
        }
    }
}

    PopupWindow {
        id: timerPopup
        grabFocus: show
        anchor {
            window: controlCenter
            rect: timerPopup.anchorRect
            edges: Edges.Left | Edges.Top
            gravity: Edges.Left | Edges.Bottom
        }

        property rect anchorRect: Qt.rect(0, 0, 40, 40)
        property bool show: false
        onShowChanged: {
            if (show) {
                timerInput.text = "";
                timerInput.forceActiveFocus();
            }
        }
        property real animHeight: animRectTimer.height
        visible: show || animRectTimer.opacity > 0
        
        implicitWidth: 200
        implicitHeight: layoutTimer.implicitHeight + 32
        color: "transparent"
        
        Item {
            anchors.fill: parent
            
            Rectangle {
                id: animRectTimer
                anchors.fill: parent
                
                anchors.rightMargin: 12
                
                color: Qt.rgba(0.08, 0.08, 0.08, 0.95)
                radius: 16
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1
                
                opacity: timerPopup.show ? 1.0 : 0.0
                scale: timerPopup.show ? 1.0 : 0.95
                x: timerPopup.show ? 0 : 20
                Behavior on opacity { NumberAnimation { duration: root.batteryMode ? 0 : 200 } }
                Behavior on scale { NumberAnimation { duration: root.batteryMode ? 0 : 350; easing.type: Easing.OutBack } }
                Behavior on x { NumberAnimation { duration: root.batteryMode ? 0 : 350; easing.type: Easing.OutBack } }
                
                ColumnLayout {
                    id: layoutTimer
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 16
                    spacing: 8
                    Text { text: "Timer Minutes"; color: Qt.rgba(root.colFg.r, root.colFg.g, root.colFg.b, 0.5); font.family: root.fontFamily; font.pixelSize: 12 }
                    
                    TextField {
                        id: timerInput
                        Layout.fillWidth: true
                        placeholderText: "e.g. 5"
                        color: root.colFg
                        background: Rectangle {
                            color: Qt.rgba(1, 1, 1, 0.1)
                            radius: 8
                            border.color: timerInput.activeFocus ? Qt.rgba(1, 1, 1, 0.3) : "transparent"
                        }
                        font.family: root.fontFamily
                        font.pixelSize: 14
                        onAccepted: {
                            let val = parseInt(text);
                            if (!isNaN(val) && val > 0) {
                                root.pomodoroState = 0;
                                root.timerTotal = val * 60;
                                root.timerSeconds = 0;
                                root.timerText = root.formatTime(root.timerTotal);
                                root.timerRunning = false;
                            }
                            timerPopup.show = false;
                        }
                    }
                }
            }
        }
    }

    PopupWindow {
        id: gpuPopup
        anchor {
            window: controlCenter
            rect: gpuPopup.anchorRect
            edges: Edges.Left | Edges.Top
            gravity: Edges.Left | Edges.Bottom
        }

        property rect anchorRect: Qt.rect(0, 0, 40, 40)
        property bool show: false
        property real animHeight: animRect.height
        visible: show || animRectGpu.opacity > 0
        
        implicitWidth: 200
        implicitHeight: layoutGpu.implicitHeight + 32
        color: "transparent"
        
        Item {
            anchors.fill: parent
            
            Rectangle {
                id: animRectGpu
                anchors.fill: parent
                
                anchors.rightMargin: 12
                
                color: Qt.rgba(0.08, 0.08, 0.08, 0.95)
                radius: 16
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1
                
                opacity: gpuPopup.show ? 1.0 : 0.0
                scale: gpuPopup.show ? 1.0 : 0.95
                x: gpuPopup.show ? 0 : 20
                Behavior on opacity { NumberAnimation { duration: root.batteryMode ? 0 : 200 } }
                Behavior on scale { NumberAnimation { duration: root.batteryMode ? 0 : 350; easing.type: Easing.OutBack } }
                Behavior on x { NumberAnimation { duration: root.batteryMode ? 0 : 350; easing.type: Easing.OutBack } }
                
                ColumnLayout {
                    id: layoutGpu
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 16
                    spacing: 8
                    
                    
                    ModernButton { text: "Integrated"; iconText: "󰍛"; onClicked: { pGpuInt.running = true; gpuPopup.show = false; controlCenter.show = false } }
                    ModernButton { text: "Hybrid"; iconText: "󰢮"; onClicked: { pGpuHyb.running = true; gpuPopup.show = false; controlCenter.show = false } }
                }
            }
        }
    }

    PopupWindow {
        id: notesPopup
        anchor {
            window: controlCenter
            rect: notesPopup.anchorRect
            edges: Edges.Left | Edges.Top
            gravity: Edges.Left | Edges.Bottom
        }

        property rect anchorRect: Qt.rect(0, 0, 40, 40)
        property bool show: false
        property real animHeight: animRect.height
        visible: show || animRectNotes.opacity > 0
        
        implicitWidth: 340
        implicitHeight: layoutNotes.implicitHeight + 32
        color: "transparent"
        
        Item {
            anchors.fill: parent
            
            Rectangle {
                id: animRectNotes
                anchors.fill: parent
                
                anchors.rightMargin: 12
                
                color: Qt.rgba(0.08, 0.08, 0.08, 0.95)
                radius: 16
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1
                
                opacity: notesPopup.show ? 1.0 : 0.0
                scale: notesPopup.show ? 1.0 : 0.95
                x: notesPopup.show ? 0 : 20
                Behavior on opacity { NumberAnimation { duration: root.batteryMode ? 0 : 200 } }
                Behavior on scale { NumberAnimation { duration: root.batteryMode ? 0 : 350; easing.type: Easing.OutBack } }
                Behavior on x { NumberAnimation { duration: root.batteryMode ? 0 : 350; easing.type: Easing.OutBack } }
                
                ColumnLayout {
                    id: layoutNotes
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 16
                    spacing: 8
                    
                    
                    
                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 8
                        columnSpacing: 8
                        
                        ModernButton { Layout.preferredHeight: 40; text: "Hyprland"; onClicked: { pNoteHyprland.running = true; notesPopup.show = false; controlCenter.show = false } }
                        ModernButton { Layout.preferredHeight: 40; text: "Waybar"; onClicked: { pNoteWaybar.running = true; notesPopup.show = false; controlCenter.show = false } }
                        ModernButton { Layout.preferredHeight: 40; text: "Tofi"; onClicked: { pNoteTofi.running = true; notesPopup.show = false; controlCenter.show = false } }
                        ModernButton { Layout.preferredHeight: 40; text: "Kitty"; onClicked: { pNoteKitty.running = true; notesPopup.show = false; controlCenter.show = false } }
                        ModernButton { Layout.preferredHeight: 40; text: "Foot"; onClicked: { pNoteFoot.running = true; notesPopup.show = false; controlCenter.show = false } }
                        ModernButton { Layout.preferredHeight: 40; text: "Ghostty"; onClicked: { pNoteGhostty.running = true; notesPopup.show = false; controlCenter.show = false } }
                        ModernButton { Layout.preferredHeight: 40; text: "Fish"; onClicked: { pNoteFish.running = true; notesPopup.show = false; controlCenter.show = false } }
                        ModernButton { Layout.preferredHeight: 40; text: "Fastfetch"; onClicked: { pNoteFastfetch.running = true; notesPopup.show = false; controlCenter.show = false } }
                        ModernButton { Layout.preferredHeight: 40; text: "Quickshell"; onClicked: { pNoteQuickshell.running = true; notesPopup.show = false; controlCenter.show = false } }
                    }
                }
            }
        }
    }

    PowerMenu {
        id: powerMenuPopup
        shellRoot: root
    }

    AppLauncher {
        id: appLauncherPopup
        shellRoot: root
    }

    ClipboardManager {
        id: clipboardManagerPopup
        shellRoot: root
    }

    ThemeSwitcher {
        id: themeSwitcherPopup
        shellRoot: root
    }

    WallpaperPicker {
        id: wallpaperPickerPopup
        shellRoot: root
    }

    WifiMenu {
        id: wifiMenuPopup
        shellRoot: root
    }

    BluetoothMenu {
        id: bluetoothMenuPopup
        shellRoot: root
    }

    WindowOverview {
        id: windowOverviewPopup
        shellRoot: root
    }

    IpcHandler {
        id: qsIpc
        target: "qsIpc"
        function showOsd(type: string, val: string) {
            val = parseFloat(val);
            if (type === "V") {
                root.osdIcon = val === 0 ? "󰝟" : (val > 50 ? "󰕾" : "󰖀");
                root.osdText = Math.round(val) + "%";
            } else if (type === "B") {
                root.osdIcon = "󰃠";
                root.osdText = Math.round(val) + "%";
            }
            root.osdValue = val;
            root.showOsd = true;
            osdTimer.restart();
        }
        function toggleAppLauncher() {
            appLauncherPopup.show = !appLauncherPopup.show;
        }
        function togglePowerMenu() {
            powerMenuPopup.show = !powerMenuPopup.show;
        }
        function toggleClipboard() {
            clipboardManagerPopup.show = !clipboardManagerPopup.show;
        }
        function toggleThemeSwitcher() {
            themeSwitcherPopup.show = !themeSwitcherPopup.show;
        }
        function toggleWallpaperPicker() {
            wallpaperPickerPopup.show = !wallpaperPickerPopup.show;
        }
        function toggleWifiMenu() {
            wifiMenuPopup.show = !wifiMenuPopup.show;
        }
        function toggleBluetoothMenu() {
            bluetoothMenuPopup.show = !bluetoothMenuPopup.show;
        }
        function toggleControlCenter() {
            controlCenter.show = !controlCenter.show;
        }
        function refreshBatteryMode() {
            pCheckBatteryMode.running = true;
        }
        function toggleWindowOverview() {
            windowOverviewPopup.show = !windowOverviewPopup.show;
        }
        function updateColors(bg: string, fg: string, accent: string) {
            root.colBg     = bg;
            root.colFg     = fg;
            root.colAccent = accent;
        }
    }

    }
