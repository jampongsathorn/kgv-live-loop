# วิธีทำ Live YouTube แบบวนลูป 24/7 ด้วย GitHub (ฉบับภาษาไทย)

> แปลและเรียบเรียงจาก `README.md` — ทุกอย่างที่อยู่ในโฟลเดอร์นี้ใช้ได้จริง: `stream.sh` + GitHub Actions

---

## 0. อ่านก่อน (สำคัญ)

"ทำ live วนลูป 24 ชั่วโมงบน YouTube โดยใช้ GitHub" = ต้องมีอะไรบางอย่างที่ **ส่งวิดีโอเข้า RTMP ของ YouTube ตลอดเวลาไม่หยุด** GitHub เป็นที่ฟรีที่คนใช้ทำสิ่งนี้ มันทำได้ แต่มีกับดัก 4 ข้อ:

| กับดัก | รายละเอียด | ทางแก้ |
|---|---|---|
| **งานถูกฆ่าที่ 6 ชม.** | job บนเครื่อง GitHub-hosted จะถูกยกเลิกที่ 6 ชั่วโมง เลี่ยงไม่ได้ | ใช้ cron ทุก 6 ชม. + ให้สคริปต์จบเองที่ 5 ชม. 45 น. แล้วรอบถัดไปเริ่มต่อ (คนดูจะเห็นภาพสะดุด 30–120 วินาทีทุกรอบ) |
| **cron ไม่ใช่เวลาที่แม่น** | งานตาม schedule เริ่มช้า (1–15 นาที) และอาจถูกข้ามตอนคนใช้เยอะ **อีกทั้ง GitHub จะปิด workflow แบบ schedule ถ้า repo ไม่มี commit 60 วัน** | commit อะไรก็ได้ หรือกด Run workflow ทุกๆ ไม่กี่สัปดาห์ |
| **กฎการใช้งานของ GitHub** | Actions มีไว้สำหรับ "production, testing, deployment หรือ publication ของโปรเจกต์ซอฟต์แวร์" — การสตรีมมีเดียยาวๆ ไม่เข้าข่าย และมี repo ที่ถูกระงับมาแล้ว | ถ้าจะใช้ ใช้ repo เงียบๆ ไม่โปรโมท หรือย้ายไป VPS (§5) — นี่คือคำตอบจริงสำหรับ 24/7 |
| **นาทีฟรี** | repo public = ไม่จำกัดนาที / repo private = 2,000 นาที/เดือน แล้วคิดเงิน 24/7 กิน ~720 ชม./เดือน | ใช้ repo **public** แต่ **ห้ามใส่ stream key ในไฟล์** ใส่ใน Secrets เท่านั้น |

ฝั่ง YouTube ต้องเตรียมก่อน:

- ยืนยันช่องด้วยเบอร์โทรที่ `youtube.com/verify` → เปิด Live ใน YouTube Studio → **รอ 24 ชั่วโมง** (รอครั้งเดียว)
- ไม่มี strike จาก Community Guidelines ใน 90 วันล่าสุด
- การวนลูปวิดีโอ **ของคนอื่น** = ลิขสิทธิ์ + โดน strike ใช้ฟุตเทจ/เพลงที่คุณมีสิทธิ์ ถ้าจะ monetize ต้องอ่านนโยบาย "reused content" ของ YouTube ด้วย

---

## 1. สองสถาปัตยกรรม

**A. GitHub Actions** (ฟรี, ไม่เสถียร, ขาดช่วงทุก 6 ชม.) — คือไฟล์ใน `yt-live-loop/`

**B. เครื่องที่เปิดตลอด** (Oracle Cloud Always Free, แล็ปท็อปเก่า, Raspberry Pi 4 หรือ self-hosted runner) — ffmpeg ตัวเดียวรันได้หลายเดือน ไม่มีช่วงขาด ใช้ `stream.sh` ตัวเดียวกัน รันใต้ `systemd` หรือ `tmux` **คนที่ทำช่อง lo-fi หาเงินจริงใช้วิธีนี้**

ลอง A ก่อนเพื่อเรียนรู้ แล้วย้ายไป B เมื่อเริ่มแคร์ uptime

