#!/usr/bin/env bash
# make_music_loop.sh — สร้างไฟล์ live จาก "เพลงใน zip" แบบสุ่มไม่ซ้ำในรอบเดียว
#
# หลักการ
#   1) ดาวน์โหลด zip เพลงจาก Google Drive (ไฟล์ใหญ่แค่ไหนก็ได้)
#   2) แตกไฟล์ + วัดความยาวทุกเพลง
#   3) สุ่มลำดับ (seed = วันที่) แบบ "ไม่ซ้ำในรอบ" ครบทุกเพลง = 1 รอบ
#   4) ทำคลิปวิดีโอสั้น 20 วิจากปก (zoom เข้า-ออก วนเนียน) แล้ว "copy" วนต่อกับเสียง
#      → ไม่ต้อง encode 3 ชั่วโมง (เร็ว ~56x realtime)
#
# ใช้
#   ./make_music_loop.sh --zip-id <DRIVE_FILE_ID> --cover cover.png
#   ./make_music_loop.sh --zip K-Song1.zip --cover cover.png --minutes 177
#   ./make_music_loop.sh --songs-dir ./songs --cover cover.png --height 1080
#
# ผลลัพธ์: loop_<นาที>m_<height>p.mp4 + playlist.json + tracklist.txt
set -euo pipefail

ZIP=""; ZIP_ID=""; SONGS_DIR=""; COVER=""; MINUTES=177; HEIGHT=720; OUT=""
SEED=""; COVER_SECS=20

while [ $# -gt 0 ]; do
  case "$1" in
    --zip) ZIP="$2"; shift 2 ;;
    --zip-id) ZIP_ID="$2"; shift 2 ;;
    --songs-dir) SONGS_DIR="$2"; shift 2 ;;
    --cover) COVER="$2"; shift 2 ;;
    --minutes) MINUTES="$2"; shift 2 ;;
    --height) HEIGHT="$2"; shift 2 ;;
    --seed) SEED="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "ไม่รู้จัก option: $1"; exit 1 ;;
  esac
done

FF=$(command -v ffmpeg || true)
[ -n "$FF" ] || FF=$(python3 -c "import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())" 2>/dev/null || true)
[ -n "$FF" ] || { echo "ไม่พบ ffmpeg"; exit 1; }
[ -f "$(dirname "$0")/build_playlist.py" ] || { echo "ไม่พบ build_playlist.py"; exit 1; }

command -v ffprobe >/dev/null || echo "⚠ ไม่มี ffprobe — จะใช้ mutagen แทน (pip install mutagen)"

# 1) เตรียมโฟลเดอร์เพลง
if [ -z "$SONGS_DIR" ]; then
  SONGS_DIR="./songs"
  mkdir -p "$SONGS_DIR"
  if [ -n "$ZIP_ID" ]; then
    echo "→ ดาวน์โหลดจาก Google Drive id=$ZIP_ID"
    curl -sL --retry 3 -o songs.zip "https://drive.usercontent.google.com/download?id=$ZIP_ID&export=download&confirm=t"
  elif [ -n "$ZIP" ]; then
    cp "$ZIP" songs.zip
  else
    echo "ต้องระบุ --zip-id / --zip / --songs-dir"; exit 1
  fi
  ls -lh songs.zip
  unzip -o -q songs.zip -d "$SONGS_DIR" || { echo "แตก zip ไม่ได้ (อาจเป็นไฟล์เสีย/ไม่ครบ)"; exit 1; }
  # zip บางตัวมีโฟลเดอร์ซ้อน — ดึงไฟล์เสียงขึ้นมาระดับเดียว
  find "$SONGS_DIR" -mindepth 2 -type f \( -iname '*.m4a' -o -iname '*.mp3' -o -iname '*.wav' -o -iname '*.flac' \) -exec mv -n {} "$SONGS_DIR"/ \; 2>/dev/null || true
