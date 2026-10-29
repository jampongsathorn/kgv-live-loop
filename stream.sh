#!/usr/bin/env bash
# stream.sh — K-GoodVibe live loop -> YouTube RTMP
#
# โหมดการทำงาน
#   1) เปิดตลอด (WINDOW ว่าง)                      -> เหมาะกับ VPS + broadcast แบบ auto-start
#   2) เปิดเฉพาะช่วงเวลา WINDOW="22:00-06:00"      -> เปิด/ปิดเองตามเวลา Asia/Bangkok (รองรับข้ามเที่ยงคืน)
#   3) COPY_MODE=1                                 -> สตรีมด้วย -c:v copy (CPU ~0, ต้อง pre-encode ด้วย make_loop_file.sh)
#
# env ที่ใช้
#   STREAM_KEY        (จำเป็น) stream key จาก YouTube Studio หรือจาก kgv_live.py
#   VIDEO             default loop.mp4
#   RTMP_URL          default rtmp://a.rtmp.youtube.com/live2
#   V_BITRATE         4500k (1080p30) / 2500k (720p)
#   A_BITRATE         192k (เพลงควร 192k)
#   COPY_MODE         1 = ไม่ encode, สตรีมไฟล์ที่ encode มาแล้ว
#   WINDOW             "22:00-06:00" = ช่วงเวลาเปิด, ว่าง = เปิดตลอด
#   TZ_NAME           default Asia/Bangkok
#   MAX_SECONDS       หยุดตัวเองก่อน GitHub ฆ่าที่ 6 ชม. (default 20700 = 5 ชม. 45 น.)
#   HEALTHCHECK_URL   (ไม่บังคับ) ping ทุก 5 นาที กันตายเงียบ
set -uo pipefail

