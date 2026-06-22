#!/usr/bin/env python3
import json, subprocess, sys
from datetime import datetime, timezone

def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r.stdout.strip()

# --- Active block: time remaining ---
block_json = run(["npx", "ccusage", "blocks", "--json", "--active"])
remain_pct = 0
reset_str = "--"
block_cost = 0.0

try:
    blocks = json.loads(block_json).get("blocks", [])
    if blocks:
        b = blocks[0]
        now = datetime.now(timezone.utc)
        end = datetime.fromisoformat(b["endTime"].replace("Z", "+00:00"))
        start = datetime.fromisoformat(b["startTime"].replace("Z", "+00:00"))
        total_sec = (end - start).total_seconds()
        remain_sec = max(0, (end - now).total_seconds())
        remain_pct = int(remain_sec / total_sec * 100)
        h = int(remain_sec // 3600)
        m = int((remain_sec % 3600) // 60)
        reset_str = f"{h}h{m:02d}m" if h > 0 else f"{m}m"
        block_cost = b.get("costUSD", 0.0)
except Exception:
    pass

# --- Weekly cost ---
week_cost = 0.0
try:
    week_json = run(["npx", "ccusage", "weekly", "--json"])
    weeks = json.loads(week_json).get("weekly", [])
    current_week_str = datetime.now().strftime("%Y-%m-%d")
    # Find the most recent week entry (all agents combined)
    for w in reversed(weeks):
        if w.get("agent") == "all":
            week_cost = w.get("totalCost", 0.0)
            break
except Exception:
    pass

# Output: remain_pct|reset_str|week_cost
print(f"{remain_pct}|{reset_str}|{week_cost:.2f}")
