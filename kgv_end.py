#!/usr/bin/env python3
"""
kgv_end.py — จบ live broadcast ให้เรียบร้อย (transition -> complete)

ใช้เมื่อ: stream.sh หยุดตาม WINDOW (เช่น 06:00 BKK) แต่ YouTube ไม่จบรายการให้
เพราะเราเปิด enableAutoStop: False ไว้ (กันเน็ตสะดุดแล้วรายการตาย)

ตัวอย่าง
  python3 kgv_end.py --dry-run                 # ดูว่าจะจบรายการไหน (ไม่ยิง API)
  python3 kgv_end.py                           # จบรายการที่ชื่อตรงกับ default title
  python3 kgv_end.py --id AbCdEf12345          # จบรายการที่ระบุ
  python3 kgv_end.py --title "K-GoodVibe"      # จับจากบางส่วนของชื่อ
  python3 kgv_end.py --all-live                # จบทุก broadcast ที่ยัง live อยู่

ใช้ร่วมกับ systemd:
  ExecStopPost=/usr/bin/python3 /home/ubuntu/stream/kgv_end.py --tokens /home/ubuntu/stream/auth/youtube_oauth_tokens.json

ต้องมี scope: youtube หรือ youtube.force-ssl
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from kgv_live import DEFAULT_TOKENS, DEFAULT_BC_TITLE, build_service, die, load_token_file

LIVE_STATES = {"live", "testing", "ready", "created"}


def main() -> None:
    p = argparse.ArgumentParser(description="จบ YouTube live broadcast (transition -> complete)")
    p.add_argument("--tokens", default=DEFAULT_TOKENS)
    p.add_argument("--id", default=None, help="broadcast id ที่ต้องการจบ")
    p.add_argument("--title", default=None, help="จับชื่อแบบมีคำนี้ (default = ชื่อ broadcast มาตรฐาน)")
    p.add_argument("--all-live", action="store_true", help="จบทุก broadcast ที่ยัง live/ready")
    p.add_argument("--dry-run", action="store_true", help="แสดงรายการที่จะจบ แต่ไม่ยิง API")
    args = p.parse_args()

    tokens_path = Path(args.tokens).expanduser()
    load_token_file(tokens_path)  # ตรวจว่ามีไฟล์ก่อน (ฟ้อง error ที่อ่านรู้เรื่อง)
    yt, _ = build_service(tokens_path)

    if args.id:
        items = yt.liveBroadcasts().list(
            part="id,snippet,status", id=args.id
        ).execute().get("items", [])
        if not items:
            die(f"ไม่พบ broadcast id={args.id}")
        targets = items
    else:
        resp = yt.liveBroadcasts().list(
            part="id,snippet,status", mine=True, broadcastStatus="all", maxResults=50
        ).execute()
        items = resp.get("items", [])
        needle = args.title or DEFAULT_BC_TITLE
        targets = []
        for it in items:
            state = it["status"]["lifeCycleStatus"]
            if state not in LIVE_STATES:
                continue
            if args.all_live or needle.lower() in it["snippet"]["title"].lower():
                targets.append(it)

    if not targets:
        print("ไม่มี broadcast ที่ต้องจบ (อาจจบไปแล้ว หรือชื่อไม่ตรง — ลอง --all-live / --title)")
        return

    print(f"พบ {len(targets)} รายการ:")
    for it in targets:
        print(f"  {it['id']}  [{it['status']['lifeCycleStatus']}]  {it['snippet']['title'][:70]}")

    if args.dry_run:
        print("\n--dry-run: ไม่ได้ยิง API")
        return

    for it in targets:
        bid = it["id"]
        state = it["status"]["lifeCycleStatus"]
        try:
            if state == "live":
                # live -> complete
                yt.liveBroadcasts().transition(
                    part="status", broadcastStatus="complete", id=bid
                ).execute()
                print(f"→ {bid}: live -> complete ✔")
            else:
                # created/ready/testing -> ต้องผ่าน live ก่อน แล้วค่อย complete
                try:
                    yt.liveBroadcasts().transition(
                        part="status", broadcastStatus="live", id=bid
                    ).execute()
                except Exception as e:  # noqa: BLE001
                    print(f"  (ข้าม live: {str(e)[:90]})")
                yt.liveBroadcasts().transition(
                    part="status", broadcastStatus="complete", id=bid
                ).execute()
                print(f"→ {bid}: {state} -> complete ✔")
        except Exception as e:  # noqa: BLE001
            print(f"✗ {bid}: {e}", file=sys.stderr)

    print("\nเช็คซ้ำได้ที่: python3 kgv_live.py --list")


if __name__ == "__main__":
    main()