# ───────── pure helpers (ทดสอบได้: KGV_LIB_ONLY=1 bash stream.sh) ─────────
to_min() { # "HH:MM" -> minutes ของวัน
  local hm="${1:-}"
  if [[ ! "$hm" =~ ^([0-9]{1,2}):([0-9]{2})$ ]]; then
    echo "ERROR: รูปแบบเวลาไม่ถูกต้อง: '$hm' (ต้องเป็น HH:MM)" >&2
    return 1
  fi
  echo $(( 10#${BASH_REMATCH[1]} * 60 + 10#${BASH_REMATCH[2]} ))
}

in_window_min() { # $1=now_min $2=start_min $3=end_min
  local now="$1" s="$2" e="$3"
  [ "$s" -eq "$e" ] && return 0                 # เปิด 24 ชม.
  if [ "$s" -lt "$e" ]; then                    # เช่น 06:00-22:00
    [ "$now" -ge "$s" ] && [ "$now" -lt "$e" ]
  else                                          # เช่น 22:00-06:00 (ข้ามเที่ยงคืน)
    [ "$now" -ge "$s" ] || [ "$now" -lt "$e" ]
  fi
}

minutes_until() { # $1=now_min $2=target_min -> 0..1439
  echo $(( ( $2 - $1 + 1440 ) % 1440 ))
}

now_min() { local hm; hm=$(TZ="$TZ_NAME" date +%H:%M); to_min "$hm"; }
now_hm()  { TZ="$TZ_NAME" date +%H:%M; }

if [ "${KGV_LIB_ONLY:-0}" = "1" ]; then return 0 2>/dev/null || exit 0; fi

# ───────── config ─────────
: "${STREAM_KEY:?ตั้ง STREAM_KEY ก่อน (env หรือ secrets YOUTUBE_STREAM_KEY)}"
VIDEO="${VIDEO:-loop.mp4}"
RTMP_URL="${RTMP_URL:-rtmp://a.rtmp.youtube.com/live2}"
V_BITRATE="${V_BITRATE:-4500k}"
A_BITRATE="${A_BITRATE:-192k}"
COPY_MODE="${COPY_MODE:-0}"
WINDOW="${WINDOW:-}"
TZ_NAME="${TZ_NAME:-Asia/Bangkok}"
MAX_SECONDS="${MAX_SECONDS:-20700}"
HEALTHCHECK_URL="${HEALTHCHECK_URL:-}"
BACKUP_URL="${BACKUP_URL:-}"   # เช่น rtmp://b.rtmp.youtube.com/live2?backup=1
ON_EXIT_CMD="${ON_EXIT_CMD:-}"  # คำสั่งที่จะรันตอนจบ (เช่น จบ broadcast ด้วย kgv_end.py)
PLAY_ONCE="${PLAY_ONCE:-0}"     # 1 = เล่นไฟล์จบรอบเดียวไม่วนซ้ำ (เพลงไม่ซ้ำในรอบ)

NUM="${V_BITRATE%[kK]}"; BUF="$(( ${NUM:-4500} * 2 ))k"

WS=""; WE=""
if [ -n "$WINDOW" ]; then
  [ "${WINDOW#*-}" != "$WINDOW" ] || { echo "ERROR: WINDOW ต้องเป็น HH:MM-HH:MM"; exit 1; }
  WS=$(to_min "${WINDOW%%-*}") || exit 1
  WE=$(to_min "${WINDOW##*-}") || exit 1
fi

[ -f "$VIDEO" ] || { echo "ERROR: ไม่พบไฟล์วิดีโอ: $VIDEO"; exit 1; }
[ -r "$VIDEO" ] || { echo "ERROR: อ่านไฟล์ไม่ได้: $VIDEO"; exit 1; }


# ───────── healthcheck pinger ─────────
PINGER_PID=""
EXIT_CMD_DONE=0
cleanup() {
  [ -n "$PINGER_PID" ] && kill "$PINGER_PID" 2>/dev/null
  echo "ปิดสตรีม $(TZ="$TZ_NAME" date '+%Y-%m-%d %H:%M:%S %Z')"
  if [ -n "$ON_EXIT_CMD" ] && [ "$EXIT_CMD_DONE" = "0" ]; then
    EXIT_CMD_DONE=1
    echo "รัน ON_EXIT_CMD: $ON_EXIT_CMD"
    # จำกัดเวลา 120 วิ กันค้างตอน systemd stop
    timeout 120 bash -c "$ON_EXIT_CMD" || echo "ON_EXIT_CMD ออกด้วย rc=$?"
  fi
}
trap cleanup EXIT INT TERM
if [ -n "$HEALTHCHECK_URL" ]; then
  ( while :; do curl -fsS -m 10 -o /dev/null "$HEALTHCHECK_URL" 2>/dev/null; sleep 300; done ) &
  PINGER_PID=$!
fi

echo "video=$VIDEO copy_mode=$COPY_MODE window=${WINDOW:-always} tz=$TZ_NAME bitrate=$V_BITRATE budget=${MAX_SECONDS}s backup=${BACKUP_URL:-no}"

start=$SECONDS
while :; do
  elapsed=$(( SECONDS - start ))
  if [ "$elapsed" -ge "$MAX_SECONDS" ]; then
    echo "ครบ budget ${elapsed}s — จบงานนี้เพื่อให้รอบถัดไป (cron) ต่อสตรีม"
    exit 0
  fi

  limit=""
  if [ -n "$WS" ]; then
    cur=$(now_min)
    if ! in_window_min "$cur" "$WS" "$WE"; then
      wait_min=$(minutes_until "$cur" "$WS")
      echo "[$(now_hm)] นอกเวลา (window $WINDOW) — รอเปิดอีก ${wait_min} นาที"

      # nap แบบไม่เกิน budget และไม่ทำให้ get_process_output ค้างนาน
      nap=$(( wait_min * 60 ))
      budget_left=$(( MAX_SECONDS - elapsed + 1 ))
      [ "$nap" -gt "$budget_left" ] && nap="$budget_left"
      while [ "$nap" -gt 0 ]; do
        step=60; [ "$nap" -lt 60 ] && step="$nap"
        sleep "$step"
        nap=$(( nap - step ))
        if [ $(( SECONDS - start )) -ge "$MAX_SECONDS" ]; then
          echo "ครบ budget ระหว่างรอ — จบงาน"
          exit 0
        fi
      done
      continue
    fi
    limit=$(( $(minutes_until "$cur" "$WE") * 60 ))
    echo "[$(now_hm)] อยู่ในเวลา — สตรีมอีก ${limit}s จนถึง $WINDOW"
  fi

  # ให้ ffmpeg หยุดเองเมื่อครบ budget (ไม่ใช่รอให้ GitHub ฆ่า) และไม่เกินเวลาที่เหลือของ window
  budget_left=$(( MAX_SECONDS - elapsed ))
  if [ -z "$limit" ] || [ "$limit" -gt "$budget_left" ]; then
    limit="$budget_left"
  fi
  [ "$limit" -gt 0 ] && echo "[$(now_hm)] จะสตรีมต่ออีกไม่เกิน ${limit}s"

  if [ "$PLAY_ONCE" = "1" ]; then
    args=(-hide_banner -loglevel warning -stats -re -i "$VIDEO")
  else
    args=(-hide_banner -loglevel warning -stats -re -stream_loop -1 -i "$VIDEO")
  fi
  [ -n "$limit" ] && args+=(-t "$limit")

  if [ "$COPY_MODE" = "1" ]; then
    args+=(-c:v copy -c:a copy)
  else
    args+=(-c:v libx264 -preset veryfast -tune zerolatency -profile:v high -pix_fmt yuv420p
           -b:v "$V_BITRATE" -maxrate "$V_BITRATE" -bufsize "$BUF"
           -g 60 -keyint_min 60 -sc_threshold 0
           -c:a aac -b:a "$A_BITRATE" -ar 44100 -ac 2)
  fi

  if [ -n "$BACKUP_URL" ]; then
    # ส่งออก 2 ที่พร้อมกันด้วย tee: encode ครั้งเดียว ไม่กิน CPU เพิ่ม
    # ต้องมี -map ชัดเจน ไม่งั้น tee จะฟ้อง "Output file does not contain any stream"
    args+=(-map 0:v:0 -map 0:a:0 -f tee "[f=flv]${RTMP_URL}/${STREAM_KEY}|[f=flv]${BACKUP_URL}")
  else
    args+=(-f flv "${RTMP_URL}/${STREAM_KEY}")
  fi

  echo "[$(now_hm)] ffmpeg starting"
  ffmpeg "${args[@]}"
  rc=$?
  echo "ffmpeg exited rc=$rc"

  # โหมดรอบเดียว: จบไฟล์ = จบรอบ ห้ามวนซ้ำ (กันเพลงซ้ำ)
  if [ "$PLAY_ONCE" = "1" ] && [ "$rc" = "0" ]; then
    echo "เล่นครบรอบแล้ว (PLAY_ONCE=1) — จบงาน ไม่วนซ้ำ"
    exit 0
  fi

  # ออกจากช่วงเวลาแล้ว -> กลับไปรอรอบถัดไป (ไม่ต้อง reconnect)
  if [ -n "$WS" ]; then
    cur=$(now_min)
    in_window_min "$cur" "$WS" "$WE" || { echo "จบช่วงเวลาแล้ว — พัก"; continue; }
  fi
  sleep 5
done