---

## 2. ฝั่ง YouTube: เอา stream key (5 นาที)

1. YouTube Studio → **สร้าง → ถ่ายทอดสด → สตรีม** (ไม่ใช่ "เว็บแคม")
2. ใส่ชื่อ, รูปปก, หมวดหมู่, ตั้ง **การมองเห็น Public/Unlisted**
3. Latency: เลือก **ปกติ (Normal)** — low-latency ทำให้ 24/7 ลูปไม่เสถียร เปิด DVR ด้วย
4. คัดลอก **Stream key** (`xxxx-xxxx-xxxx-xxxx`) และ **Stream URL** `rtmp://a.rtmp.youtube.com/live2`
5. ไปที่ **การตั้งค่าสตรีม → เริ่ม/หยุดอัตโนมัติ** เปิด **Auto-start** ไว้ → ช่องจะขึ้น live ทันทีที่ encoder ต่อเข้ามา (จำเป็นมากสำหรับลูปที่รีสตาร์ททุก 6 ชม.)
6. stream key = รหัสผ่าน ใครมีก็ออกอากาศเข้าช่องคุณได้ ถ้าหลุดให้กด **รีเซ็ต**

---

## 3. ฝั่ง GitHub: ตั้งค่า 10 นาที

```bash
# 1. สร้าง repo public ว่างๆ บน github.com (ชื่อเช่น "live-loop") แล้ว:
cd yt-live-loop
git init && git add . && git commit -m "24/7 loop"
git branch -M main
git remote add origin https://github.com/ชื่อคุณ/live-loop.git
git push -u origin main
```

```bash
# 2. ใส่วิดีโอ (ไฟล์ละไม่เกิน 100 MB ไม่งั้นใช้ GitHub Release หรือลิงก์แทน)
cp /path/to/your-loop.mp4 ./loop.mp4
git add loop.mp4 && git commit -m "video" && git push
```

**ใส่ secret** → repo **Settings → Secrets and variables → Actions → New repository secret**:

| ชื่อ | ค่า |
|---|---|
| `YOUTUBE_STREAM_KEY` | key จาก YouTube Studio |
| `VIDEO_URL` *(ไม่บังคับ)* | ลิงก์ตรงไปยังไฟล์ mp4 (Google Drive `uc?export=download&id=…`, GitHub Release asset, S3/R2) ถ้าใส่ ระบบจะโหลดไฟล์นี้แทนไฟล์ใน repo |

**เริ่มสตรีม** → แท็บ **Actions** → `24-7 YouTube live loop` → **Run workflow**
ภายใน ~60 วินาที YouTube Studio ควรขึ้น "สตรีมกำลังไลฟ์" และออกอากาศอัตโนมัติ

จากนั้นมันจะรีสตาร์ทตัวเองทุก 6 ชั่วโมงและวนลูปต่อไป

### ไฟล์ในโปรเจกต์

| ไฟล์ | หน้าที่ |
|---|---|
| `.github/workflows/live.yml` | ติดตั้ง ffmpeg, เตรียมวิดีโอ, รัน `stream.sh` สูงสุด 5 ชม. 45 น., ต่อด้วย cron ทุก 6 ชม. |
| `stream.sh` | ลูป `ffmpeg -re -stream_loop -1` ไม่มีที่สิ้นสุด + ต่อใหม่เมื่อหลุด + จบตัวเองก่อนโดนฆ่าที่ 6 ชม. |

ปรับได้ผ่าน env vars: `V_BITRATE` (4500k ≈ 1080p30, 2500k ≈ 720p), `A_BITRATE` (เพลงใช้ 192k), `MAX_SECONDS`

ข้อกำหนด YouTube: H.264 + AAC, **keyframe ทุก 2 วินาที** (`-g 60` ที่ 30fps), FLV over RTMP, AAC สเตอริโอ ≥128 kbps — ถ้าผิดข้อ keyframe จะโดนจำกัดหรือหลุด

### ทางลัดประหยัด CPU: encode ไว้ก่อนแล้ว copy
encode บน runner 2 คอร์คือสาเหตุหลักของภาพกระตุก ให้ encode ไฟล์เองให้ตรงสเปก YouTube (H.264 High, yuv420p, `keyint=60`, CBR) แล้วสตรีมด้วย `-c:v copy -c:a copy` แทบไม่กิน CPU:

```bash
ffmpeg -re -stream_loop -1 -i loop.mp4 -c:v copy -c:a copy -f flv "$RTMP_URL/$STREAM_KEY"
```

### หลายไฟล์เรียงต่อกัน (playlist)
```bash
printf "file '%s'\n" /path/videos/*.mp4 > list.txt
ffmpeg -re -f concat -safe 0 -stream_loop -1 -i list.txt -c:v libx264 ... -f flv "$RTMP_URL/$STREAM_KEY"
```

---

## 4. repo บน GitHub ที่ "มี setup อยู่แล้ว" (คัดมาให้)

ผมค้นใน GitHub แล้ว นี่คือของที่ใช้ได้จริง เรียงตามความเหมาะสม:

| Repo | สถานะ | เหมาะกับ | ข้อควรระวัง |
|---|---|---|---|
| **[gokulramg11-byte/rain-youtube-stream](https://github.com/gokulramg11-byte/rain-youtube-stream)** | ครบสุด: Bash + FFmpeg + Docker + systemd + **GitHub Actions** แบ่ง 4 ก้อน/วัน (5 ชม. 50 น. + พัก 10 น.) | ถ้าอยากได้ทั้ง Actions และ VPS ในโปรเจกต์เดียว | ตั้งเวลาเป็น IST ต้องแก้ cron |
| **[anishbhattarai-asm/247yt](https://github.com/anishbhattarai-asm/247yt)** | ตัวเต็มสำหรับ VPS: มีแผงควบคุมบนมือถือ, playlist, lofi mode, reconnect, Discord แจ้งเตือน | 24/7 จริงจัง (ต้องมีเซิร์ฟเวอร์) | ต้องมี VPS ไม่ใช่แค่ GitHub |
| **[hajilok/youtube-live-streaming](https://github.com/hajilok/youtube-live-streaming)** (⭐50, fork 32) | Node.js + ffmpeg + ลูป lofi ให้ในตัว | เริ่มเร็วสุด แก้ command เดียว | เจ้าของบอกเองว่าบางทีมี error, ไม่มี auto-restart ที่ดี |
| **[ec-026/ytstream](https://github.com/ec-026/ytstream)** (⭐7) | `yt.sh` + `keep_alive.py` สำหรับ VPS | ตัวอย่างสั้น อ่านง่าย | ต้องมี VPS |
| **[cloudnxne/24-7-Youtube-stream](https://github.com/cloudnxne/24-7-Youtube-stream)** | Docker, แยกโฟลเดอร์ assets/secrets ที่ git-ignore ให้ | คนที่ถนัด Docker | README บอกเองว่ายังไม่ผ่านการทดสอบไลฟ์เต็มรูปแบบ |
| **[NoniDOTio/LiveStreamRadio](https://github.com/NoniDOTio/LiveStreamRadio)** (⭐47) | วิทยุเพลง 24/7 ด้วย ffmpeg + mpg123 | ช่องเพลง/วิทยุ | ไม่มี auto-reconnect ที่ทันสมัย |
| **[Reveal80/lofi-radio](https://github.com/Reveal80/lofi-radio)** | Docker Compose + mediamtx + แผงควบคุม (สเปน) | อยากได้หน้าเว็บพรีวิว | เอกสารภาษาสเปน |

**วิธีตรวจ repo ก่อนใช้ (สำคัญมาก):**
1. อ่าน `.github/workflows/*.yml` ทีละบรรทัด — repo อันตรายอาจ `curl` เอา secret ของคุณไปให้ host อื่น **อย่าใส่ secret ใน workflow ที่ยังไม่ได้อ่าน**
2. fork มาดัดแปลง แล้วเก็บ key ใน Secrets เท่านั้น
3. ดู commit ล่าสุด + ดาว/ fork — หลาย repo ตายแล้ว
4. ทดสอบด้วยวิดีโอสั้น 2 นาที และตั้งเป็น **Unlisted** ก่อน

---

## 5. ทางที่เสถียร (แนะนำถ้าจะทำจริง)

**Oracle Cloud Always Free** (ARM 4 คอร์ / RAM 24 GB ฟรีตลอดชีพ) คือที่ที่คนใช้กัน:

```bash
sudo apt update && sudo apt install -y ffmpeg
mkdir -p ~/stream && cd ~/stream     # วาง stream.sh + loop.mp4 ที่นี่
nano ~/stream.env                    # STREAM_KEY=xxxx-xxxx-xxxx-xxxx
```

`/etc/systemd/system/youtube-loop.service`:

```ini
[Unit]
Description=YouTube 24/7 loop
After=network-online.target
Wants=network-online.target

[Service]
EnvironmentFile=/home/ubuntu/stream.env
Environment=VIDEO=/home/ubuntu/stream/loop.mp4
Environment=MAX_SECONDS=999999999
ExecStart=/bin/bash /home/ubuntu/stream/stream.sh
Restart=always
RestartSec=10
User=ubuntu

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now youtube-loop
journalctl -u youtube-loop -f      # ดู log
```

แบนด์วิดท์ที่ต้องใช้: ~4.5 Mbps upload ตลอดเวลา ≈ 1.5 TB/เดือน — เช็ค egress cap ของผู้ให้บริการ
**ห้ามใช้ host ที่ sleep ได้** (Render free, Fly.io scale-to-zero, Replit) เพราะจะตัดสตรีมทิ้ง

อีกทางที่ไม่ต้องมี VPS: ลงทะเบียนเครื่องตัวเองเป็น **self-hosted runner** → เพดานงานขึ้นเป็น 5 วัน และไม่กินนาที Actions

---

## 6. แก้ปัญหา

| อาการ | สาเหตุ | วิธีแก้ |
|---|---|---|
| job เขียว แต่ YouTube ขึ้น "ไม่มีข้อมูล" | RTMP URL หรือ key ผิด | ต้องเป็น `rtmp://a.rtmp.youtube.com/live2/<KEY>` ไม่มี `/` ต่อท้าย ไม่ใช่ https |
| "Stream key ไม่ถูกต้อง" | คัดลอกมาแล้วมีช่องว่าง หรือ key ถูก reset | คัดลอกใหม่จาก Studio → ตั้งค่าสตรีม |
| ภาพกระตุก / เตือน "การเชื่อมต่อไม่ดี" | CPU runner เต็มเพราะ encode | encode ไว้ก่อน + `-c:v copy` หรือลดเป็น 720p/2500k |
| หลุดทุก 6 ชม. แล้วไม่กลับมา | cron ช้า หรือ workflow ถูกปิด (ไม่มีความเคลื่อนไหว 60 วัน) | เช็คแท็บ Actions, commit ใหม่ หรือย้ายไป VPS |
| จอดำ มีแต่เสียง | ลืม `-pix_fmt yuv420p` | อย่าลบ flag นี้ใน `stream.sh` |
| เสียงไม่ตรงภาพหลังลูปวนรอบใหม่ | ความยาวเสียงของไฟล์ต้นฉบับไม่พอดี | encode ไฟล์ใหม่ให้สะอาด หรือใช้ playlist |
| YouTube ปิดเสียง / ให้ strike | มีเพลงหรือฟุตเทจติดลิขสิทธิ์ | ใช้เนื้อหาที่มีสิทธิ์ |
| ffmpeg ออกทันที, log ขึ้น "Input/output error" | key ถูก reset หรือมี encoder อื่นต่ออยู่ | reset key, อัปเดต secret หรือปิดตัวที่ต่ออยู่ |

---

## สรุปสั้นๆ

1. YouTube Studio → ถ่ายทอดสด → สตรีม → คัดลอก key + เปิด auto-start
2. push repo นี้พร้อม `loop.mp4` และ secret `YOUTUBE_STREAM_KEY`
3. Actions → Run workflow → มันจะรีสตาร์ทตัวเองทุก 6 ชม.
4. เบื่อช่วงขาดทุก 6 ชม. แล้ว → ย้าย `stream.sh` ไป Oracle VM ใต้ systemd รันได้เป็นเดือน
