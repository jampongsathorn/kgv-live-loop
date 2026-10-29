# สถานะการติดตั้ง (อัปเดต 2026-10-30)

## ✅ เสร็จแล้ว

| รายการ | สถานะ |
|---|---|
| ช่อง | K-GoodVibe (`UC2jSpXIE4QcaRBUFY1WyxKA`) |
| OAuth token | ใช้ได้ — scope `https://www.googleapis.com/auth/youtube` (Live API ผ่าน) |
| Live stream | `2jSpXIE4QcaRBUFY1WyxKA1793305568516024` "Default stream key" — สถานะ `ready` |
| Broadcast | [`absVeqJ9_SM`](https://youtube.com/watch?v=absVeqJ9_SM) — `public` / `ready` |
| `enableAutoStart` | `True` (encoder ต่อเข้ามา = ขึ้นไลฟ์เอง) |
| `enableAutoStop` | **`False`** (แก้จาก `True` — เน็ตหลุด 30 วิ ต้องไม่จบรายการ) |
| `latencyPreference` | **`normal`** (แก้จาก `low` — low latency ทำให้ 24/7 หลุดง่าย) |
| DVR / recordFromStart | `True` / `True` |
| ชื่อ broadcast | `🔴 K-GoodVibe Radio 24/7 \| Korean City Pop & Lo-fi \| Study · Work · Sleep` |
| GitHub secrets | `YOUTUBE_STREAM_KEY`, `RTMP_URL`, `BACKUP_URL` ✔ |
| Repo | https://github.com/jampongsathorn/kgv-live-loop (public) |
| Workflow | `24-7 YouTube live loop` — cron ทุก 2 ชม. + queued hand-off (~0 ช่องว่าง) |

ค่า ingest (ยืนยันจาก API):
```
primary : rtmp://a.rtmp.youtube.com/live2
backup  : rtmp://b.rtmp.youtube.com/live2?backup=1
key     : (ตั้งเป็น secret แล้ว — ไม่แสดงในไฟล์นี้)
```

## ❌ ยังขาด: ไฟล์วิดีโอสำหรับวนลูป

workflow จะ fail ที่ step "Get the loop video" ถ้าไม่มีอย่างใดอย่างหนึ่ง:
`loop.mp4` ใน repo / secret `VIDEO_URL` / secret `DRIVE_FILE_ID`

ไฟล์ 3 ชม. ต้นฉบับไม่อยู่ใน Drive (มีแต่ Shorts) และ `K-Song1.zip` (120 MB) เกินขีดจำกัด 100 MB ของ sandbox

### 3 ทางเลือก

**A. โหลดคลิปของตัวเองจาก YouTube Studio** (ง่ายสุด, คุณภาพ 1080p)
Studio → คลิป 3 ชม. → ⋮ → Download → อัปขึ้น Drive → เอา file id มาใส่ secret `DRIVE_FILE_ID`
(เป็นเนื้อหาของคุณเอง ดาวน์โหลดผ่าน Studio ถูกต้องตามนโยบาย YouTube)

**B. render ใหม่แล้วเก็บไฟล์**
รัน `KGoodVibe_Music_Workflow` อีกครั้งแต่ **ไม่ต้องอัป YouTube** แค่เซฟ mp4 → `make_loop_file.sh` → host

**C. ให้ sandbox สร้างลูปให้**
ส่งไฟล์เสียง (mp3/wav <100 MB) + ปกที่ต้องการ → สร้างลูป 1080p 60 นาที (ภาพปก + falling leaves จาก `make_leaf_loop.py` + เสียง) แล้วอัปขึ้น Drive ให้อัตโนมัติ

## ⚠️ ต้องทำเอง (ความปลอดภัย)

- **revoke GitHub PAT** ที่ paste ในแชท: https://github.com/settings/tokens
- ไฟล์ `kgoodvibe_youtube_oauth_tokens.json` มี `client_secret` + `refresh_token` ฝังอยู่ — ถ้าต้องการหมุนใหม่ ทำใน Google Cloud Console
- หลังใส่ไฟล์วิดีโอเสร็จ: ไปที่ https://github.com/jampongsathorn/kgv-live-loop/actions → Run workflow → ขึ้นไลฟ์ภายใน ~60 วินาที

## บั๊กที่แก้ระหว่างทาง

| ไฟล์ | ปัญหา | แก้เป็น |
|---|---|---|
| `kgv_live.py`, `kgv_end.py` | `mine=true` + `broadcastStatus=all` → HTTP 400 Incompatible parameters | ตัด `broadcastStatus` ออกเมื่อใช้ `mine` |
| `kgv_live.py` | สร้าง stream ใหม่ทับของเดิม | ใช้ Default stream key เดิมก่อนถ้ามี |
| `stream.sh` | `-f tee` ฟ้อง "Output file does not contain any stream" | เพิ่ม `-map 0:v:0 -map 0:a:0` |
| `stream.sh` | `MAX_SECONDS` ไม่หยุด ffmpeg กลางทาง | ใส่ `-t` ตาม budget ที่เหลือ |
| `kgv_live.py` | อัปเดต `scheduledStartTime` บน broadcast ที่เคยไลฟ์แล้ว → 403 | ไม่ส่งฟิลด์นี้ตอน update |
