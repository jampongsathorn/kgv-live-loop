#!/usr/bin/env bash
# make_loop_file.sh — เตรียมไฟล์สำหรับ live loop 24/7 จาก render ของ K-GoodVibe
#
# ทำ 2 อย่าง:
#   1) loop_1080p.mp4  = ไฟล์หลักสำหรับสตรีม (H.264 High, CBR, keyint=60)  -> สตรีมด้วย -c:v copy (CPU ~0)
#   2) loop_720p_small.mp4 = ไฟล์เล็กสำหรับ host บน GitHub/Drive/R2 (ถ้าอยากให้ runner โหลดไว)
#
# ใช้: ./make_loop_file.sh KGV_V003_Cover02.mp4
set -euo pipefail

IN="${1:?usage: $0 <source.mp4>}"
BASE="${IN%.*}"

echo "==> probe"
ffprobe -v error -show_entries format=duration,size,bit_rate -show_entries stream=codec_name,width,height,r_frame_rate \
  -of default=nw=1 "$IN"

echo "==> 1/2 encoding 1080p30 CBR (ใช้เวลานานเท่าความยาวคลิป หรือมากกว่า)"
ffmpeg -y -hide_banner -i "$IN" \
  -c:v libx264 -preset medium -profile:v high -level 4.1 -pix_fmt yuv420p \
  -b:v 4500k -maxrate 4500k -bufsize 9000k \
  -g 60 -keyint_min 60 -sc_threshold 0 \
  -c:a aac -b:a 192k -ar 44100 -ac 2 \
  -movflags +faststart \
  "${BASE}_loop_1080p.mp4"

echo "==> 2/2 encoding 720p small (สำหรับ host/โหลดเร็ว)"
ffmpeg -y -hide_banner -i "$IN" \
  -vf "scale=-2:720" \
  -c:v libx264 -preset medium -profile:v high -pix_fmt yuv420p \
  -b:v 2500k -maxrate 2500k -bufsize 5000k \
  -g 60 -keyint_min 60 -sc_threshold 0 \
  -c:a aac -b:a 160k -ar 44100 -ac 2 \
  -movflags +faststart \
  "${BASE}_loop_720p.mp4"

echo
echo "เสร็จแล้ว:"
ls -lh "${BASE}_loop_1080p.mp4" "${BASE}_loop_720p.mp4"
echo
echo "ทดสอบสตรีมแบบ copy (ต้องมี STREAM_KEY):"
echo "  ffmpeg -re -stream_loop -1 -i ${BASE}_loop_1080p.mp4 -c:v copy -c:a copy -f flv \"rtmp://a.rtmp.youtube.com/live2/\$STREAM_KEY\""
