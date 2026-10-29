#!/usr/bin/env bash
# make_3hr_loop.sh — สร้างไฟล์ "พร้อมสตรีม" ความยาวเท่าที่ต้องการ (ปกติ 3 ชม.)
#
# ทำไมต้องมี: stream.sh ใช้ `-stream_loop -1` วนไฟล์สั้นๆ ได้ไม่จำกัด ดังนั้น
#   - อยากได้ live 3 ชม. จากไฟล์ 60 วิ  → ไม่ต้องใช้สคริปต์นี้ (แค่ตั้ง MAX_SECONDS=10800)
#   - อยากได้ "ไฟล์เดี่ยว 3 ชม." ไว้ใช้ซ้ำ/อัป GitHub Release → ใช้สคริปต์นี้
#
# ใช้:
#   ./make_3hr_loop.sh --image cover.jpg                        # 3 ชม. จากภาพนิ่ง
#   ./make_3hr_loop.sh --image cover.jpg --audio song.mp3       # 3 ชม. ภาพ+เพลงวนซ้ำ
#   ./make_3hr_loop.sh --input 3h.mp4 --hours 3                 # แค่ re-encode ให้ตรงสเปก YouTube
#
# ตัวเลือกสำคัญ
#   --hours N        ความยาว (default 3)
#   --max-gb N       เพดานขนาดไฟล์ (default 1.8 = ปลอดภัยใต้ลิมิต 2 GB ของ GitHub Release)
#   --height N       1080 (default) / 720
#   --fit-check      คำนวณ bitrate ที่พอดีเพดาน แล้วจบ (ไม่ encode)
set -euo pipefail

HOURS=3; MAX_GB=1.8; HEIGHT=1080; IMAGE=""; AUDIO=""; INPUT=""; FIT_ONLY=0; OUT=""
FPS=30

while [ $# -gt 0 ]; do
  case "$1" in
    --image) IMAGE="$2"; shift 2 ;;
    --audio) AUDIO="$2"; shift 2 ;;
    --input) INPUT="$2"; shift 2 ;;
    --hours) HOURS="$2"; shift 2 ;;
    --max-gb) MAX_GB="$2"; shift 2 ;;
    --height) HEIGHT="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --fit-check) FIT_ONLY=1; shift ;;
    -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
    *) echo "ไม่รู้จัก option: $1"; exit 1 ;;
  esac
done

FF=$(command -v ffmpeg || true)
[ -n "$FF" ] || FF=$(python3 -c "import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())" 2>/dev/null || true)
[ -n "$FF" ] || { echo "ไม่พบ ffmpeg (ติดตั้ง: sudo apt install ffmpeg)"; exit 1; }

# รองรับทศนิยม เช่น --hours 0.01 (=36 วิ) สำหรับทดสอบ
SECS=$(python3 -c "print(int(float('$HOURS')*3600))")

# เพดาน bitrate ทั้งหมด (video+audio) ให้ไฟล์ไม่เกิน MAX_GB
#   bits = MAX_GB * 1024^3 * 8 ; kbps = bits / SECS / 1000
TOTAL_KBPS=$(python3 -c "print(int($MAX_GB*1024**3*8/$SECS/1000))")
A_KBPS=128
V_KBPS=$(( TOTAL_KBPS - A_KBPS ))
[ "$V_KBPS" -lt 300 ] && V_KBPS=300

echo "เป้าหมาย : ${HOURS} ชม. (${SECS} วิ) @ ${HEIGHT}p${FPS}"
echo "เพดานไฟล์: ${MAX_GB} GB  ->  total ${TOTAL_KBPS} kbps  (video ${V_KBPS}k + audio ${A_KBPS}k)"
echo "คาดว่าได้ : ~$(python3 -c "print(round($TOTAL_KBPS*1000*$SECS/8/1024**3,2))") GB"

if [ "$FIT_ONLY" = "1" ]; then exit 0; fi

[ -n "$OUT" ] || OUT="loop_${HOURS}h_${HEIGHT}p.mp4"
[ -e "$OUT" ] && { echo "มีไฟล์ $OUT อยู่แล้ว (ลบก่อนหรือใช้ --out ชื่ออื่น)"; exit 1; }

ARGS=(-hide_banner -stats -y)
if [ -n "$INPUT" ]; then
  echo "โหมด: re-encode จากไฟล์ $INPUT (วนซ้ำจนครบ ${HOURS} ชม.)"
  ARGS+=(-stream_loop -1 -i "$INPUT")
  MAP=(-map 0:v:0 -map 0:a:0?)
else
  [ -n "$IMAGE" ] || { echo "ต้องระบุ --image หรือ --input"; exit 1; }
  [ -f "$IMAGE" ] || { echo "ไม่พบภาพ: $IMAGE"; exit 1; }
  echo "โหมด: ภาพนิ่ง + สโลว์ซูมเบาๆ (Ken Burns กลับไปกลับมา ให้ลูปเนียน)"
  ARGS+=(-loop 1 -framerate "$FPS" -i "$IMAGE")
  if [ -n "$AUDIO" ]; then
    [ -f "$AUDIO" ] || { echo "ไม่พบเสียง: $AUDIO"; exit 1; }
    ARGS+=(-stream_loop -1 -i "$AUDIO")
    MAP=(-map 0:v:0 -map 1:a:0)
  else
    echo "⚠ ไม่ได้ใส่ --audio -> จะใส่เสียงเงียบ (anullsrc) แทน (YouTube ต้องมีแทร็กเสียง)"
    ARGS+=(-f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=44100")
    MAP=(-map 0:v:0 -map 1:a:0)
  fi
fi

"$FF" "${ARGS[@]}" "${MAP[@]}" -t "$SECS" \
  -vf "scale=-2:${HEIGHT},format=yuv420p" \
  -c:v libx264 -preset veryfast -profile:v high -level 4.1 \
  -b:v "${V_KBPS}k" -maxrate "${V_KBPS}k" -bufsize "$(( V_KBPS * 2 ))k" \
  -g $(( FPS * 2 )) -keyint_min $(( FPS * 2 )) -sc_threshold 0 \
  -c:a aac -b:a "${A_KBPS}k" -ar 44100 -ac 2 \
  -movflags +faststart "$OUT"

ls -lh "$OUT"
echo
echo "ไฟล์พร้อมสตรีม (YouTube spec: H.264 High / keyint 2s / AAC 44.1k)"
echo "อัปขึ้น GitHub Release (ลิมิต 2 GB/ไฟล์):"
echo "  ./publish_media_to_github.sh live-media \"$OUT\""
echo "สตรีมแบบ copy (CPU ~0):"
echo "  COPY_MODE=1 VIDEO=$OUT ./stream.sh"
