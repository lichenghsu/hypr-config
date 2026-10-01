#!/usr/bin/env python3
# 從 LRCLIB 抓同步歌詞給 quickshell 歌詞島用
# 用法：lyrics_fetch.py <key> <title> <artist> <album> <length_us>
# 輸出：BEGIN\t<key> / L\t<秒數>\t<歌詞>... / END\t<key>（找不到同步歌詞就只有 BEGIN/END）
# 快取在 ~/.cache/quickshell/lyrics/，查無結果也快取 24 小時，避免每次切歌都打 API
import hashlib
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

API = "https://lrclib.net/api"
UA = "quickshell-lyrics (https://github.com/lichenghsu/hypr-config)"
CACHE = os.path.expanduser("~/.cache/quickshell/lyrics")
NEG_TTL = 24 * 3600
MAX_DIFF = 8  # 秒；長度差超過這個就當作不同首

# 瀏覽器（YouTube 等）標題常見的雜訊
NOISE = re.compile(
    r"\s*[\(\[【「『]?\s*(official\s*(music\s*)?(video|audio|mv|lyric\s*video|visualizer)|"
    r"music\s*video|lyric(s)?\s*video|lyrics|audio|mv|m/v|hd|hq|4k|"
    r"官方(完整版)?\s*(mv|music video|音樂錄影帶)?|完整版|動態歌詞|歌詞版|中字|中文字幕)\s*[\)\]】」』]?",
    re.I,
)
SITE_SUFFIX = re.compile(r"\s*[-|–—]\s*(youtube( music)?|spotify|soundcloud|bilibili|哔哩哔哩|嗶哩嗶哩)\s*$", re.I)


def clean_title(t):
    t = SITE_SUFFIX.sub("", t)
    t = NOISE.sub("", t)
    t = re.sub(r"\s*[\(\[]\s*[\)\]]", "", t)  # 清掉被掏空的括號
    return re.sub(r"\s+", " ", t).strip(" -|")


def clean_artist(a):
    a = re.sub(r"\s*-\s*Topic$", "", a)
    a = re.sub(r"VEVO$", "", a)
    a = re.sub(r"\s*(official|官方頻道|官方)$", "", a, flags=re.I)
    return a.strip()


def candidates(title, artist):
    seen, out = set(), []

    def add(t, a):
        t, a = t.strip(), a.strip()
        if t and (t, a) not in seen:
            seen.add((t, a))
            out.append((t, a))

    add(title, artist)
    ct, ca = clean_title(title), clean_artist(artist)
    add(ct, ca)
    # "Artist - Title" 形式（YouTube 最常見），artist 欄位通常只是頻道名
    m = re.match(r"^(.+?)\s+[-–—]\s+(.+)$", ct)
    if m:
        add(m.group(2), m.group(1))
        add(m.group(1), m.group(2))
    # 華語 MV 常見「歌手【歌名 English】」/「歌手《歌名》」：括號內是歌名，外面是歌手
    m = re.match(r"^(.*?)[【《「『](.+?)[】》」』](.*)$", SITE_SUFFIX.sub("", title))
    if m:
        name = m.group(2).strip()
        who = clean_title(m.group(1) + " " + m.group(3)) or ca
        cjk = re.match(r"^([^A-Za-z]+?)\s+[A-Za-z].*$", name)  # 去掉中英並列的英文譯名
        for n in ([cjk.group(1)] if cjk else []) + [name]:
            add(n, who)
            whocjk = re.match(r"^([^A-Za-z]+?)\s+[A-Za-z].*$", who)
            if whocjk:
                add(n, whocjk.group(1))
            add(n, "")
    return out


errored = False  # 有任何請求失敗就不寫負快取，下次再試


def http_json(path, params):
    global errored
    url = f"{API}/{path}?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=6) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        if e.code != 404:
            errored = True
    except Exception:
        errored = True
    return None


def pick(results, dur):
    best, best_diff = None, None
    for r in results or []:
        if not r.get("syncedLyrics"):
            continue
        if dur is None:
            return r
        diff = abs((r.get("duration") or 0) - dur)
        if diff <= MAX_DIFF and (best_diff is None or diff < best_diff):
            best, best_diff = r, diff
    return best


def lookup(title, artist, album, dur):
    for t, a in candidates(title, artist):
        if a and dur is not None:
            r = http_json("get", {"track_name": t, "artist_name": a, "album_name": album, "duration": round(dur)})
            if r and r.get("syncedLyrics") and abs((r.get("duration") or 0) - dur) <= MAX_DIFF:
                return r["syncedLyrics"]
        params = {"track_name": t}
        if a:
            params["artist_name"] = a
        r = pick(http_json("search", params), dur)
        if r:
            return r["syncedLyrics"]
    # 最後手段：整串丟全文搜尋，只在有長度可比對時採用，免得抓到同名別首
    if dur is not None:
        q = clean_title(title)
        if artist:
            q += " " + clean_artist(artist)
        r = pick(http_json("search", {"q": q}), dur)
        if r:
            return r["syncedLyrics"]
    return None


TS = re.compile(r"\[(\d+):(\d+(?:\.\d+)?)\]")


def parse_lrc(lrc):
    lines = []
    for raw in lrc.splitlines():
        stamps = TS.findall(raw)
        if not stamps:
            continue
        text = TS.sub("", raw).strip().replace("\t", " ")
        for m, s in stamps:
            lines.append((int(m) * 60 + float(s), text))
    lines.sort(key=lambda x: x[0])
    return lines


def main():
    key, title, artist, album, length = (sys.argv[1:] + [""] * 5)[:5]
    us = int(length) if length.isdigit() else 0
    dur = us / 1e6 if us > 0 else None

    print(f"BEGIN\t{key}", flush=True)
    os.makedirs(CACHE, exist_ok=True)
    h = hashlib.sha1(f"{title}|{artist}|{album}".encode()).hexdigest()
    hit, miss = os.path.join(CACHE, h + ".lrc"), os.path.join(CACHE, h + ".none")

    lrc = None
    if os.path.exists(hit):
        with open(hit, encoding="utf-8") as f:
            lrc = f.read()
    elif not (os.path.exists(miss) and time.time() - os.path.getmtime(miss) < NEG_TTL):
        lrc = lookup(title, artist, album, dur)
        if lrc:
            with open(hit, "w", encoding="utf-8") as f:
                f.write(lrc)
        elif not errored:
            open(miss, "w").close()

    if lrc:
        for t, text in parse_lrc(lrc):
            print(f"L\t{t:.2f}\t{text}")
    print(f"END\t{key}", flush=True)


if __name__ == "__main__":
    main()
