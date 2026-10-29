#!/usr/bin/env python3
"""
kgv_live.py — สร้าง/ใช้ซ้ำ YouTube Live broadcast ของ K-GoodVibe แล้วต่อ ffmpeg loop ให้ทันที

จุดประสงค์: ไม่ต้องกรอก stream key มือ ไม่ต้องสร้างรายการสดใหม่ทุกครั้ง
ใช้ OAuth token ชุดเดียวกับที่ใช้ upload อยู่แล้ว (kgoodvibe_youtube_oauth_tokens.json)

ตัวอย่าง
  # 1) ดู token + scope ที่มี (ไม่ต่อเน็ต)
  python3 kgv_live.py --check

  # 2) ดู live stream / broadcast ที่มีอยู่บนช่อง
  python3 kgv_live.py --list

  # 3) สร้าง (หรือใช้ซ้ำ) broadcast แล้วเขียน key ลงไฟล์ env เฉยๆ ไม่สตรีม
  python3 kgv_live.py --env-out ~/stream.env --no-stream

  # 4) ครบวงจร: สร้าง broadcast + สตรีมทันที (โหมดเปิดตลอด)
  python3 kgv_live.py --video ~/stream/loop_1080p.mp4 --copy --run

  # 5) ครบวงจร + เปิดเฉพาะ 22:00-06:00 BKK
  python3 kgv_live.py --video ~/stream/loop_1080p.mp4 --copy --window 22:00-06:00 --run

  # 6) สร้าง key ใหม่ (เผื่อ key รั่ว) แล้วสตรีม
  python3 kgv_live.py --new-key --video loop_1080p.mp4 --copy --run

ต้องติดตั้ง:  pip install google-api-python-client google-auth google-auth-httplib2
ต้องมี scope: youtube หรือ youtube.force-ssl  (ถ้ามีแค่ youtube.upload จะได้ 403 — ต้อง re-consent 1 ครั้ง)
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import stat
import sys
from pathlib import Path

# ─────────────────────────── constants ───────────────────────────
DEFAULT_TOKENS = "auth/youtube_oauth_tokens.json"
RTMP_BASE = "rtmp://a.rtmp.youtube.com/live2"
STREAM_TITLE = "KGV Live ingest (reusable)"
DEFAULT_BC_TITLE = "🔴 K-GoodVibe Radio 24/7 | Korean City Pop & Lo-fi | Study · Work · Sleep"
DEFAULT_BC_DESC = """Korean City Pop · Lo-fi · Workday Pop — เปิดต่อเนื่องตลอดวัน

▶ ฟังเพลงชุดเต็ม 3 ชั่วโมง (พร้อม chapter): https://www.youtube.com/@k-goodvibe/videos
▶ Playlist: https://www.youtube.com/playlist?list=PLP59TNDc7Rj4

