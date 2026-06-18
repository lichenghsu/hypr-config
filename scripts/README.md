# scripts/

Custom shell scripts used by Hyprland keybindings.

## Deploy

Copy all scripts to `~/.local/bin/` and make executable:

```bash
cp scripts/*.sh ~/.local/bin/
chmod +x ~/.local/bin/*.sh
```

---

## hypr_window_picker.sh

**Trigger:** `SUPER + X`

A fuzzy window switcher using `tofi`. Lists all open windows across workspaces, lets you search by title or class, and jumps to the selected window.

**Dependencies:** `tofi`, `python3`, `hyprctl`

**Notes:**
- Requires Hyprland with Lua config (0.45+). Uses `hyprctl eval` to focus windows because `hyprctl dispatch focuswindow address:0x...` breaks under the Lua parser (colon in argument causes Lua syntax error).
- Colors match the theme: `#3a8fbf` (blue accent) / `#ff4b30` (orange accent) on `#000000` background.
- Window list is sorted: normal workspaces first (ascending), special workspaces last.
