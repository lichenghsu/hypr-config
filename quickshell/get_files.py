#!/usr/bin/env python3
import sys
import os
import json
import subprocess


def get_files(query):
    if not query:
        print(json.dumps([]))
        return

    home = os.path.expanduser("~")
    try:
        result = subprocess.run(
            ["fd", "--max-results", "50", "--ignore-case", query, home],
            capture_output=True, text=True, timeout=3,
        )
        paths = [p for p in result.stdout.splitlines() if p]
    except Exception:
        paths = []

    files = []
    for p in paths:
        is_dir = p.endswith("/")
        clean = p.rstrip("/")
        files.append({
            "name": os.path.basename(clean),
            "path": clean,
            "icon": "folder" if is_dir else "text-x-generic",
        })
    print(json.dumps(files))


if __name__ == "__main__":
    get_files(sys.argv[1] if len(sys.argv) > 1 else "")