fi
COUNT=$(find "$SONGS_DIR" -maxdepth 1 -type f \( -iname '*.m4a' -o -iname '*.mp3' -o -iname '*.wav' -o -iname '*.flac' \) | wc -l)
[ "$COUNT" -gt 0 ] || { echo "ไม่พบไฟล์เสียงใน $SONGS_DIR"; exit 1; }
echo "→ พบเพลง $COUNT ไฟล์"

# 2) สุ่ม playlist (ไม่ซ้ำในรอบ)
SEED_ARG=""; [ -n "$SEED" ] && SEED_ARG="--seed $SEED"
python3 "$(dirname "$0")/build_playlist.py" --dir "$SONGS_DIR" --minutes "$MINUTES" \
  $SEED_ARG --out ./concat.txt --json ./playlist.json | tee /tmp/pl.log
TOTAL=$(python3 -c "import json;print(int(json.load(open('playlist.json'))['total_seconds']))")
echo "→ ความยาวจริง $TOTAL วินาที"

# tracklist สำหรับใส่ description
python3 - <<'PY' > tracklist.txt
import json
d=json.load(open('playlist.json'))
for i,t in enumerate(d['order'],1):
    m,s=divmod(int(t['start_sec']),60); h,m=divmod(m,60)
    stamp=f"{h}:{m:02d}:{s:02d}" if h else f"{m}:{s:02d}"
    print(f"{stamp} {t['name']}")
PY
echo "→ เขียน tracklist.txt ($(wc -l < tracklist.txt) เพลง)"

# 3) คลิปวิดีโอสั้นจากปก (zoom ping-pong วนเนียน)
[ -n "$COVER" ] && [ -f "$COVER" ] || { echo "ต้องระบุ --cover ที่มีไฟล์จริง"; exit 1; }
W=$(( HEIGHT * 16 / 9 )); W=$(( W / 2 * 2 ))
FRAMES=$(( COVER_SECS * 30 ))
echo "→ ทำคลิปปก ${COVER_SECS}s @ ${W}x${HEIGHT}"
"$FF" -y -hide_banner -loglevel error -loop 1 -framerate 30 -i "$COVER" \
  -vf "scale=${W}:${HEIGHT}:force_original_aspect_ratio=increase,crop=${W}:${HEIGHT},setsar=1,\
zoompan=z='1+0.08*sin(2*PI*on/${FRAMES})':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=${FRAMES}:s=${W}x${HEIGHT}:fps=30,format=yuv420p" \
  -frames:v "$FRAMES" -c:v libx264 -preset veryfast -tune stillimage -profile:v high \
  -b:v 1000k -maxrate 1000k -bufsize 2000k -g 60 -keyint_min 60 -sc_threshold 0 -an cover_clip.mp4

# 4) mux: วิดีโอ copy วนซ้ำ + เสียงจาก playlist (encode เฉพาะเสียง = เร็วมาก)
[ -n "$OUT" ] || OUT="loop_${MINUTES}m_${HEIGHT}p.mp4"
echo "→ mux ${TOTAL}s -> $OUT (คาดว่า ~$(python3 -c "print(round((1160*$TOTAL/8)/1024/1024/1024,2))") GB)"
"$FF" -y -hide_banner -loglevel warning -stats \
  -stream_loop -1 -i cover_clip.mp4 \
  -f concat -safe 0 -i concat.txt \
  -map 0:v:0 -map 1:a:0 -t "$TOTAL" \
  -c:v copy -c:a aac -b:a 160k -ar 44100 -ac 2 \
  -movflags +faststart "$OUT"

ls -lh "$OUT"
"$FF" -hide_banner -i "$OUT" 2>&1 | grep -E "Duration|Stream #"
echo
echo "เสร็จ: $OUT"
echo "อัปขึ้น GitHub Release:  ./publish_media_to_github.sh live-media \"$OUT\""
