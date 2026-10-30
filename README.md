# hypr-config

個人 Hyprland 桌面環境設定。

## 組成

- **WM**: [Hyprland](https://hyprland.org/) — Wayland tiling compositor，Lua 設定
- **Bar / UI**: [Quickshell](https://quickshell.com/) — QML top bar，含 control center、VPN 切換、Remmina 快速連線
- **Terminal**: [Foot](https://codeberg.org/dnkl/foot)
- **Shell**: Fish
- **App Launcher**: tofi
- **Notification**: mako

## 目錄結構

```
bin/          # smart_*.sh IPC wrapper（quickshell ipc 用）
fish/         # Fish shell 設定
foot/         # Foot 終端機設定
gnupg/        # ~/.gnupg/gpg-agent.conf
hypr/
  lua/        # keybindings, programs, input, autostart
  modules/    # windowrules, look_and_feel, input
  themes/     # 多主題 color scheme
kde/          # ~/.config/kdeglobals（KDE 顏色/widget style）
qt6ct/        # ~/.config/qt6ct/qt6ct.conf（Qt6 非 KDE app 樣式）
quickshell/   # shell.qml 主 UI
waybar/       # 備用 waybar 設定
zsh/          # ~/.zshenv（QT_QPA_PLATFORMTHEME 等環境變數）
```

## 注意事項

重啟 quickshell 需從 Hyprland 內的終端機執行，不可從 SSH session 或外部 shell 啟動：

```bash
pkill quickshell && quickshell &
```
