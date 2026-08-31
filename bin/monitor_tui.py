#!/usr/bin/env python3
"""fzf-based TUI to change a monitor's mode/scale/position live and
persist the choice into hypr/lua/monitors.lua.

Needed because this Hyprland setup runs Lua config: `hyprctl keyword monitor`
and the legacy `.conf` monitor= lines are both dead here (Hyprland refuses
`keyword` under a non-legacy/Lua parser, and hypr/monitors.conf is no longer
sourced meaningfully once hypr/lua/monitors.lua's wildcard hl.monitor() rule
wins). The only way to change a monitor live is `hyprctl eval 'hl.monitor({...})'`,
and the only way to make it survive a reload/reboot is editing monitors.lua
directly -- so this script does both from one place instead of hand-editing
Lua and remembering the eval incantation each time.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

MONITORS_LUA = Path.home() / "Lab/hypr/dotfiles/hypr/lua/monitors.lua"

SCALE_PRESETS = ["1", "1.25", "1.5", "1.75", "2"]


def fzf(items, prompt):
    proc = subprocess.run(
        ["fzf", "--prompt", prompt, "--height=~50%", "--reverse"],
        input="\n".join(items),
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0 or not proc.stdout.strip():
        sys.exit("cancelled")
    return proc.stdout.strip()


def get_monitors():
    out = subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


def pick_monitor(monitors):
    lines = [
        f"{m['name']}  {m['width']}x{m['height']}@{m['refreshRate']:.0f}  scale={m['scale']}  ({m['description']})"
        for m in monitors
    ]
    choice = fzf(lines, "monitor> ")
    name = choice.split()[0]
    return next(m for m in monitors if m["name"] == name)


def pick_mode(mon):
    modes = []
    seen = set()
    for raw in mon.get("availableModes", []):
        m = raw.replace("Hz", "").replace(".00", "")
        if m not in seen:
            seen.add(m)
            modes.append(m)
    # common downscaled presets keeping the native aspect ratio, dedup'd
    w, h = mon["width"], mon["height"]
    for divisor in (1.5, 2):
        pw, ph = round(w / divisor / 2) * 2, round(h / divisor / 2) * 2
        cand = f"{pw}x{ph}@60"
        if cand not in seen:
            seen.add(cand)
            modes.append(cand)
    # standard resolutions whose aspect ratio matches this panel (e.g. 2K/1440p
    # on a 16:9 main monitor). Hyprland rejects anything the panel can't do, so
    # offering an unsupported one just fails on apply.
    native_ratio = w / h
    for cw, ch in ((3840, 2160), (2560, 1440), (1920, 1080), (1600, 900)):
        if abs(cw / ch - native_ratio) < 0.02:
            cand = f"{cw}x{ch}@60"
            if cand not in seen:
                seen.add(cand)
                modes.append(cand)
    modes.append("custom (type WxH@RR)")
    choice = fzf(modes, "mode> ")
    if choice.startswith("custom"):
        choice = input("mode (e.g. 1920x1200@60): ").strip()
    return choice


def pick_scale():
    choice = fzf(SCALE_PRESETS + ["custom"], "scale> ")
    if choice == "custom":
        choice = input("scale (e.g. 1.33): ").strip()
    return choice


def pick_position(mon):
    current = f"{mon['x']}x{mon['y']} (current)"
    choice = fzf([current, "auto", "custom (type Xx Y)"], "position> ")
    if choice.startswith("custom"):
        return input("position (e.g. 1920x0): ").strip()
    if choice == "auto":
        return "auto"
    return f"{mon['x']}x{mon['y']}"


def apply_live(output, mode, position, scale):
    lua = f'hl.monitor({{output="{output}", mode="{mode}", position="{position}", scale="{scale}"}})'
    subprocess.run(["hyprctl", "eval", lua], check=True)


def persist(output, mode, position, scale):
    text = MONITORS_LUA.read_text()
    block = (
        f'hl.monitor({{ output = "{output}", mode = "{mode}", '
        f'position = "{position}", scale = "{scale}" }})'
    )
    pattern = re.compile(
        r'hl\.monitor\(\{\s*output\s*=\s*"' + re.escape(output) + r'".*?\}\)',
        re.DOTALL,
    )
    if pattern.search(text):
        text = pattern.sub(block, text, count=1)
    else:
        # insert before the final (wildcard) hl.monitor call so this
        # output-specific rule is matched first
        idx = text.rfind("hl.monitor({")
        text = text[:idx] + block + "\n\n" + text[idx:]
    MONITORS_LUA.write_text(text)
    print(f"updated {MONITORS_LUA}")


def main():
    # non-interactive entry points for callers that already know what they
    # want (e.g. the drag-to-arrange popup in MonitorLayout.qml) and can't
    # go through fzf/input()
    if len(sys.argv) >= 2 and sys.argv[1] in ("--apply", "--persist"):
        action, output, mode, position, scale = sys.argv[1:6]
        if action == "--apply":
            apply_live(output, mode, position, scale)
        else:
            persist(output, mode, position, scale)
        return

    monitors = get_monitors()
    mon = pick_monitor(monitors)
    mode = pick_mode(mon)
    scale = pick_scale()
    position = pick_position(mon)

    apply_live(mon["name"], mode, position, scale)
    print(f"applied live: {mon['name']} {mode} @ {position} scale={scale}")

    save = input("persist to monitors.lua so it survives reload/reboot? [Y/n] ").strip().lower()
    if save in ("", "y", "yes"):
        persist(mon["name"], mode, position, scale)
        print("run `hyprctl reload` if you want to verify it re-applies cleanly")


if __name__ == "__main__":
    main()
