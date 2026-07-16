import Quickshell
import QtQuick
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import Quickshell.Services.Notifications

ShellRoot {
    PanelWindow {
    id: root
    screen: Quickshell.screens.find(s => s.name.startsWith("eDP")) ?? Quickshell.screens[0]

    property color colBg: "#000000"
    property color colFg: "#ffffff"
    property color colAccent: "#FF6A00"
    property color colMuted: Qt.rgba(1, 1, 1, 0.4)
    property color colHover: Qt.rgba(1, 1, 1, 0.1)
    property color colCrit: "#ff0000"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 10 // Reduced font size to match waybar 9px
    property int windowCount: 0
    property bool isBarMode: windowCount === 1
    property real notchWidth: notchLayout.implicitWidth

    property string sysCpu: "0%"
    property string sysRam: "0%"
    property string sysSwap: "0%"
    property string webdavSync: "OK"
    property bool webdavSyncing: false

    property var notificationHistory: []
    property int unreadCount: 0

    property bool isAnyPopupOpen: controlCenter.show || appLauncherPopup.show || clipboardManagerPopup.show || themeSwitcherPopup.show || wifiMenuPopup.show || powerMenuPopup.show || bluetoothMenuPopup.show || wallpaperPickerPopup.show
    property bool isAnyPopupAnimActive: isAnyPopupOpen || controlCenter.animHeight > 36 || appLauncherPopup.animHeight > 36 || clipboardManagerPopup.animHeight > 36 || themeSwitcherPopup.animHeight > 36 || wifiMenuPopup.animHeight > 36 || powerMenuPopup.animHeight > 36 || bluetoothMenuPopup.animHeight > 36 || wallpaperPickerPopup.animHeight > 36

    // 1. monitor of CPU、RAM and SWAP
    Process {
        command: ["sh", "-c", "while true; do \
            cpu=$(top -bn1 | grep \"Cpu(s)\" | awk '{print 100 - $8\"%\"}'); \
            ram=$(free | grep Mem | awk '{print int($3/$2 * 100)\"%\"}'); \
            swap=$(free | grep Swap | awk '{if ($2 > 0) print int($3/$2 * 100)\"%\"; else print \"0%\"}'); \
            echo \"$cpu|$ram|$swap\"; \
            sleep 3; \
        done"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split("|");
                if (p.length === 3) {
                    root.sysCpu = p[0];
                    root.sysRam = p[1];
                    root.sysSwap = p[2];
                }
            }
        }
    }

    // 2. monitor of Obsidian vault backup (obsidian-git 外掛每 5 分鐘 auto-commit/push 到 Gitea)
    Process {
        command: ["sh", "-c", "cd /home/miles/Lab/obsidian-sync || exit 1; \
            while true; do \
                dirty=$(git status --porcelain 2>/dev/null | wc -l); \
                ahead=$(git rev-list --count '@{u}..HEAD' 2>/dev/null); \
                ahead=${ahead:-0}; \
                if [ \"$dirty\" -gt 0 ] || [ \"$ahead\" -gt 0 ]; then \
                    echo \"syncing|PENDING\"; \
                else \
                    echo \"idle|OK\"; \
                fi; \
                sleep 5; \
            done"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split("|");
                if (p.length === 2) {
                    root.webdavSyncing = (p[0] === "syncing");
                    root.webdavSync = p[1];
                }
            }
        }
    }

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

    // 3. Desktop notification daemon (取代 mako/dunst，直接用 quickshell 內建實作並用自家風格顯示)
    NotificationServer {
        id: notificationServer
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true
        onNotification: notif => {
            notif.tracked = true;

            var arr = root.notificationHistory.slice();
            arr.unshift({
                appName: notif.appName || "System",
                summary: notif.summary,
                body: notif.body,
                time: new Date().toLocaleTimeString()
            });
            root.notificationHistory = arr.slice(0, 50);

            if (!notifHistoryPopup.show) root.unreadCount++;
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

    property bool islandActive: root.mprisStatus !== "offline" && root.mprisTitle !== ""
    property var cavaBars: []
    property string barClock: Qt.formatDateTime(new Date(), "HH:mm")
    property bool caffeineOn: false

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

    property string wifiIcon: "WIFI"
    property string wifiText: "Disconnected"

    property bool showOsd: false
    property string osdText: "0%"
    property string osdIcon: "VOL"
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

    Process { id: pPowerLock;     command: ["/home/miles/.local/bin/qs-lock"] }
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
    Process { id: pCaffeineOn; command: ["pkill", "hypridle"] }
    Process { id: pCaffeineOff; command: ["hypridle"] }
    Process { id: pSeek }

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
        command: ["sh", "-c", "while true; do ryzenadj -i 2>/dev/null | awk -F'|' '/STAPM LIMIT/ {print int($3)}'; sleep 10; done"]
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
                if (d === 'disc') { root.wifiIcon = "WIFI"; root.wifiText = "Disconnected"; }
                else {
                    var s = parseInt(d);
                    root.wifiText = s + "%";
                    if (s > 80) root.wifiIcon = "WIFI";
                    else if (s > 60) root.wifiIcon = "WIFI";
                    else if (s > 40) root.wifiIcon = "WIFI";
                    else if (s > 20) root.wifiIcon = "WIFI";
                    else root.wifiIcon = "WIFI";
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

    Timer { interval: 10000; running: true; repeat: true; onTriggered: root.barClock = Qt.formatDateTime(new Date(), "HH:mm") }

    Process {
        id: pCava
        command: ["cava", "-p", "/home/miles/.config/quickshell/cava_bar.ini"]
        running: root.islandActive && !musicPopup.show
        stdout: SplitParser {
            onRead: data => {
                var vals = data.trim().split(";").map(function(v) { return parseInt(v) || 0 })
                if (vals.length > 1) root.cavaBars = vals
            }
        }
    }

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
        width: root.isBarMode
            ? parent.width
            : (root.islandActive ? (notchLayout.implicitWidth + notchLayoutRight.implicitWidth + 224) : notchLayout.implicitWidth + 32)
        color: Qt.rgba(0.02, 0.02, 0.02, 0.95)
        radius: root.isBarMode ? 0 : 16

        Behavior on width { NumberAnimation { duration: root.batteryMode ? 0 : 400; easing.type: Easing.OutExpo } }
        Behavior on radius { NumberAnimation { duration: root.batteryMode ? 0 : 400; easing.type: Easing.OutExpo } }
        Behavior on anchors.topMargin { NumberAnimation { duration: root.batteryMode ? 0 : 400; easing.type: Easing.OutExpo } }
        border.color: Qt.rgba(1, 0.42, 0, 0.5)
        border.width: root.isBarMode ? 0 : 1

        // ── Left: clock ──────────────────────────────────────────────────
        MouseArea {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: 52; height: parent.height
            visible: root.isBarMode && !root.showOsd
            onClicked: controlCenter.show = true
            Text {
                anchors.centerIn: parent
                text: root.barClock
                color: root.colFg
                font.family: root.fontFamily; font.pixelSize: root.fontSize; font.bold: true
            }
        }

        // ── Right: battery ────────────────────────────────────────────────
        MouseArea {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter

            width: root.batteryCharging ? 75 : 55
            height: parent.height
            visible: root.isBarMode && !root.showOsd && !controlCenter.show
            onClicked: controlCenter.show = true

            Text {
                anchors.centerIn: parent
                property int cap: parseInt(root.batteryCap)
                text: root.batteryCharging ? "+" + root.batteryCap + "%" : root.batteryCap + "%"
                color: {
                    var cap = parseInt(root.batteryCap)
                    if (cap <= 15 && !root.batteryCharging) return root.colCrit
                        if (cap <= 30 && !root.batteryCharging) return "#FFA500"
                            if (root.batteryCharging) return "#76B900"
                                return root.colFg
                }
                font.family: root.fontFamily
                font.pixelSize: root.fontSize
                font.bold: true
            }
        }

        RowLayout {
            id: notchLayout
            opacity: root.isAnyPopupOpen ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: root.batteryMode ? 0 : 150 } }
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: root.isBarMode
                ? (root.islandActive ? 90 : (notchRect.width - notchLayout.width) / 2)
                : 16
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
                    show: (ws !== undefined || isActive) && !root.showOsd && (!root.islandActive || modelData <= 5)
                    onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + modelData + " })")
                }
            }

            Mod {
                property int cap: parseInt(root.batteryCap)
                property bool isCrit: cap <= 15 && !root.batteryCharging
                property bool isWarn: cap <= 30 && cap > 15 && !root.batteryCharging

                text: {
                    if (root.batteryCharging) return "BATT";
                    if (cap > 80) return "BATT";
                    if (cap > 60) return "BATT";
                    if (cap > 40) return "BATT";
                    if (cap > 20) return "BATT";
                    return "BATT";
                }
                textColor: {
                    if (isCrit) return root.colCrit;
                    if (isWarn) return "#FFA500";
                    if (root.batteryCharging) return "#76B900";
                    return root.colFg;
                }
                bgColor: "transparent"
                blink: isCrit
                show: !controlCenter.show && !root.showOsd && !root.islandActive
                onClicked: controlCenter.show = true
            }

            Mod {
                property bool isActive: root.stopwatchRunning || root.stopwatchSeconds > 0
                text: "SW " + root.stopwatchText
                textColor: root.stopwatchRunning ? "#FFA500" : root.colFg
                bgColor: "transparent"
                show: isActive && !controlCenter.show && !root.showOsd && !root.islandActive
                onClicked: controlCenter.show = true
            }

            Mod {
                property bool isActive: root.timerRunning || (root.timerSeconds > 0 && root.timerSeconds < root.timerTotal)
                text: "TMR " + root.timerText
                textColor: root.timerRunning ? "#FFA500" : root.colFg
                bgColor: "transparent"
                show: isActive && !controlCenter.show && !root.showOsd && !root.islandActive
                onClicked: controlCenter.show = true
            }

            Mod {
                text: root.batteryMode ? "POWER SAVER" : "PERFORMANCE"
                textColor: root.batteryMode ? "#FFCC00" : "#76B900"
                bgColor: "transparent"
                show: root.showBatteryModeIndicator && !controlCenter.show && !root.showOsd && !root.islandActive
            }

            Mod {
                text: "MIC"
                textColor: root.micMuted ? root.colMuted : "#FFA500"
                bgColor: "transparent"
                show: root.showMicIndicator && !controlCenter.show && !root.showOsd && !root.islandActive
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
                                radius: 0
                                color: root.colMuted
                                Rectangle {
                                    height: parent.height
                                    width: parent.width * (root.osdValue / 100)
                                    radius: 0
                                    color: "#FF6A00"
                                }
                            }
                        }
                    }
                }
            }
        }

        // 播放音樂時，工作區 6-10 移到右側跟左側 1-5 對稱，讓 cava 保持置中
        RowLayout {
            id: notchLayoutRight
            visible: root.islandActive
            opacity: root.isAnyPopupOpen ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: root.batteryMode ? 0 : 150 } }
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: root.isBarMode ? 90 : 16
            height: parent.height
            spacing: 8

            Repeater {
                model: [6, 7, 8, 9, 10]
                Mod {
                    property var ws: Hyprland.workspaces.values.find(w => w.id === modelData)
                    property bool isActive: Hyprland.focusedWorkspace != null && Hyprland.focusedWorkspace.id === modelData

                    text: modelData
                    textColor: isActive ? root.colFg : root.colMuted
                    bgColor: "transparent"
                    show: (ws !== undefined || isActive) && !root.showOsd
                    onClicked: Hyprland.dispatch("hl.dsp.focus({ workspace = " + modelData + " })")
                }
            }
        }

        // 播放中的 cava 視覺化永遠置中於整個動態島，不隨左側工作區/狀態列擠壓
        Item {
            id: cavaCenter
            anchors.centerIn: parent
            width: 160
            height: 20
            visible: root.islandActive && !root.showOsd

            MouseArea {
                anchors.fill: parent
                onClicked: musicPopup.show = !musicPopup.show
            }

            Row {
                anchors.centerIn: parent
                spacing: 3
                opacity: musicPopup.show ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 150 } }
                visible: opacity > 0
                Repeater {
                    model: root.cavaBars
                    Item {
                        width: 4; height: 20
                        Rectangle {
                            width: parent.width
                            height: Math.max(2, Math.round(modelData * 20 / 20))
                            anchors.bottom: parent.bottom; radius: 0
                            color: root.mprisPlayer === "spotify" ? "#FF6A00" : root.colFg
                            Behavior on height { NumberAnimation { duration: 80 } }
                        }
                    }
                }
            }
            Text {
                anchors.centerIn: parent; width: parent.width - 8
                text: root.mprisTitle; color: root.colFg
                font.family: root.fontFamily; font.pixelSize: 11; font.bold: true
                elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                opacity: musicPopup.show ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
        }
    }

    // ── EVA 風格分段式 progress bar：固定寬度、依數值分段上色 ──
    component EvaBar: Item {
        id: evaBar
        property real value: 0 // 0.0 ~ 1.0
        property int segments: 8
        implicitWidth: 50
        implicitHeight: 10

        readonly property color activeColor: {
            if (evaBar.value >= 0.85) return "#FF3B30" // 危險：紅
            if (evaBar.value >= 0.6) return "#FFA500"  // 警戒：橙
            return "#3DDC84"                            // 正常：綠
        }

        Row {
            anchors.fill: parent
            spacing: 2
            Repeater {
                model: evaBar.segments
                Rectangle {
                    width: (evaBar.width - (evaBar.segments - 1) * 2) / evaBar.segments
                    height: evaBar.height
                    color: index < Math.round(evaBar.value * evaBar.segments) ? evaBar.activeColor : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.25)
                }
            }
        }
    }

    // ── 右上角系統動態島 (固定顯示) ──
    Rectangle {
        id: sysIsland
        anchors.right: parent.right
        anchors.rightMargin: root.isBarMode ? 100 : 16
        anchors.top: parent.top
        anchors.topMargin: root.isBarMode ? 0 : 4
        z: 2 // 確保顯示在最上層

        // 寬度依內容自動撐開，避免文字被裁切或溢出動態島
        width: sysRow.implicitWidth + 24
        height: 32
        radius: root.isBarMode ? 0 : 16
        color: Qt.rgba(0.02, 0.02, 0.02, 0.95)
        border.color: Qt.rgba(1, 0.42, 0, 0.5)
        border.width: root.isBarMode ? 0 : 1

        // 寬度平滑動態過渡動畫
        Behavior on width {
            NumberAnimation { duration: root.batteryMode ? 0 : 350; easing.type: Easing.OutExpo }
        }

        // 滑鼠懸停（Hover）或點擊時，可以觸發展開顯示
        MouseArea {
            id: sysIslandClick
            anchors.fill: parent
            hoverEnabled: true

            RowLayout {
                id: sysRow
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // CPU
                RowLayout {
                    spacing: 6
                    Text {
                        text: "CPU"
                        color: root.colMuted
                        font { family: root.fontFamily; pixelSize: root.fontSize }
                    }
                    EvaBar { value: parseFloat(root.sysCpu) / 100 }
                    Text {
                        text: root.sysCpu
                        color: root.colFg
                        font { family: root.fontFamily; pixelSize: root.fontSize }
                    }
                }

                // RAM
                RowLayout {
                    spacing: 6
                    Text {
                        text: "RAM"
                        color: root.colMuted
                        font { family: root.fontFamily; pixelSize: root.fontSize }
                    }
                    EvaBar { value: parseFloat(root.sysRam) / 100 }
                    Text {
                        text: root.sysRam
                        color: root.colFg
                        font { family: root.fontFamily; pixelSize: root.fontSize }
                    }
                }

                // SWAP
                RowLayout {
                    spacing: 6
                    Text {
                        text: "SWAP"
                        color: root.colMuted
                        font { family: root.fontFamily; pixelSize: root.fontSize }
                    }
                    EvaBar { value: parseFloat(root.sysSwap) / 100 }
                    Text {
                        text: root.sysSwap
                        color: root.colFg
                        font { family: root.fontFamily; pixelSize: root.fontSize }
                    }
                }

                // 分隔線
                Rectangle {
                    Layout.fillHeight: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                    width: 1
                    color: Qt.rgba(1, 1, 1, 0.15)
                }

                // Vault 備份狀態（obsidian-git 是否已 commit/push 乾淨）
                Text {
                    text: "SYNC | " + root.webdavSync
                    color: root.webdavSyncing ? "#FFCC00" : "#76B900"
                    font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
                }

                // 分隔線
                Rectangle {
                    Layout.fillHeight: true
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                    width: 1
                    color: Qt.rgba(1, 1, 1, 0.15)
                }

                // 通知歷史（NERV 終端機風格：純文字標籤 + 方角警示紅點）
                Item {
                    id: bellButton
                    implicitWidth: bellLabel.implicitWidth + 10
                    implicitHeight: 20

                    Text {
                        id: bellLabel
                        anchors.centerIn: parent
                        text: "ALERT"
                        color: root.unreadCount > 0 ? "#FF6A00" : root.colMuted
                        font { family: root.fontFamily; pixelSize: root.fontSize; bold: true; letterSpacing: 1 }
                    }

                    Rectangle {
                        visible: root.unreadCount > 0
                        width: 14; height: 14; radius: 2
                        color: "#FF3B30"
                        border.color: Qt.rgba(0, 0, 0, 0.6)
                        border.width: 1
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: -6
                        anchors.rightMargin: -6
                        Text {
                            anchors.centerIn: parent
                            text: root.unreadCount > 9 ? "9+" : String(root.unreadCount)
                            color: "white"
                            font.family: root.fontFamily
                            font.pixelSize: 8
                            font.bold: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            notifHistoryPopup.show = !notifHistoryPopup.show;
                            if (notifHistoryPopup.show) root.unreadCount = 0;
                        }
                    }
                }
            }
        }
    }
}