Tracklist หมุนเวียนตามรอบ ภาพและเสียงสร้างด้วย AI (synthetic content)
ติดตามผลงานใหม่: https://www.youtube.com/@k-goodvibe
"""
REQUIRED_SCOPES = {
    "https://www.googleapis.com/auth/youtube",
    "https://www.googleapis.com/auth/youtube.force-ssl",
}


# ─────────────────────────── helpers ───────────────────────────
def die(msg: str, code: int = 1):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(code)


def mask(key: str) -> str:
    if not key:
        return "(ว่าง)"
    if len(key) <= 8:
        return key[:2] + "***"
    return f"{key[:4]}…{key[-4:]} (masked)"


def load_token_file(path: Path) -> dict:
    if not path.exists():
        die(
            f"ไม่พบไฟล์ token: {path}\n"
            "  ดาวน์โหลดจาก Google Drive: kgoodvibe_youtube_oauth_tokens.json\n"
            "  (file id 1dR03FmiuRUB1nKvBIOikBMAm84wo1zV7) แล้ววางที่ path นี้ / หรือใช้ --tokens"
        )
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        die(f"ไฟล์ token ไม่ใช่ JSON: {e}")


def scopes_of(raw: dict) -> set[str]:
    sc = raw.get("scopes") or raw.get("scope") or []
    if isinstance(sc, str):
        sc = sc.split()
    return set(sc)


def build_service(tokens_path: Path, verbose: bool = True):
    """คืน (youtube_service, creds) — refresh token ถ้าหมดอายุ แล้วเขียนกลับลงไฟล์"""
    try:
        from google.auth.transport.requests import Request
        from google.oauth2.credentials import Credentials
        from googleapiclient.discovery import build
    except ImportError:
        die("ยังไม่ได้ติดตั้งไลบรารี: pip install google-api-python-client google-auth google-auth-httplib2")

    raw = load_token_file(tokens_path)
    # รองรับทั้งไฟล์แบบ google-auth ตรงๆ และแบบที่ห่อด้วย key อื่น
    if "refresh_token" not in raw and "installed" in raw:
        raw = {**raw["installed"], **raw.get("token", {})}
    if "refresh_token" not in raw and "web" in raw:
        raw = {**raw["web"], **raw.get("token", {})}
    if "refresh_token" not in raw:
        die(f"ไฟล์ token ไม่มี refresh_token — ตรวจ {tokens_path}")

    creds = Credentials.from_authorized_user_info(raw)
    missing = REQUIRED_SCOPES - scopes_of(raw)
    if not (REQUIRED_SCOPES & scopes_of(raw)):
        die(
            "token นี้ไม่มี scope สำหรับ Live API\n"
            f"  scope ที่มี: {sorted(scopes_of(raw)) or '(ไม่ระบุ)'}\n"
            "  ต้องมีอย่างน้อย https://www.googleapis.com/auth/youtube.force-ssl\n"
            "  → re-consent 1 ครั้งด้วย flow เดิม (ไม่ต้องขอ TV device code ใหม่) แล้วบันทึกทับไฟล์นี้"
        )
    del missing

    if not creds.valid:
        if creds.expired and creds.refresh_token:
            if verbose:
                print("→ refresh access token")
            creds.refresh(Request())
            tokens_path.write_text(creds.to_json(), encoding="utf-8")
            os.chmod(tokens_path, stat.S_IRUSR | stat.S_IWUSR)  # 600
        else:
            die("token ใช้ไม่ได้และ refresh ไม่ได้ — ต้อง authorize ใหม่")

    yt = build("youtube", "v3", credentials=creds, cache_discovery=False)
    return yt, creds


def find_or_create_stream(yt, new_key: bool = False, verbose: bool = True) -> dict:
    found = None
    default_stream = None
    resp = yt.liveStreams().list(part="id,snippet,cdn,status", mine=True, maxResults=50).execute()
    for item in resp.get("items", []):
        if item["snippet"].get("isDefaultStream"):
            default_stream = item
        if item["snippet"]["title"] == STREAM_TITLE:
            found = item
            break
    # ไม่มี stream ที่ชื่อเรา -> ใช้ stream เดิมของช่องก่อน (กันสร้าง key ใหม่ทุกรอบ)
    if not found and resp.get("items"):
        cand = default_stream or next(
            (i for i in resp["items"] if i["snippet"]["title"].startswith("Default stream")),
            resp["items"][0],
        )
        if verbose:
            print(f"→ ใช้ stream เดิมของช่อง {cand['id']} ({cand['snippet']['title']})")
        found = cand
    if not found and default_stream:
        if verbose:
            print(f"→ ใช้ Default stream key เดิม {default_stream['id']}")
        found = default_stream

    if found and new_key:
        if verbose:
            print(f"→ ลบ live stream เดิม {found['id']} เพื่อสร้าง key ใหม่")
        yt.liveStreams().delete(id=found["id"]).execute()
        found = None

    if found:
        if verbose:
            print(f"→ ใช้ live stream เดิม {found['id']}")
        return found

    if verbose:
        print("→ สร้าง live stream ใหม่")
    body = {
        "snippet": {"title": STREAM_TITLE},
        "cdn": {
            "frameRate": "30fps",
            "resolution": "1080p",
            "ingestionType": "rtmp",
            "ingestionInfo": {"streamName": "kgv", "ingestionAddress": RTMP_BASE},
        },
        "contentDetails": {"isReusable": True},
    }
    return yt.liveStreams().insert(
        part="snippet,cdn,contentDetails,status", body=body
    ).execute()


def find_or_create_broadcast(yt, stream_id: str, args, verbose: bool = True) -> dict:
    live_states = {"created", "ready", "testing", "live"}
    resp = yt.liveBroadcasts().list(
        part="id,snippet,status,contentDetails", mine=True, maxResults=50
    ).execute()

    for item in resp.get("items", []):
        if item["snippet"]["title"] != args.title:
            continue
        if item["status"]["lifeCycleStatus"] not in live_states:
            continue
        if item.get("contentDetails", {}).get("boundStreamId") != stream_id:
            continue
        if verbose:
            print(f"→ ใช้ broadcast เดิม {item['id']} ({item['status']['lifeCycleStatus']})")
        return item

    start = args.start_time or (
        dt.datetime.now(dt.timezone.utc) + dt.timedelta(minutes=2)
    ).strftime("%Y-%m-%dT%H:%M:%SZ")

    if verbose:
        print(f"→ สร้าง broadcast ใหม่ (scheduledStartTime={start})")
    body = {
        "snippet": {
            "title": args.title,
            "description": args.description,
            "scheduledStartTime": start,
        },
        "status": {"privacyStatus": args.privacy, "selfDeclaredMadeForKids": False},
        "contentDetails": {
            "enableAutoStart": True,     # encoder ต่อเข้ามา -> ขึ้น live เอง
            "enableAutoStop": False,     # เน็ตสะดุด = ไม่จบรายการ
            "enableDvr": True,
            "recordFromStart": True,
            "enableEmbed": True,
            "latencyPreference": "normal",  # low latency ทำให้ 24/7 หลุดง่าย
            "monitorStream": {"enableMonitorStream": False},
        },
    }
    bc = yt.liveBroadcasts().insert(part="snippet,contentDetails,status", body=body).execute()
    return bc


def bind(yt, broadcast_id: str, stream_id: str, verbose: bool = True) -> None:
    yt.liveBroadcasts().bind(
        part="id,contentDetails", id=broadcast_id, streamId=stream_id
    ).execute()
    if verbose:
        print(f"→ bind broadcast {broadcast_id} <-> stream {stream_id}")


def write_env(path: Path, values: dict) -> None:
    lines = [f"{k}={v}" for k, v in values.items() if v is not None]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    os.chmod(path, stat.S_IRUSR | stat.S_IWUSR)  # 600 — key ไม่ให้คนอื่นอ่าน
    print(f"→ เขียน {path} (mode 600): {', '.join(values)}")


# ─────────────────────────── main ───────────────────────────
def main() -> None:
    p = argparse.ArgumentParser(description="K-GoodVibe YouTube Live setup + ffmpeg loop runner")
    p.add_argument("--tokens", default=DEFAULT_TOKENS, help=f"ไฟล์ OAuth token (default {DEFAULT_TOKENS})")
    p.add_argument("--title", default=DEFAULT_BC_TITLE, help="ชื่อ broadcast (ใช้จับคู่ของเดิมด้วย)")
    p.add_argument("--description", default=DEFAULT_BC_DESC)
    p.add_argument("--privacy", default="public", choices=["public", "unlisted", "private"])
    p.add_argument("--start-time", default=None, help="ISO8601 UTC เช่น 2026-11-01T00:00:00Z")
    p.add_argument("--new-key", action="store_true", help="ลบ live stream เดิมแล้วสร้าง key ใหม่")
    p.add_argument("--check", action="store_true", help="ดู token/scope แล้วจบ (ไม่เรียก API)")
    p.add_argument("--list", action="store_true", help="แสดง live stream + broadcast ที่มี")
    p.add_argument("--env-out", default=None, help="เขียน STREAM_KEY ลงไฟล์ env (mode 600)")
    p.add_argument("--print-key", action="store_true", help="แสดง key เต็มบนหน้าจอ")
    p.add_argument("--rtmps", dest="use_rtmps", action="store_true",
                   help="ใช้ RTMPS (port 443) แทน RTMP 1935 — แนะนำถ้าเน็ตบล็อก 1935")
    p.add_argument("--no-backup", action="store_true",
                   help="ไม่ส่ง feed ที่ 2 ไป backup server (ประหยัด bandwidth ครึ่งหนึ่ง)")

    # ffmpeg runner
    p.add_argument("--run", action="store_true", help="ต่อ ffmpeg loop ทันทีหลัง setup")
    p.add_argument("--video", default="loop_1080p.mp4")
    p.add_argument("--copy", action="store_true", help="สตรีมด้วย -c:v copy (ไฟล์ pre-encode แล้ว)")
    p.add_argument("--window", default="", help="เช่น 22:00-06:00 (Asia/Bangkok), ว่าง = เปิดตลอด")
    p.add_argument("--v-bitrate", default="4500k")
    p.add_argument("--a-bitrate", default="192k")
    p.add_argument("--max-seconds", default="999999999")
    p.add_argument("--healthcheck-url", default="")
    p.add_argument("--stream-sh", default=str(Path(__file__).with_name("stream.sh")))
    args = p.parse_args()

    tokens_path = Path(args.tokens).expanduser()
    raw = load_token_file(tokens_path)

    if args.check:
        print(f"token file : {tokens_path}")
        print(f"scopes     : {sorted(scopes_of(raw)) or '(ไม่ระบุ)'}")
        ok = bool(REQUIRED_SCOPES & scopes_of(raw))
        print(f"live ok    : {'YES' if ok else 'NO — ต้อง re-consent ให้มี youtube.force-ssl'}")
        print(f"has refresh: {bool(raw.get('refresh_token'))}")
        return

    yt, _ = build_service(tokens_path)

    if args.list:
        print("\n== liveStreams ==")
        for s in yt.liveStreams().list(part="id,snippet,status", mine=True, maxResults=50).execute().get("items", []):
            print(f"  {s['id']}  {s['snippet']['title']}  [{s['status']['streamStatus']}]")
        print("\n== liveBroadcasts ==")
        # หมายเหตุ: API ไม่ให้ใช้ mine=true คู่กับ broadcastStatus (400 Incompatible parameters)
        for b in yt.liveBroadcasts().list(
            part="id,snippet,status", mine=True, maxResults=50
        ).execute().get("items", []):
            print(f"  {b['id']}  [{b['status']['lifeCycleStatus']}]  {b['snippet']['title'][:70]}")
        return

    stream = find_or_create_stream(yt, new_key=args.new_key)
    broadcast = find_or_create_broadcast(yt, stream["id"], args)
    bind(yt, broadcast["id"], stream["id"])

    info = stream["cdn"]["ingestionInfo"]
    key = info["streamName"]
    rtmp = info.get("ingestionAddress", RTMP_BASE)
    backup = info.get("backupIngestionAddress") or "rtmp://b.rtmp.youtube.com/live2?backup=1"
    rtmps = info.get("rtmpsIngestionAddress")
    rtmps_backup = info.get("rtmpsBackupIngestionAddress")

    print("\n──────────────────────────────────────────")
    print(f"broadcast : https://youtube.com/watch?v={broadcast['id']}")
    print(f"studio    : https://studio.youtube.com/video/{broadcast['id']}/livestreaming")
    print(f"rtmp      : {rtmp}")
    print(f"backup    : {backup}")
    if rtmps:
        print(f"rtmps     : {rtmps}   (ใช้เมื่อพอร์ต 1935 ถูกบล็อก)")
    if rtmps_backup:
        print(f"rtmps backup: {rtmps_backup}")
    print(f"combined  : {rtmp}/{key if args.print_key else '<STREAM_KEY>'}")
    print(f"stream key: {key if args.print_key else mask(key)}")
    print("──────────────────────────────────────────\n")

    if args.env_out:
        write_env(Path(args.env_out).expanduser(), {
            "STREAM_KEY": key,
            "RTMP_URL": args.use_rtmps and (rtmps or rtmp) or rtmp,
            "BACKUP_URL": args.use_rtmps and (rtmps_backup or backup) or backup,
            "VIDEO": args.video,
            "COPY_MODE": "1" if args.copy else "0",
            "V_BITRATE": args.v_bitrate,
            "A_BITRATE": args.a_bitrate,
            "WINDOW": args.window,
            "MAX_SECONDS": args.max_seconds,
            "HEALTHCHECK_URL": args.healthcheck_url or None,
        })

    if not args.run:
        print("ไม่ได้ใส่ --run → จบแค่ setup (ใช้ --env-out เพื่อบันทึก key)")
        return

    script = Path(args.stream_sh).expanduser()
    if not script.exists():
        die(f"ไม่พบ stream.sh ที่ {script}")

    print(f"→ เริ่มสตรีมด้วย {script} (video={args.video}, window={args.window or 'always'})")
    env = {
        **os.environ,
        "STREAM_KEY": key,
        "RTMP_URL": args.use_rtmps and (rtmps or rtmp) or rtmp,
        "BACKUP_URL": args.use_rtmps and (rtmps_backup or backup) or ("" if args.no_backup else backup),
        "VIDEO": args.video,
        "COPY_MODE": "1" if args.copy else "0",
        "V_BITRATE": args.v_bitrate,
        "A_BITRATE": args.a_bitrate,
        "WINDOW": args.window,
        "MAX_SECONDS": args.max_seconds,
    }
    if args.healthcheck_url:
        env["HEALTHCHECK_URL"] = args.healthcheck_url
    os.execvpe("bash", ["bash", str(script)], env)


if __name__ == "__main__":
    main()
