#!/usr/bin/env python3
import json
import glob
import os
import subprocess
from datetime import datetime, timezone, timedelta

# --- Calibration ---
# Block %: weighted = out*15 + cc*3.75 + cr*0.30; pct = weighted / BLOCK_LIMIT_WEIGHTED
# Derived from first data point (21% usage at known token counts). Adjust if plan changes.
BLOCK_LIMIT_WEIGHTED      = 9_176_752

# Weekly: costUSD since last reset / WEEKLY_LIMIT_USD
WEEKLY_LIMIT_USD          = 176.6

# Claude Pro weekly reset: day-of-week + UTC time
WEEKLY_RESET_WEEKDAY      = 4      # 0=Mon ... 4=Fri
WEEKLY_RESET_HOUR         = 12
WEEKLY_RESET_MINUTE       = 30

# Idle gaps longer than this (minutes) mark a new session start
SESSION_GAP_THRESHOLD_MIN = 10

def run(cmd):
    r = subprocess.run(cmd, capture_output=True, text=True, check=False)
    return r.stdout.strip()

def fmt_duration(sec):
    sec = int(sec)
    d = sec // 86400
    h = (sec % 86400) // 3600
    m = (sec % 3600) // 60
    if d > 0:
        return f"{d}d{h}h"
    if h > 0:
        return f"{h}h{m:02d}m"
    return f"{m}m"

def find_session_offset(block_start):
    """Scan JSONL to find the biggest idle gap in this block.
    Returns timedelta from billing-block-start to the true session start."""
    timestamps = []
    base   = os.path.expanduser("~/.claude/projects")
    cutoff = block_start - timedelta(hours=1)
    for f in glob.glob(os.path.join(base, "**/*.jsonl"), recursive=True):
        try:
            if datetime.fromtimestamp(os.path.getmtime(f), tz=timezone.utc) < cutoff:
                continue
            with open(f) as fh:
                for line in fh:
                    try:
                        d = json.loads(line)
                        ts = d.get("timestamp") or d.get("created_at")
                        if ts:
                            t = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                            if t >= block_start:
                                timestamps.append(t)
                    except:
                        pass
        except:
            pass

    if len(timestamps) < 2:
        return timedelta(0)

    timestamps.sort()
    best_gap_min, session_start = 0.0, block_start
    for i in range(1, len(timestamps)):
        gap_min = (timestamps[i] - timestamps[i - 1]).total_seconds() / 60
        if gap_min > best_gap_min:
            best_gap_min = gap_min
            session_start = timestamps[i]

    if best_gap_min < SESSION_GAP_THRESHOLD_MIN:
        return timedelta(0)
    return session_start - block_start


# --- Active block ---
block_remain_str = "--"
block_used_pct   = 0
session_offset   = timedelta(0)

try:
    block_json = run(["ccusage", "blocks", "--json", "--active", "--offline"])
    if block_json:
        blocks = json.loads(block_json).get("blocks", [])
        if blocks:
            b           = blocks[0]
            now_utc     = datetime.now(timezone.utc)
            block_start = datetime.fromisoformat(b["startTime"].replace("Z", "+00:00"))
            block_end   = datetime.fromisoformat(b["endTime"].replace("Z", "+00:00"))

            session_offset = find_session_offset(block_start)
            effective_end  = block_end + session_offset

            remain_sec       = max(0, (effective_end - now_utc).total_seconds())
            block_remain_str = fmt_duration(remain_sec)

            tc       = b.get("tokenCounts", {})
            weighted = (tc.get("outputTokens", 0) * 15 +
                        tc.get("cacheCreationInputTokens", 0) * 3.75 +
                        tc.get("cacheReadInputTokens", 0) * 0.30)
            block_used_pct = min(100, int(weighted / BLOCK_LIMIT_WEIGHTED * 100))
except Exception:
    pass


# --- Weekly cycle ---
week_remain_str = "--"
week_used_pct   = 0

try:
    now_utc = datetime.now(timezone.utc)

    days_since_reset = (now_utc.weekday() - WEEKLY_RESET_WEEKDAY) % 7
    week_start = (now_utc.replace(hour=WEEKLY_RESET_HOUR, minute=WEEKLY_RESET_MINUTE,
                                  second=0, microsecond=0)
                  - timedelta(days=days_since_reset))
    if week_start > now_utc:
        week_start -= timedelta(days=7)

    # Apply same idle offset to weekly reset window
    week_end          = week_start + timedelta(days=7) + session_offset
    week_remain_sec   = max(0, (week_end - now_utc).total_seconds())
    week_remain_str   = fmt_duration(week_remain_sec)

    all_blocks_json = run(["ccusage", "blocks", "--json", "--offline"])
    if all_blocks_json:
        week_cost = sum(
            blk.get("costUSD", 0)
            for blk in json.loads(all_blocks_json).get("blocks", [])
            if datetime.fromisoformat(blk["startTime"].replace("Z", "+00:00")) >= week_start
        )
        week_used_pct = min(100, int(week_cost / WEEKLY_LIMIT_USD * 100))
except Exception:
    pass

# Output: block_remain|block_used_pct|week_remain|week_used_pct
print(f"{block_remain_str}|{block_used_pct}|{week_remain_str}|{week_used_pct}")