// ── 通知堆疊：取代 mako/dunst，顯示在右上角，跟 sysIsland 同一套視覺風格 ──
PopupWindow {
    id: notificationPopup
    anchor {
        window: root
        rect: Qt.rect(0, root.isBarMode ? 32 : 40, root.width, 1)
        edges: Edges.Top | Edges.Right
        gravity: Edges.Bottom | Edges.Left
    }
    color: "transparent"
    implicitWidth: 340
    implicitHeight: notifColumn.implicitHeight + 16
    visible: notificationServer.trackedNotifications.values.length > 0

    ColumnLayout {
        id: notifColumn
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.topMargin: 8
        spacing: 8

        Repeater {
            model: notificationServer.trackedNotifications

            delegate: Rectangle {
                id: notifCard
                required property var modelData

                Layout.preferredWidth: 320
                Layout.preferredHeight: notifContent.implicitHeight + 24
                radius: 0
                color: Qt.rgba(0.02, 0.02, 0.02, 0.95)
                border.color: Qt.rgba(1, 0.42, 0, 0.5)
                border.width: 1

                // NERV 終端機風格左側警示條
                Rectangle {
                    width: 3
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    color: "#FF6A00"
                }

                // 依通知標示的 expire timeout 自動關閉，沒指定則預設 5 秒
                Timer {
                    running: true
                    interval: notifCard.modelData.expireTimeout > 0 ? notifCard.modelData.expireTimeout : 5000
                    onTriggered: notifCard.modelData.expire()
                }

                ColumnLayout {
                    id: notifContent
                    anchors.fill: parent
                    anchors.margins: 12
                    anchors.leftMargin: 16
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Text {
                            text: notifCard.modelData.appName.toUpperCase()
                            color: "#FF6A00"
                            font { family: root.fontFamily; pixelSize: root.fontSize + 2; bold: true; letterSpacing: 1 }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "[X]"
                            color: root.colMuted
                            font { family: root.fontFamily; pixelSize: root.fontSize + 2; bold: true }
                            MouseArea { anchors.fill: parent; onClicked: notifCard.modelData.dismiss() }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(1, 0.42, 0, 0.25)
                    }
                    Text {
                        Layout.fillWidth: true
                        text: notifCard.modelData.summary
                        color: root.colFg
                        wrapMode: Text.Wrap
                        font { family: root.fontFamily; pixelSize: root.fontSize + 3; bold: true }
                    }
                    Text {
                        Layout.fillWidth: true
                        visible: notifCard.modelData.body.length > 0
                        text: notifCard.modelData.body
                        color: root.colMuted
                        wrapMode: Text.Wrap
                        font { family: root.fontFamily; pixelSize: root.fontSize + 2 }
                    }
                }
            }
        }
    }
}

