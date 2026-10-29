#!/usr/bin/env python3
"""
build_playlist.py — สุ่มลำดับเพลงสำหรับ live 1 รอบ โดยไม่ให้เพลงซ้ำกันในรอบเดียว

หลักการ
  - หนึ่ง "รอบ" (round) = สุ่มเพลงทั้งหมด (หรือจนครบเวลาเป้าหมาย) แบบ "ไม่ซ้ำ"
  - ถ้าเพลงรวมสั้นกว่าที่ต้องการ → จบรอบแล้วขึ้นรอบใหม่ (สลับลำดับใหม่)
    แต่บังคับว่าเพลงแรกของรอบใหม่ != เพลงสุดท้ายของรอบก่อน (ไม่ให้สะดุดหู)
  - seed มาจากวันที่ → รอบเดียวกันของวันเดียวกันได้ลำดับเดิม (ทำซ้ำได้/ตรวจสอบได้)

ใช้
  python3 build_playlist.py --dir songs --minutes 177 --out concat.txt --json playlist.json
  python3 build_playlist.py --dir songs --minutes 180 --rounds 2 --out concat.txt

ผลลัพธ์
  concat.txt   ไฟล์รายการสำหรับ ffmpeg:  file '/path/เพลง.m4a'
  playlist.json ลำดับเพลง + รอบ + ความยาวที่คำนวณได้
"""
from __future__ import annotations

import argparse
import json
import os
import random
import subprocess
import sys

AUDIO_EXT = (".m4a", ".mp3", ".wav", ".flac", ".aac", ".ogg")


def duration_of(path: str) -> float:
    """อ่านความยาวด้วย ffprobe ถ้ามี ไม่งั้นใช้ mutagen"""
    try:
        out = subprocess.run(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "default=nw=1:nk=1", path],
            capture_output=True, text=True, timeout=60,
        )
        if out.returncode == 0 and out.stdout.strip():
            return float(out.stdout.strip())
    except (FileNotFoundError, ValueError, subprocess.SubprocessError):
        pass
    try:
        from mutagen import File as MFile
        a = MFile(path)
        return float(a.info.length)
    except Exception:  # noqa: BLE001
        return 0.0


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--dir", required=True, help="โฟลเดอร์เพลง")
    p.add_argument("--minutes", type=float, default=177, help="ความยาวเป้าหมาย (นาที)")
    p.add_argument("--rounds", type=int, default=0, help="0 = พอดีเวลาเป้าหมาย, N = บังคับ N รอบ")
    p.add_argument("--seed", default=None, help="seed (default = วันที่ YYYYMMDD)")
    p.add_argument("--out", default="concat.txt")
    p.add_argument("--json", default="playlist.json")
    p.add_argument("--cover", default="", help="บันทึกชื่อปกที่ใช้ (ไม่บังคับ)")
    args = p.parse_args()

    seed = args.seed or __import__("datetime").date.today().strftime("%Y%m%d")
    rng = random.Random(seed)

    files = sorted(
        os.path.join(args.dir, f) for f in os.listdir(args.dir)
        if f.lower().endswith(AUDIO_EXT)
    )
    if not files:
        sys.exit(f"ไม่พบไฟล์เสียงใน {args.dir}")

    meta = []
    for f in files:
        d = duration_of(f)
        if d > 1:
            meta.append({"path": os.path.abspath(f), "name": os.path.splitext(os.path.basename(f))[0], "dur": d})
    if not meta:
        sys.exit("อ่านความยาวเพลงไม่ได้เลย (ตรวจ ffprobe / mutagen)")

    total_pool = sum(m["dur"] for m in meta)
    target = args.minutes * 60
    print(f"คลังเพลง   : {len(meta)} เพลง / {total_pool/60:.1f} นาที")
    print(f"เป้าหมาย   : {args.minutes:.0f} นาที ({target/60:.1f} ชม.) | seed={seed}")

    order: list[dict] = []
    rounds: list[list[str]] = []
    acc = 0.0
    round_no = 0

    while True:
        round_no += 1
        pool = meta[:]
        rng.shuffle(pool)
        # เพลงแรกของรอบใหม่ต้องไม่ซ้ำกับเพลงสุดท้ายของรอบก่อน
        if order and len(pool) > 1 and pool[0]["path"] == order[-1]["path"]:
            pool[0], pool[1] = pool[1], pool[0]

        this_round: list[str] = []
        for m in pool:
            entry = dict(m, round=round_no, start_sec=round(acc, 2))
            order.append(entry)
            this_round.append(m["name"])
            acc += m["dur"]
            if args.rounds == 0 and acc >= target:
                break
        rounds.append(this_round)

        done = (args.rounds and round_no >= args.rounds) or (args.rounds == 0 and acc >= target)
        if done:
            break

    # ตรวจสอบว่าไม่มีเพลงซ้ำในรอบเดียวกัน
    for i, r in enumerate(rounds, 1):
        dup = len(r) - len(set(r))
        print(f"รอบ {i}: {len(r)} เพลง ({sum(m['dur'] for m in order if m['round']==i)/60:.1f} นาที) | ซ้ำในรอบ = {dup}")
        assert dup == 0, f"พบเพลงซ้ำในรอบ {i}"

    with open(args.out, "w", encoding="utf-8") as fh:
        for m in order:
            esc = m["path"].replace("'", r"'\''")
            fh.write(f"file '{esc}'\n")

    with open(args.json, "w", encoding="utf-8") as fh:
        json.dump(
            {
                "seed": seed,
                "target_minutes": args.minutes,
                "total_seconds": round(acc, 2),
                "total_hours": round(acc / 3600, 3),
                "tracks": len(order),
                "rounds": [{"round": i + 1, "tracks": r} for i, r in enumerate(rounds)],
                "order": order,
                "cover": args.cover,
            },
            fh, ensure_ascii=False, indent=1,
        )

    print(f"\nรวมที่ได้ : {acc/60:.1f} นาที ({acc/3600:.2f} ชม.) / {len(order)} เพลง")
    print(f"เขียน     : {args.out} , {args.json}")
    print("\n5 เพลงแรก:")
    for m in order[:5]:
        print(f"  [{m['round']}] {m['name']}  ({m['dur']:.0f}s)")


if __name__ == "__main__":
    main()