// ── 通知歷史清單：點右上角小鈴鐺開關 ──
PopupWindow {
    id: notifHistoryPopup
    property bool show: false
    grabFocus: show
    visible: show
    anchor {
        window: root
        rect: Qt.rect(0, root.isBarMode ? 32 : 40, root.width, 1)
        edges: Edges.Top | Edges.Right
        gravity: Edges.Bottom | Edges.Left
    }
    color: "transparent"
    implicitWidth: 340
    implicitHeight: Math.min(historyCard.implicitHeight, 480)

    Rectangle {
        id: historyCard
        width: 340
        implicitHeight: historyColumn.implicitHeight + 24
        radius: 0
        color: Qt.rgba(0.02, 0.02, 0.02, 0.97)
        border.color: Qt.rgba(1, 0.42, 0, 0.5)
        border.width: 1

        ColumnLayout {
            id: historyColumn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "NOTIFICATIONS"
                    color: "#FF6A00"
                    font { family: root.fontFamily; pixelSize: root.fontSize + 3; bold: true; letterSpacing: 1 }
                }
                Item { Layout.fillWidth: true }
                Text {
                    visible: root.notificationHistory.length > 0
                    text: "[CLEAR]"
                    color: root.colMuted
                    font { family: root.fontFamily; pixelSize: root.fontSize + 2; bold: true }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.notificationHistory = []
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 0.42, 0, 0.25)
            }

            Text {
                Layout.fillWidth: true
                visible: root.notificationHistory.length === 0
                text: "NO SIGNAL"
                color: root.colMuted
                font { family: root.fontFamily; pixelSize: root.fontSize + 2; letterSpacing: 1 }
            }

            Repeater {
                model: root.notificationHistory

                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: entryCol.implicitHeight + 16
                    radius: 0
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.color: Qt.rgba(1, 0.42, 0, 0.2)
                    border.width: 1

                    Rectangle {
                        width: 3
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        color: "#FF6A00"
                    }

                    ColumnLayout {
                        id: entryCol
                        anchors.fill: parent
                        anchors.margins: 8
                        anchors.leftMargin: 12
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: modelData.appName.toUpperCase()
                                color: "#FF6A00"
                                font { family: root.fontFamily; pixelSize: root.fontSize + 1; bold: true; letterSpacing: 1 }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: modelData.time
                                color: "#3DDC84"
                                font { family: root.fontFamily; pixelSize: root.fontSize }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.summary
                            color: root.colFg
                            wrapMode: Text.Wrap
                            font { family: root.fontFamily; pixelSize: root.fontSize + 2; bold: true }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: modelData.body.length > 0
                            text: modelData.body
                            color: root.colMuted
                            wrapMode: Text.Wrap
                            font { family: root.fontFamily; pixelSize: root.fontSize + 1 }
                        }
                    }
                }
            }
        }
    }
}

PopupWindow {
    id: musicPopup
    property bool show: false
    grabFocus: show
    visible: show || musicCard.opacity > 0
    color: "transparent"
    anchor {
        window: root
        rect: Qt.rect(root.width / 2 - 180, 0, 360, root.height)
        edges: Edges.Bottom
        gravity: Edges.Bottom
    }
    implicitWidth: 400
    implicitHeight: 400

    Rectangle {
        id: musicCard
        anchors.fill: parent
        anchors.topMargin: 12
        focus: musicPopup.show
        Keys.onEscapePressed: musicPopup.show = false

        // NERV 終端機風格
        color: Qt.rgba(0.05, 0.05, 0.05, 0.88)
        radius: 0
        opacity: musicPopup.show ? 1 : 0
        border.color: Qt.rgba(1, 0.42, 0, 0.5)
        border.width: 1

        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuint } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24 // 加大留白，提升呼吸感
            spacing: 20

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 160
                Layout.preferredHeight: 160
                radius: 0
                border.color: Qt.rgba(1, 0.42, 0, 0.3)
                border.width: 1
                color: "#161616"
                clip: true

                // 封面陰影/發光效果
                layer.enabled: true

                Image {
                    id: musicArt
                    anchors.fill: parent
                    source: (root.mprisArtUrl.startsWith("file://") || root.mprisArtUrl.startsWith("https://")) ? root.mprisArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    smooth: true
                    asynchronous: true
                    visible: source !== "" && status === Image.Ready
                }

                // 封面未載入時的現代替代圖標
                Text {
                    anchors.centerIn: parent
                    text: "NOTE"
                    color: root.mprisPlayer === "spotify" ? "#FF6A00" : root.colMuted
                    font.family: root.fontFamily
                    font.pixelSize: 16
                    font.bold: true
                    font.letterSpacing: 1
                    visible: musicArt.source === "" || musicArt.status !== Image.Ready
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    text: root.mprisTitle !== "" ? root.mprisTitle : "未在播放音樂"
                    color: "#FFFFFF"
                    font.family: root.fontFamily
                    font.pixelSize: 16
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: root.mprisArtist !== "" ? root.mprisArtist : "未知藝術家"
                    color: root.mprisPlayer === "spotify" ? "#FF6A00" : root.colMuted
                    font.family: root.fontFamily
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Item {
                    Layout.fillWidth: true
                    height: 12

                    // 進度條軌道
                    Rectangle {
                        id: progressBarTrack
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 4 // 超纖細軌道
                        radius: 0
                        color: Qt.rgba(1, 1, 1, 0.1)

                        Rectangle {
                            id: seekFill
                            width: parent.width * root.mprisProgress
                            height: parent.height
                            radius: 0
                            color: "#FF6A00"
                        }
                    }

                    Rectangle {
                        id: progressHandle
                        x: Math.max(0, Math.min(parent.width - width, parent.width * root.mprisProgress - width/2))
                        anchors.verticalCenter: parent.verticalCenter
                        width: progressMouseArea.containsMouse ? 12 : 0
                        height: width
                        radius: 0
                        color: "#FFFFFF"
                        Behavior on width { NumberAnimation { duration: 120 } }
                    }

                    MouseArea {
                        id: progressMouseArea
                        anchors.fill: parent
                        anchors.margins: -6 // 加大滑鼠判定範圍
                        hoverEnabled: true
                        preventStealing: true

                        function seek(mx) {
                            if (root.mprisLength > 0) {
                                var sec = Math.max(0, Math.min(1, mx / width)) * root.mprisLength / 1000000
                                pSeek.command = ["playerctl", "position", String(Math.round(sec))]
                                pSeek.running = true
                            }
                        }
                        onClicked: function(mouse) { seek(mouse.x) }
                        onPositionChanged: function(mouse) { if (pressed) seek(mouse.x) }
                    }
                }

                // 重新排列至進度條下方的時間標籤
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: { var s=Math.floor(root.mprisPosition/1000000); return Math.floor(s/60)+":"+(s%60<10?"0":"")+s%60 }
                        color: root.colMuted; font.family: root.fontFamily; font.pixelSize: 10
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: { var s=Math.floor(root.mprisLength/1000000); return Math.floor(s/60)+":"+(s%60<10?"0":"")+s%60 }
                        color: root.colMuted; font.family: root.fontFamily; font.pixelSize: 10
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 8
                spacing: 24

                Item { Layout.fillWidth: true }

                // 上一首
                MouseArea {
                    id: btnPrev
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40
                    hoverEnabled: true
                    onClicked: pSpotPrev.running = true
                    Rectangle { anchors.fill: parent; radius: 0; border.color: Qt.rgba(1, 0.42, 0, 0.3); border.width: 1; color: parent.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent" }
                    Text { anchors.centerIn: parent; text: "[<<]"; color: "#FFF"; font.family: root.fontFamily; font.pixelSize: 12; font.bold: true }
                }

                // 播放 / 暫停（主按鈕放大、圓環焦點）
                MouseArea {
                    id: btnPlay
                    Layout.preferredWidth: 54; Layout.preferredHeight: 54
                    hoverEnabled: true
                    onClicked: pSpotPlay.running = true
                    Rectangle {
                        anchors.fill: parent
                        radius: 0
                        color: root.mprisStatus === "Playing" ? (root.mprisPlayer === "spotify" ? "#FF6A00" : root.colFg) : Qt.rgba(1, 1, 1, 0.1)
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: root.mprisStatus === "Playing" ? "[||]" : "[>]"
                        color: root.mprisStatus === "Playing" ? "#000000" : "#FFFFFF" // 播放時反白
                        font.family: root.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                    }
                }

                // 下一首
                MouseArea {
                    id: btnNext
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40
                    hoverEnabled: true
                    onClicked: pSpotNext.running = true
                    Rectangle { anchors.fill: parent; radius: 0; border.color: Qt.rgba(1, 0.42, 0, 0.3); border.width: 1; color: parent.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent" }
                    Text { anchors.centerIn: parent; text: "[>>]"; color: "#FFF"; font.family: root.fontFamily; font.pixelSize: 12; font.bold: true }
                }

                Item { Layout.fillWidth: true }
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
            radius: 0
            opacity: 0.7

            Rectangle {
                id: fill
                x: 2
                y: 2
                width: Math.max(0, (parent.width - 4) * battIcon.level)
                height: parent.height - 4
                radius: 0
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
            radius: 0
        }

        // Charging bolt
        Text {
            visible: battIcon.charging
            text: "+"
            font.pixelSize: 10
            font.bold: true
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
            radius: 0
            color: mainMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.1)
            border.color: Qt.rgba(1, 0.42, 0, 0.3)
            border.width: 1
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
                radius: 0
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
                    text: ">"
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
            radius: 0
            color: mbtn.isActive ? Qt.rgba(mbtn.accent.r, mbtn.accent.g, mbtn.accent.b, 0.15)
                                 : (mbtn.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.1))
            border.color: mbtn.isActive ? Qt.rgba(mbtn.accent.r, mbtn.accent.g, mbtn.accent.b, 0.3) : Qt.rgba(1, 0.42, 0, 0.25)
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
            radius: 0
            color: Qt.rgba(1, 1, 1, 0.1)
            border.color: Qt.rgba(1, 0.42, 0, 0.25)
            border.width: 1
            Rectangle {
                width: mSlider.visualPosition * parent.width
                height: parent.height
                color: "#FF6A00"
                radius: 0
            }
        }

        handle: Rectangle {
            x: mSlider.leftPadding + mSlider.visualPosition * (mSlider.availableWidth - width)
            y: mSlider.topPadding + mSlider.availableHeight / 2 - height / 2
            implicitWidth: 16
            implicitHeight: 16
            radius: 0
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
                border.color: Qt.rgba(1, 0.42, 0, 0.5)
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

                    /// Header: Clock & Date & Battery
                    RowLayout {
                        Layout.fillWidth: true

                        ColumnLayout {
                            spacing: 4

                            // 1. time text
                            Text {
                                id: clockText
                                color: root.colFg
                                font.family: root.fontFamily
                                font.pixelSize: 24
                                font.bold: true
                                // 初始化顯示
                                text: Qt.formatDateTime(new Date(), "HH:mm:ss tt")

                                // timer
                                Timer {
                                    interval: 1000
                                    running: true
                                    repeat: true
                                    onTriggered: {
                                        var currentDate = new Date();
                                        clockText.text = Qt.formatDateTime(currentDate, "HH:mm:ss tt");
                                        dateText.text = Qt.formatDateTime(currentDate, "dddd, MMMM d");
                                    }
                                }
                            }

                            // 2. date text
                            Text {
                                id: dateText
                                color: root.colMuted
                                font.family: root.fontFamily
                                font.pixelSize: 13
                                // init
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
                                        if (root.batteryCharging) return "BATT";
                                        if (cap > 80) return "BATT";
                                        if (cap > 60) return "BATT";
                                        if (cap > 40) return "BATT";
                                        if (cap > 20) return "BATT";
                                        return "BATT";
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

                        Text { text: "PWR " + root.powerDraw + (root.powerDraw === "AC" ? "" : "W"); color: root.colMuted; font.family: root.fontFamily; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                        Text { text: "TEMP " + root.temperature + "°"; color: parseInt(root.temperature) >= 80 ? root.colCrit : root.colMuted; font.family: root.fontFamily; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                        Text { text: "UPD " + root.updates; color: root.colMuted; font.family: root.fontFamily; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; visible: parseInt(root.updates) > 0 }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.rgba(1,0.42,0,0.25); visible: root.mprisStatus !== "offline" }

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
                                        text: root.volumeMuted ? "MUTE" : "VOL"
                                        color: root.volumeMuted ? root.colMuted : root.colFg
                                        font.family: root.fontFamily
                                        font.pixelSize: 8
                                        font.bold: true
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
                                        text: root.audioSinkExpanded ? "v" : ">"
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
                                        radius: 0
                                        color: parent.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                                    }
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 28
                                        anchors.rightMargin: 8
                                        spacing: 6
                                        Text {
                                            text: model.name === root.defaultSink ? "*" : ""
                                            color: model.name === root.defaultSink ? "#FF6A00" : root.colMuted
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
                                        text: root.micMuted ? "MUTE" : "MIC"
                                        color: root.micMuted ? root.colMuted : root.colFg
                                        font.family: root.fontFamily
                                        font.bold: true
                                        font.pixelSize: 8
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
                                        text: root.audioSourceExpanded ? "v" : ">"
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
                                        radius: 0
                                        color: parent.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
                                    }
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 28
                                        anchors.rightMargin: 8
                                        spacing: 6
                                        Text {
                                            text: model.name === root.defaultSource ? "*" : ""
                                            color: model.name === root.defaultSource ? "#FF6A00" : root.colMuted
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
                            iconText: "BT"
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
                            iconText: "WIFI"
                            isActive: root.wifiText !== "Disconnected"
                            accent: "#007AFF"
                            onMainClicked: { wifiMenuPopup.show = true; controlCenter.show = false }
                            onRightIconClicked: { wifiMenuPopup.show = true; controlCenter.show = false }
                            onIconClicked: {
                                root.wifiText = (root.wifiText === "Disconnected") ? "Connecting..." : "Disconnected"
                                root.wifiIcon = (root.wifiText === "Connecting...") ? "WIFI" : "WIFI"
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
                                iconText: "VPN"
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
                        radius: 0
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
                                    radius: 0
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
                                    radius: 0
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
                        color: Qt.rgba(1, 0.42, 0, 0.2)
                    }

                    MouseArea {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36
                        hoverEnabled: true
                        onClicked: root.remminaExpanded = !root.remminaExpanded

                        Rectangle {
                            anchors.fill: parent
                            radius: 0
                            color: parent.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent"
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 4
                            anchors.rightMargin: 4
                            spacing: 6

                            Text {
                                text: "RM"
                                color: "#4A90D9"
                                font.family: root.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                            }
                            Text {
                                text: "REMMINA"
                                color: root.colFg
                                font.family: root.fontFamily
                                font.pixelSize: 13
                                font.bold: true
                                font.letterSpacing: 1
                                Layout.fillWidth: true
                            }
                            Text {
                                text: remminaModel.count + " connections"
                                color: root.colMuted
                                font.family: root.fontFamily
                                font.pixelSize: 11
                            }
                            Text {
                                text: root.remminaExpanded ? "v" : ">"
                                color: root.colMuted
                                font.family: root.fontFamily
                                font.pixelSize: 13
                                font.bold: true
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
                                            onClicked: {
                                                // 1. 先強制停止/重置上一次的行程狀態（依據 QuickShell API，通常是 terminate() 或 stop()）
                                                if (pRemmina.running) {
                                                    pRemmina.terminate();
                                                }

                                                // 2. 重新指派指令並啟動
                                                pRemmina.command = ["remmina", "--connect", model.filePath];
                                                pRemmina.running = true;
                                                root.remminaExpanded = false;
                                            }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 0
                                            color: parent.containsMouse ? Qt.rgba(0.29, 0.56, 0.85, 0.2) : Qt.rgba(1,1,1,0.04)
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            spacing: 8

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
                        color: Qt.rgba(1, 0.42, 0, 0.2)
                        visible: root.remminaExpanded
                    }

                    // Toggles Row 3 (Timer and Stopwatch)
                    RowLayout {
                        spacing: 8
                        Layout.fillWidth: true

                        ModernSplitButton {
                            text: root.stopwatchText
                            iconText: "SW"
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
                            iconText: "TMR"
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
                            iconText: "GPU"
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
                            iconText: "NOTE"
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
                            iconText: root.batteryMode ? "ECO" : "PERF"
                            isActive: root.batteryMode
                            accent: "#FFCC00"
                            onClicked: pToggleBatteryMode.running = true
                        }
                        ModernButton {
                            id: btnPomodoro
                            text: ""
                            iconText: "POMO"
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
                            iconText: "OVW"
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
                        color: Qt.rgba(1, 0.42, 0, 0.2)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        ModernButton {
                            iconText: "LOCK"
                            accent: "#cc9900"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            onClicked: pPowerLock.running = true
                        }
                        ModernButton {
                            iconText: "ZZZ"
                            accent: "#5B9BD5"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            onClicked: pPowerSuspend.running = true
                        }

                        ModernButton {
                            iconText: "EXIT"
                            accent: "#FF9500"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            onClicked: pPowerLogout.running = true
                        }
                        ModernButton {
                            iconText: "RST"
                            accent: "#5CB85C"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            onClicked: pPowerReboot.running = true
                        }
                        ModernButton {
                            iconText: "PWR"
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
                radius: 0
                border.color: Qt.rgba(1, 0.42, 0, 0.5)
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
                    Text { text: "TIMER MINUTES"; color: "#FF6A00"; font.family: root.fontFamily; font.pixelSize: 12; font.bold: true; font.letterSpacing: 1 }

                    TextField {
                        id: timerInput
                        Layout.fillWidth: true
                        placeholderText: "e.g. 5"
                        color: root.colFg
                        background: Rectangle {
                            color: Qt.rgba(1, 1, 1, 0.1)
                            radius: 0
                            border.color: timerInput.activeFocus ? Qt.rgba(1, 0.42, 0, 0.5) : "transparent"
                            border.width: 1
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
                radius: 0
                border.color: Qt.rgba(1, 0.42, 0, 0.5)
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


                    ModernButton { text: "Integrated"; iconText: ""; onClicked: { pGpuInt.running = true; gpuPopup.show = false; controlCenter.show = false } }
                    ModernButton { text: "Hybrid"; iconText: ""; onClicked: { pGpuHyb.running = true; gpuPopup.show = false; controlCenter.show = false } }
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
                radius: 0
                border.color: Qt.rgba(1, 0.42, 0, 0.5)
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

    KeyOverlay {
        id: keyOverlayPopup
        shellRoot: root
    }

    IpcHandler {
        id: qsIpc
        target: "qsIpc"
        function showOsd(type: string, val: string) {
            val = parseFloat(val);
            if (type === "V") {
                root.osdIcon = val === 0 ? "MUTE" : "VOL";
                root.osdText = Math.round(val) + "%";
            } else if (type === "B") {
                root.osdIcon = "BRT";
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
        function stepWindowOverview(delta: string) {
            if (!windowOverviewPopup.show) windowOverviewPopup.show = true;
            windowOverviewPopup.moveSelCell(parseInt(delta));
        }
        function toggleKeyOverlay() {
            keyOverlayPopup.show = !keyOverlayPopup.show;
        }
        function updateColors(bg: string, fg: string, accent: string) {
            root.colBg     = bg;
            root.colFg     = fg;
            root.colAccent = accent;
        }
        function lock() {
            lockScreen.activate()
        }
    }

    LockScreen { id: lockScreen }
    }
