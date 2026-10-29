# K-GoodVibe — แผนทำ Live 24/7 (พาะโปรเจกต์นี้)

> อ่าน context จาก Google Drive แล้ว: ช่อง **K-GoodVibe** (`UC2jSpXIE4QcaRBUFY1WyxKA` / `@k-goodvibe`)
> คอนเทนต์ = เพลง City Pop / Lo-fi / Workday Pop ธีมเกาหลี-ญี่ปุ่น ความยาว 3 ชม. + Shorts
> มีระบบ `kgv_auto_scheduler.py` + `auto_run_kgv.py` โพสต์อัตโนมัติตาม Golden Slot (06:00 / 19:00 BKK)
> คลังที่มี: `K-Cover1.zip` (91 ปก), `K-CleanCovers.zip`, `K-Song1.zip`, `Korea-Short1.zip`, 3 ชม. ที่อัปแล้ว: `eKNgf0RtPqM` (V002), `bB2_STB0a4I` (V003), `Fndk8jfTLlA` (V007), `GrwAyHVYsPg`, `jFvpcImGF9o`, `H7daWXliNh8`
>
> **สรุปสั้น:** ทำได้ และโปรเจกต์นี้พร้อมที่สุดในบรรดาคนที่ถามเรื่องนี้ เพราะมีไฟล์ต้นฉบับ + ปก + ระบบ OAuth อยู่แล้ว แต่มี 3 จุดที่ต้องตัดสินใจก่อน (หัวข้อ 1)

---

## 1. 3 เรื่องที่ต้องรู้ก่อนกดเริ่ม (เฉพาะช่องคุณ)

### 1.1 Live 24/7 จะ "กิน" คิวโพสต์ 3 ชม. ที่ตั้งไว้ 35 คลิป
ช่องคุณมีตารางโพสต์ถึง 22 ธ.ค. 2026 และเพลงเดียวกันถูกปล่อยซ้ำเป็น long-form 3 ชม. หลายรอบ
ถ้าเปิด live 24/7 บนช่องเดียวกันพร้อมกัน:

- YouTube จะเลือก **live** ขึ้นหน้า Home/Recommended แทน scheduled upload → คลิปที่ตั้ง `publishAt` ไว้จะได้ reach น้อยลง
- คลิป 3 ชม. ที่เพิ่งปล่อย (เช่น `eKNgf0RtPqM` เมื่อ 29 ต.ค. 20:30 BKK) จะแย่งคนดูกับ live ที่เล่นเพลงชุดเดียวกัน
- อัลกอริทึมมอง "เนื้อหาซ้ำบนช่องเดียวกัน" เป็นสัญญาณลบ

**ทางเลือกที่แนะนำ (เลือก 1):**
| ทางเลือก | ข้อดี | ข้อเสีย |
|---|---|---|
| **A. Live เฉพาะช่วงกลางคืน** `22:00–06:00 BKK` (8 ชม./วัน) | ไม่ชน Golden Slot 06:00/19:00, ได้ watch time ช่วงคนนอน | ต้องมี watchdog เปิด-ปิดตามเวลา |
| **B. แยกช่องที่ 2** "K-GoodVibe Radio" live 24/7 | ช่องหลักไม่โดนกิน, ทำ SEO ข้ามช่องได้ | ต้องปั้นช่องใหม่ แชร์ OAuth token เดิมไม่ได้ (คนละ channel) |
| **C. Live 24/7 บนช่องเดิมเลย** | ง่ายสุด, watch time พุ่ง | เสี่ยง cannibalize + monetization review ถ้าเนื้อหาซ้ำเยอะ |

ถ้าเป้าหมายคือ "มี live ตลอดเพื่อเก็บ watch hours" → **A** คุ้มที่สุดสำหรับช่องที่มีตารางโพสต์อยู่แล้ว

### 1.2 6-hour cap ของ GitHub Actions ชนกับคอนเทนต์ 3 ชม. พอดี
รอบละ 6 ชม. = 2 รอบของเพลง 3 ชม. ถ้าใช้ GitHub ทุก 6 ชม. คนดูจะเจอ "สตรีมสิ้นสุด" 2–4 ครั้ง/วัน
สำหรับช่องที่ทำเงิน **ควรใช้ VPS ฟรี (Oracle) รัน ffmpeg ตัวเดียวต่อเนื่องเป็นเดือน** — GitHub ใช้แค่ทดสอบ (ดูหัวข้อ 4)

### 1.3 ไฟล์ต้นฉบับ 3 ชม. ไม่ได้อยู่ใน Drive
ผมค้น Drive แล้ว: ไฟล์ `.mp4` ที่มีเป็น **Shorts** (`story-series-ep01..ep15`, 2–12 MB) เท่านั้น
ส่วนไฟล์ 3 ชม. ถูก render ใน sandbox/Colab แล้ว `videos.insert` ขึ้น YouTube ตรงๆ ไม่ได้เก็บไฟล์ไว้

**ต้องทำก่อนสตรีม (เลือก 1):**
1. **โรงงานเดิม:** รัน `KGoodVibe_Music_Workflow` render 3 ชม. อีกครั้ง **แต่เก็บ mp4 ไว้** (ไม่ต้องอัป YouTube) → ได้ไฟล์ต้นฉบับไป host
2. **ดาวน์โหลดของตัวเองจาก Studio:** YouTube Studio → คลิป → ⋮ → Download (ได้เฉพาะคลิปที่คุณเป็นเจ้าของ, 1080p) → เป็นเนื้อหาของคุณเอง ไม่ผิดกฎ
3. **สร้างไฟล์สั้นลงสำหรับ live:** 45–60 นาที 720p (~1 GB) วนซ้ำ — คนดู live ไม่นับ chapter อยู่แล้ว และไฟล์เล็กลด bandwidth/ค่า host
   → ใช้ `make_loop_file.sh` ในโฟลเดอร์นี้

> ข้อ 2 สำคัญ: อย่าใช้เครื่องมือโหลด YouTube ทั่วไป (yt-dlp) กับคลิปคนอื่น – แต่คลิปตัวเองสามารถโหลดจาก Studio ได้ตามปกติ

---

## 2. สถาปัตยกรรมที่เหมาะกับ K-GoodVibe

```
[render 3 ชม. / 60 นาที]  →  make_loop_file.sh  →  loop_1080p.mp4 (CBR, keyint=60)
                                                        │
                              host ไฟล์ (R2 / Drive / VPS เอง)
                                                        │
                          ffmpeg -re -stream_loop -1 -c:v copy
                                                        │
                              rtmp://a.rtmp.youtube.com/live2/<KEY>
                                                        │
                        YouTube Live "K-GoodVibe Radio 24/7" (auto-start ON)
```

จุดที่คนพลาดและทำให้ภาพกระตุก: **encode สดบนเครื่อง 2 คอร์** วิธีของโปรเจกต์นี้คือ encode ครั้งเดียวด้วย `make_loop_file.sh` แล้วสตรีมแบบ `-c:v copy` → CPU แทบ 0 แม้แต่ Raspberry Pi ก็ไหว

---

## 2.5 URL สตรีม & URL เซิร์ฟเวอร์สำรอง — เอามาจากไหน

### หาใน YouTube Studio (ทำครั้งเดียว)
1. YouTube Studio → **สร้าง (Create)** → **ถ่ายทอดสด (Go live)** → แท็บ **สตรีม (Stream)**
2. ถ้าเพิ่งเคยใช้ จะมีปุ่มให้กรอกชื่อ/หมวด/ความเป็นส่วนตัว แล้วกด **สร้างสตรีม** ก่อน — **URL จะยังไม่โผล่จนกว่าจะสร้าง**
3. ในกล่อง **การตั้งค่าสตรีม (Stream settings)** จะเห็น 2 ค่า:
   - **URL สตรีม (Stream URL)** → `rtmp://a.rtmp.youtube.com/live2`
   - **คีย์สตรีม (Stream key)** → `xxxx-xxxx-xxxx-xxxx-xxxx` (กดรูปตาเพื่อแสดง)
4. **URL ของเซิร์ฟเวอร์สำรอง (Backup server URL)** อยู่ในกล่องเดียวกัน (บางบัญชีต้องกดขยาย/กางรายละเอียดคีย์ก่อน) → `rtmp://b.rtmp.youtube.com/live2?backup=1`
   ถ้าหาในหน้าเว็บไม่เจอ ใช้ API ดึงได้ (สคริปต์ผมทำไว้แล้ว): `cdn.ingestionInfo.backupIngestionAddress`
5. **RTMPS (แนะนำ):** กด **รูปกุญแจ** ข้างช่อง URL สตรีม → URL เปลี่ยนเป็น `rtmps://a.rtmps.youtube.com/live2` (พอร์ต 443)
   ใช้เมื่อพอร์ต 1935 ถูกบล็อก (เน็ตมือถือ/ออฟฟิศ/บาง VPS)

### ตารางค่าจริง

| 用途 | URL | พอร์ต |
|---|---|---|
| Primary RTMP | `rtmp://a.rtmp.youtube.com/live2` | 1935 |
| **Backup RTMP** | `rtmp://b.rtmp.youtube.com/live2?backup=1` | 1935 |
| Primary RTMPS | `rtmps://a.rtmps.youtube.com/live2` (หรือ `:443`) | 443 |
| Backup RTMPS | `rtmps://b.rtmps.youtube.com/live2?backup=1` | 443 |

> กฎการเอาค่าไปใช้: เครื่องมือแบบ **ช่องเดียว (ffmpeg, สคริปต์นี้)** → ต่อกันเป็น `URL/KEY`
> เครื่องมือแบบ **2 ช่อง (OBS)** → ใส่ URL ในช่อง Server, ใส่ key ในช่อง Stream Key (อย่าสลับกัน)

### เรื่องที่คนเข้าใจผิดบ่อย: backup ≠ ตัวสำรองอัตโนมัติ
- `b.rtmp...?backup=1` คือ **ช่องทางที่ 2 ที่ต้องส่งสัญญาณเข้าไปพร้อมกันตลอดเวลา** ไม่ใช่ "สำรองไว้ค่อยใช้ตอนหลักล่ม"
- ถ้าตั้งค่า feed ที่ 2 ไม่เหมือน primary เป๊ะ (ความละเอียด, codec, bitrate, fps, keyframe 2 วิ, audio) YouTube จะไม่สลับให้
- เปิด dual ingest = **ใช้แบนด์วิดท์ upload เพิ่มเป็น 2 เท่า** (4.5 → 9 Mbps) ถ้าเน็ตที่ใช้ไม่เหลือ ควรปิด
- YouTube ไม่รับประกันว่าหลักกลับมาแล้วจะสลับกลับเอง และไม่รับประกันว่าภาพจะไม่สะดุดตอนสลับ

### ใช้กับสคริปต์ในโฟลเดอร์นี้ (ทำไว้แล้ว)
```bash
# ส่ง 2 ที่พร้อมกัน ด้วยการ encode ครั้งเดียว (ไม่กิน CPU เพิ่ม)
BR="rtmp://b.rtmp.youtube.com/live2?backup=1"
STREAM_KEY=xxxx-xxxx-xxxx-xxxx-xxxx BACKUP_URL="$BR" VIDEO=loop_1080p.mp4 \
  COPY_MODE=1 ./stream.sh

# หรือผ่าน kgv_live.py: ดึง primary+backup จาก API ให้เอง
python3 kgv_live.py --video loop_1080p.mp4 --copy --run            # ส่งทั้ง primary + backup
python3 kgv_live.py --rtmps --video loop_1080p.mp4 --copy --run    # ใช้ RTMPS 443 ทั้งคู่
python3 kgv_live.py --no-backup --video loop_1080p.mp4 --copy --run # ปิด feed ที่ 2 ประหยัดเน็ต
```
`kgv_live.py` จะพิมพ์ให้ครบทั้ง 4 ค่า (primary / backup / rtmps / rtmps backup) และเขียนลง env ให้:
```bash
python3 kgv_live.py --env-out ~/stream.env --no-stream   # ได้ STREAM_KEY, RTMP_URL, BACKUP_URL ในไฟล์ mode 600
```

**เทสแล้วในแซนด์บ็อกซ์:** `-f tee` + `-map` ส่ง 2 ปลายทางได้ไฟล์ขนาดเท่ากันเป๊ะ (3,150,333 bytes ทั้งคู่) และจบแบบ clean (rc=0) เมื่อครบ budget
*(ต้องมี `-map 0:v:0 -map 0:a:0` ไม่งั้น ffmpeg ฟ้อง `Output file does not contain any stream` — เจอตอนเทสและแก้แล้ว)*

---

## 2.6 ค่าจริงที่กรอกแล้ว (ของคุณ) + คำสั่งพร้อมใช้

```
URL สตรีม                rtmp://a.rtmp.youtube.com/live2
URL ของเซิร์ฟเวอร์สำรอง   rtmp://b.rtmp.youtube.com/live2?backup=1
คีย์สตรีม                xxxx-xxxx-xxxx-xxxx-xxxx   (คีย์เดียว ใช้ทั้ง 2 ช่องทาง)
```

### 1) เตรียมไฟล์ config (ทำครั้งเดียว)
```bash
cp env.example ~/stream.env
nano ~/stream.env          # เติม STREAM_KEY=xxxx-xxxx-xxxx-xxxx-xxxx
chmod 600 ~/stream.env     # ห้ามให้คนอื่นอ่าน
```

### 2) ทดสอบสั้นๆ 30 วินาทีก่อน (สำคัญ)
```bash
set -a; source ~/stream.env; set +a
timeout 30 ffmpeg -re -stream_loop -1 -i "$VIDEO" -t 25 \
  -c:v copy -c:a copy -f tee \
  "[f=flv]${RTMP_URL}/${STREAM_KEY}|[f=flv]${BACKUP_URL}" -map 0:v:0 -map 0:a:0
```
*(ถ้ายังไม่มีไฟล์ encode ให้ใช้โหมด encode แทน: ตัด `-t 25` ออกแล้วใส่ `-c:v libx264 -preset veryfast -pix_fmt yuv420p -g 60 -c:a aac -b:a 192k`)*
แล้วเปิด Live Control Room ดูว่า **"สถานะสตรีม: ดี"** และภาพขึ้นจริง → ค่อยรันยาว

### 3) รันยาวบน VPS
```bash
set -a; source ~/stream.env; set +a
./stream.sh                      # อ่านทุกค่าจาก env ที่ source มา
# หรือให้ systemd ทำ (ดูหัวข้อ 7.5) — และถ้าอยากให้ kgv_live.py ดึง URL จาก API เอง:
python3 kgv_live.py --video "$VIDEO" --copy --run
```

### 4) ใช้กับ GitHub Actions
Secrets (Settings → Secrets and variables → Actions):
| ชื่อ secret | ค่า |
|---|---|
| `YOUTUBE_STREAM_KEY` | คีย์สตรีม |
| `VIDEO_URL` หรือ `DRIVE_FILE_ID` | ที่เก็บไฟล์ loop |

แล้วใน workflow เพิ่ม 2 บรรทัดนี้ในบล็อก `env:` ของ step "Stream to YouTube":
```yaml
          RTMP_URL: rtmp://a.rtmp.youtube.com/live2
          BACKUP_URL: rtmp://b.rtmp.youtube.com/live2?backup=1
```
> บน GitHub Actions **ไม่แนะนำให้เปิด backup**: ดึงไฟล์ + encode + อัปโหลด 9 Mbps บน runner แชร์ จะทำให้ drop frame ง่าย ให้ใส่ `BACKUP_URL: ""` ตอนเทสบน Actions แล้วเปิดเฉพาะบน VPS

### 5) เช็กลิสต์ก่อนเปิดจริง
- [ ] คีย์สตรีมใน `~/stream.env` mode 600 และไม่เคย commit ขึ้น git
- [ ] ทดสอบ 25 วินาทีแล้ว Studio ขึ้น "ดี" (ทั้ง primary; ถ้าเปิด backup ดูว่าไม่มี error ฝั่ง b.)
- [ ] `enableAutoStop: False` (ไม่งั้นเน็ตสะดุด 30 วิ = รายการจบ)
- [ ] ถ้าใช้ `WINDOW` → จำว่าต้องกด End เองตอนจบช่วง (หรือให้ผมเพิ่ม transition ให้)
- [ ] ถ้าเน็ตอัปโหลด < 10 Mbps → **ปิด backup** (`BACKUP_URL=`)

---

## 3. ขั้นตอนทำจริง (VPS ฟรี — แนะนำ)

### 3.1 เตรียมไฟล์ (ทำใน Arena/เครื่องตัวเองครั้งเดียว)
```bash
chmod +x make_loop_file.sh
./make_loop_file.sh /path/to/KGV_V003_3hours.mp4
# ได้: KGV_V003_3hours_loop_1080p.mp4  (~6 GB / 3 ชม.)
#      KGV_V003_3hours_loop_720p.mp4   (~1.2 GB)
```
ถ้าอยากให้ loop เนียน (ไม่มีรอยต่อเงียบ): coupaudio ให้เฟดเข้า-ออก 0.5 วิที่หัวท้ายก่อน encode หรือใช้ไฟล์ 60 นาทีที่ตัดตรงจังหวะ

### 3.2 สร้าง Live บน YouTube (ทำมือครั้งเดียว — ชัวร์ที่สุด)
1. YouTube Studio → **สร้าง → ถ่ายทอดสด → สตรีม**
2. ชื่อแนะนำ (ใส่คีย์เวิร์ดที่ช่องคุณแรงอยู่แล้ว):
   `🔴 24/7 Korean City Pop & Lo-fi Radio | Autumn Workday Pop — Study · Work · Sleep | K-GoodVibe`
3. รูปปก: ใช้ `K-Cover1.zip` → `Autumn_Glow_01.jpg` หรือ `Workday_Pop_01.jpg` (1280×720) — ใช้ปกชุดเดียวกับ long-form เพื่อจำแบรนด์
4. **Latency = Normal** (low-latency ทำให้ 24/7 หลุดง่าย), เปิด **DVR** (คนเข้าช้าได้ดูย้อน)
5. **การตั้งค่าสตรีม → Auto-start ON / Auto-stop OFF** ← สำคัญสุด: ถ้า auto-stop เปิด เน็ตสะดุดนิดเดียวรายการจะจบ
6. คัดลอก **Stream key**
7. ติ๊ก **Altered or synthetic content = Yes** (เพลงคุณเป็น AI-generated — ตรงกับที่ handoff ระบุไว้)
8. Playlist: ผูก live เข้า playlist `PLP59TNDc7Rj4` เดิมไม่ได้ (คนละประเภท) → สร้าง playlist "K-GoodVibe Radio 24/7"

### 3.3 ติดตั้งบน VPS (Oracle Cloud Always Free ARM 4 คอร์ / 24 GB)
```bash
sudo apt update && sudo apt install -y ffmpeg
mkdir -p ~/stream && cd ~/stream
# อัปโหลด loop_1080p.mp4 ขึ้นมา (scp หรือ rclone จาก Drive)
cp /path/stream.sh ~/stream/ && chmod +x ~/stream/stream.sh

cat > ~/stream.env <<'EOF'
STREAM_KEY=xxxx-xxxx-xxxx-xxxx
VIDEO=/home/ubuntu/stream/loop_1080p.mp4
V_BITRATE=4500k
A_BITRATE=192k
MAX_SECONDS=999999999
EOF
chmod 600 ~/stream.env      # ← key ต้องอ่านได้คนเดียว
```
`/etc/systemd/system/kgv-live.service`:
```ini
[Unit]
Description=K-GoodVibe YouTube 24/7 loop
After=network-online.target
Wants=network-online.target

[Service]
EnvironmentFile=/home/ubuntu/stream.env
ExecStart=/bin/bash /home/ubuntu/stream/stream.sh
Restart=always
RestartSec=10
User=ubuntu

[Install]
WantedBy=multi-user.target
```
```bash
sudo systemctl daemon-reload && sudo systemctl enable --now kgv-live
journalctl -u kgv-live -f
```
ถ้าต้องการ "เฉพาะกลางคืน 22:00–06:00 BKK" → เพิ่ม systemd timer 2 ตัว (start/stop) หรือใส่ `MAX_SECONDS=28800` แล้วให้ timer ปลุกใหม่ตอน 22:00

### 3.4 ตั้ง Auto-restart แบบกันตาย (สำคัญ)
VPS ฟรีอาจถูก reclaim ถ้า idle — สตรีม ffmpeg ถือว่า active อยู่แล้ว แต่ควรมี:
- **Healthchecks.io** (ฟรี): ให้ `stream.sh` ping ทุก 5 นาที ถ้าขาด → ส่งเมล/LINE
- **cron ทุก 6 ชม.** `systemctl is-active kgv-live || systemctl restart kgv-live`
- `journalctl -u kgv-live --since "1 hour ago" | grep -i "error\|bitrate"` ดูทุกวันอาทิตย์

---

## 4. ทาง GitHub Actions (ใช้ทดสอบเท่านั้น)

ไฟล์พร้อมแล้ว: `.github/workflows/live.yml` + `stream.sh`
```bash
cd yt-live-loop && git init && git add . && git commit -m "kgv live loop"
git remote add origin https://github.com/<คุณ>/kgv-live.git && git push -u origin main
```
Secrets ที่ต้องใส่ (Settings → Secrets → Actions):
| ชื่อ | ค่า |
|---|---|
| `YOUTUBE_STREAM_KEY` | key จาก Studio |
| `DRIVE_FILE_ID` | ไฟล์ `K-Song1.zip`? ไม่ใช่ — ต้องเป็น **mp4** ที่ render แล้ว (หรือใช้ `VIDEO_URL`) |
| `VIDEO_URL` | ลิงก์ตรง (Cloudflare R2 / GitHub Release / S3) — แนะนำกว่า Drive |
> Workflow รองรับ Drive ผ่าน `gdown` แล้ว (กันปัญหาไฟล์ >100 MB ที่ต้องกด confirm)

**ข้อจำกัดที่ต้องยอมรับถ้าใช้ GitHub:**
- job ตายที่ 6 ชม. → สตรีมขาด 2–4 ครั้ง/วัน (คนดูหาย)
- workflow schedule ถูกปิดถ้า repo ไม่มี commit 60 วัน
- **ผิดนโยบาย GitHub Actions** (Actions มีไว้ทำ CI/CD ไม่ใช่ broadcast) — repo เคยถูกระงับมาแล้ว และ repo ต้อง public ถ้าอยากฟรี → stream key อยู่ใน Secrets ก็จริง แต่ repo public = workflow ของคุณถูก fork ได้
- ดึงไฟล์ 6 GB ทุก 6 ชม. = 24 GB/วัน จาก Drive → ชน quota/throttle ของ Drive

**สรุป: GitHub = ทดสอบ 1–2 วัน / VPS = ของจริง**

---

## 5. ทางเลือก: สร้าง Live อัตโนมัติด้วย YouTube Live API (ต่อยอดจากสคริปต์เดิม)

โปรเจกต์คุณมี `kgoodvibe_youtube_oauth_tokens.json` + OAuth consent อยู่สถานะ `In production` แล้ว → สร้าง broadcast/liveStream ด้วย API ได้เลย ทำให้ **ไม่ต้องกรอก key มือ** และ **rotate key ได้เอง**

```python
# ต่อท้ายระบบเดิม: สร้าง live stream + broadcast แล้วดึง ingestion key ออกมา
from googleapiclient.discovery import build

yt = build("youtube", "v3", credentials=creds)   # creds ตัวเดียวกับ videos.insert

stream = yt.liveStreams().insert(part="snippet,cdn,contentDetails,status", body={
    "snippet": {"title": "KGV Live ingest"},
    "cdn": {
        "frameRate": "30fps", "resolution": "1080p", "ingestionType": "rtmp",
        "ingestionInfo": {"streamName": "kgv", "ingestionAddress": "rtmp://a.rtmp.youtube.com/live2"},
    },
    "contentDetails": {"isReusable": True},
}).execute()

bcast = yt.liveBroadcasts().insert(part="snippet,contentDetails,status", body={
    "snippet": {"title": "🔴 K-GoodVibe Radio 24/7 | Korean City Pop & Lo-fi",
                "scheduledStartTime": "2026-11-01T00:00:00Z"},
    "status": {"privacyStatus": "public", "selfDeclaredMadeForKids": False},
    "contentDetails": {"enableAutoStart": True, "enableAutoStop": False,
                       "enableDvr": True, "latencyPreference": "normal"},
}).execute()

yt.liveBroadcasts().bind(part="id,contentDetails", id=bcast["id"],
                         streamId=stream["id"]).execute()

print(stream["cdn"]["ingestionInfo"]["streamName"])   # ← เอาไปใช้เป็น STREAM_KEY
```
**ข้อควรระวัง:**
- ต้องมี scope `https://www.googleapis.com/auth/youtube` หรือ `youtube.force-ssl` — ถ้า token เดิมมีแค่ `youtube.upload` จะติด 403 → ต้อง re-consent **1 ครั้ง** (ทำใน Arena ได้ ไม่ต้องกด TV code ใหม่ ถ้าใช้ flow เดิม)
- Live API มี quota แยก แต่ `liveBroadcasts.insert` = 50 units ต่อครั้ง (ใช้ไม่กี่ครั้ง/เดือน ไม่กระทบ bucket 10,000 ของ videos)
- อย่าให้บอทสร้าง broadcast ใหม่ทุกครั้งที่ ffmpeg รีสตาร์ท → ใช้ `isReusable: True` และ bind ครั้งเดียว ใช้ key เดิมตลอด
- `enableAutoStop: False` สำคัญมาก ตรงกับที่ handoff เตือนไว้

---

## 6. SEO / เนื้อหา live สำหรับช่องนี้โดยเฉพาะ

คุณมีข้อมูล Golden Slot อยู่แล้ว → ใช้กับ live ได้:

| ตั้งค่า | ค่า |
|---|---|
| ชื่อ | `🔴 24/7 Korean City Pop & Lo-fi Radio \| Workday Pop · Autumn Glow \| Study·Work·Sleep` |
| คำอธิบาย | ใส่ chapter ไม่มีความหมายกับ live → ใส่แทน "what you hear" + tracklist loop + link ไป long-form 3 ชม. ตัวเต็ม + playlist `PLP59TNDc7Rj4` |
| Tags | `korean city pop, korean lofi, work bgm, 作業用BGM, 공부할때 듣는 음악, k-indie, autumn lofi, 24/7 radio` |
| หมวด | Music |
| Thumbnail | ปกจาก `K-Cover1.zip` ตัวที่ theme ตรงกับฤดูกาล (ตอนนี้ = `Autumn_Glow`, `Maple_Days`, `November Light`) |
| Chat | เปิด + ตั้ง moderator, ปักข้อความ "Request → คลิป 3 ชม. ตัวเต็มอยู่ที่ playlist" |
| ภาษา | ใส่ title/desc 3 ภาษา (KR/JP/EN) ตามที่ handoff ระบุว่า JP ให้ AVD 3.2× |

**Cross-promo ที่ควรทำ:** ทุก description ของ long-form 3 ชม. เติมบรรทัด `▶ ฟังต่อเนื่อง 24/7 ที่นี่: <live URL>` → ดึงคนเข้า live และกลับกัน live ก็ปักคอมเมนต์ไป long-form

**ความเสี่ยง monetization ที่ต้องรู้:** YouTube เข้มขึ้นเรื่อง "inauthentic / repetitious content" — live ที่วนเพลงชุดเดิม 24/7 เสี่ยงถูกทบทวน ถ้าเพลงคุณเป็น AI-generated และวนซ้ำทั้งวัน แนะนำ:
- ให้ content เปลี่ยนตามฤดูกาล/ธีมทุก 2 สัปดาห์ (คุณมี 91 ปก + ธีมเยอะอยู่แล้ว → สลับไฟล์ loop ตามเดือน)
- ใส่ overlay เวลา/นาฬิกา หรือ now-playing ตาม theme (ffmpeg `drawtext` ได้ แต่กิน CPU → pre-render ใส่ไฟล์เลย)
- ติ๊ก synthetic content ทุกคลิปให้สม่ำเสมอ

---

## 7. Checklist ก่อนเปิดจริง

- [ ] เปิด Live บนช่องแล้ว / รอ 24 ชม. ผ่านแล้ว
- [ ] มีไฟล์ `loop_1080p.mp4` (encode ด้วย `make_loop_file.sh` แล้ว)
- [ ] ทดสอบยิง RTMP จากเครื่องตัวเอง 5 นาที → Studio ขึ้น "สุขภาพสตรีม: ดี"
- [ ] Auto-start ON / Auto-stop OFF
- [ ] Stream key อยู่ใน `stream.env` mode 600 (ไม่เคยอยู่ใน git)
- [ ] systemd `Restart=always` + healthcheck ทำงาน
- [ ] ตั้งเวลาเปิด-ปิดให้ไม่ชน Golden Slot 06:00 / 19:00 BKK
- [ ] Description ของ long-form 35 คลิป เติมลิงก์ live (ทำผ่าน API ทีละ 50 ได้ = 1 batch)
- [ ] ติ๊ก synthetic content แล้ว

---

## 7.5 ไฟล์ที่สร้างเสร็จแล้ว (ก + ข)

### (ก) `kgv_live.py` — สร้าง/ใช้ซ้ำ broadcast แล้วต่อ ffmpeg ในคำสั่งเดียว

```bash
pip install google-api-python-client google-auth google-auth-httplib2
mkdir -p auth && mv ~/Downloads/kgoodvibe_youtube_oauth_tokens.json auth/youtube_oauth_tokens.json
chmod 600 auth/youtube_oauth_tokens.json

python3 kgv_live.py --check                 # ดู scope อย่างเดียว ไม่ต่อเน็ต
python3 kgv_live.py --list                  # ดู liveStream / broadcast ที่มีอยู่
python3 kgv_live.py --env-out ~/stream.env --no-stream   # สร้าง broadcast + เขียน key (mode 600)
python3 kgv_live.py --video ~/stream/loop_1080p.mp4 --copy --run          # setup + สตรีมเลย
python3 kgv_live.py --video ~/stream/loop_1080p.mp4 --copy --window 22:00-06:00 --run
python3 kgv_live.py --new-key --video loop_1080p.mp4 --copy --run          # key รั่ว → สร้างใหม่
```

สิ่งที่มันทำให้:
- refresh OAuth token เองแล้ว **เขียนกลับลงไฟล์** (ไม่ต้อง re-auth ทุกครั้ง)
- หา `liveStream` ชื่อ `KGV Live ingest (reusable)` ที่มีอยู่ → **ใช้ซ้ำ ไม่สร้างใหม่ทุกรอบ** (ประหยัด quota, key ไม่เปลี่ยน)
- หา broadcast ที่ชื่อ+stream ตรงกันและยัง `created/ready/live` → ใช้ซ้ำ; ถ้าไม่มีจึงสร้างใหม่
- ตั้งค่าตามที่วางไว้: `enableAutoStart: True`, **`enableAutoStop: False`**, `enableDvr: True`, `latencyPreference: normal`
- `bind` ให้เสร็จ แล้ว `os.execvpe` ต่อ `stream.sh` (systemd ยังคุม process เดียว)

**ข้อจำกัดที่เจอตอนเทส (สำคัญ):** token ของคุณตอนนี้มี scope `youtube.upload` (ตามที่ใช้ `videos.insert` อยู่)
→ **Live API ต้องใช้ `youtube.force-ssl` หรือ `youtube`** ถ้าไม่เพิ่มจะได้ 403
สคริปต์จะฟ้องก่อนตั้งแต่วินาทีแรกแบบนี้ (เทสแล้ว):
```
live ok    : NO — ต้อง re-consent ให้มี youtube.force-ssl
```
แก้: re-consent **1 ครั้ง** ด้วย flow เดิม เพิ่ม scope `https://www.googleapis.com/auth/youtube.force-ssl` แล้วเขียนทับไฟล์ token (ยังไม่ต้องทำเดี๋ยวนี้ — ถ้าใช้ key มือจาก Studio ก็ข้ามได้)

### (ข) `stream.sh` — โหมดเปิด-ปิดตามเวลา (เพิ่มจากเดิม)

| env | ค่า | ความหมาย |
|---|---|---|
| `WINDOW` | `22:00-06:00` | เปิดเฉพาะช่วงนี้ (Asia/Bangkok) รองรับข้ามเที่ยงคืน; ว่าง = เปิดตลอด |
| `TZ_NAME` | `Asia/Bangkok` | เขตเวลาที่ใช้คิด window |
| `COPY_MODE` | `1` | `-c:v copy` ไม่ encode (ใช้กับไฟล์จาก `make_loop_file.sh`) |
| `HEALTHCHECK_URL` | URL | ping ทุก 5 นาที (healthchecks.io) |
| `MAX_SECONDS` | `20700` | หยุดก่อน GitHub ฆ่า 6 ชม. (บน VPS ตั้งเป็นเลขเยอะๆ) |

พฤติกรรม:
- นอกเวลา → ไม่ต่อ RTMP เลย แค่ log `นอกเวลา — รอเปิดอีก N นาที` แล้วนอนรอ (นับเวลาเป็นช่วง 60 วิ ไม่กิน CPU)
- ในเวลา → คำนวณเวลาที่เหลือของ window แล้วใส่ `-t <seconds>` ให้ ffmpeg ปิดตัวเองตรงเวลาพอดี
- ffmpeg ตายกลางทาง → รอ 5 วิ แล้วต่อใหม่ (ถ้ายังอยู่ในเวลา)
- จบแล้ว log + trap ปิด pinger ให้เรียบร้อย

**เทสแล้วใน sandbox:** ตรรกะ window ผ่าน 8/8 เคส (23:00 in, 05:59 in, 06:00 out, 12:00 out, ขอบ 22:00 in, 06:00-22:00 ปกติ, start==end = 24 ชม., `minutes_until` ทิศทางถูก)
args ของ ffmpeg ตรวจแล้วว่า encode ลงไฟล์ได้ `rc=0` ทั้งโหมด encode และ copy (ใน sandbox ตัว static ffmpeg segfault ตอนเปิด RTMP ซึ่งเป็นที่ binary ไม่ใช่คำสั่ง — บน VPS ที่มี ffmpeg ปกติไม่มีอาการนี้)

**⚠️ ข้อควรรู้ถ้าใช้ WINDOW:** `enableAutoStop: False` (ที่แนะนำไว้กันเน็ตสะดุด) หมายความว่า **YouTube จะไม่จบรายการให้ตอนครบเวลา** — รายการจะค้างสถานะ "กำลังถ่ายทอดสด" แต่ขึ้นว่าไม่มีสัญญาณ จนกว่าคุณจะกด End เอง
ทางเลือก: (1) ใช้ `enableAutoStop: True` ในโหมดมี window แล้วยอมรับว่าเน็ตหลุด 30 วิ = รายการจบ (ต้องกดสร้างใหม่), หรือ (2) ปล่อยให้ค้างและกด End เองทุกเช้า ~06:00, หรือ (3) เปิด 24/7 ไปเลยไม่ต้องมี window แล้วแก้เรื่อง cannibalize ด้วยการแยกช่อง
→ ถ้าจะเอาแบบ "เปิดกลางคืนแล้วจบเองสวยๆ" บอกผมได้ ผมเพิ่มสคริปต์เรียก `liveBroadcasts.transition` เป็น `complete` ตอนจบ window ให้

### ตัวอย่าง systemd ที่ใช้ของใหม่ทั้งสองชิ้น
```ini
[Unit]
Description=K-GoodVibe live (22:00-06:00 BKK)
After=network-online.target

[Service]
WorkingDirectory=/home/ubuntu/stream
Environment=TZ=Asia/Bangkok
ExecStart=/usr/bin/python3 /home/ubuntu/stream/kgv_live.py \
  --tokens /home/ubuntu/stream/auth/youtube_oauth_tokens.json \
  --video /home/ubuntu/stream/loop_1080p.mp4 \
  --copy --window 22:00-06:00 --healthcheck-url https://hc-ping.com/xxxx \
  --run
Restart=always
RestartSec=15
User=ubuntu

[Install]
WantedBy=multi-user.target
```

---

## 9. ปิดรายการอัตโนมัติ (kgv_end.py) + การขึ้น GitHub

### 9.1 `kgv_end.py` — จบ broadcast ให้เรียบร้อย (ทำเสร็จแล้ว)

ปัญหาเดิม: `enableAutoStop: False` (ที่จำเป็นเพื่อกันเน็ตสะดุดแล้วรายการตาย) ทำให้ครบ 06:00 แล้ว ffmpeg หยุด แต่ YouTube ยังค้างสถานะ "กำลังถ่ายทอดสดแต่ไม่มีสัญญาณ"

```bash
python3 kgv_end.py --dry-run                       # ดูว่าจะจบรายการไหน (ไม่ยิง API)
python3 kgv_end.py                                 # จบรายการที่ชื่อตรงกับ default
python3 kgv_end.py --id AbCdEf12345                # จบรายการที่ระบุ
python3 kgv_end.py --title "K-GoodVibe" --dry-run  # จับจากบางส่วนของชื่อ
python3 kgv_end.py --all-live                      # จบทุก broadcast ที่ยัง live
```
มันจัดการเคส `created/ready/testing` ให้เอง (ต้องผ่าน `live` ก่อนแล้วค่อย `complete` เพราะ YouTube ไม่ให้ข้ามขั้น)

### 9.2 ต่อเข้ากับ stream.sh (ทำเสร็จแล้ว — env `ON_EXIT_CMD`)

`stream.sh` มี `ON_EXIT_CMD` ที่รันตอนจบทุกกรณี (จบ window / ครบ budget / ถูก SIGTERM) พร้อม timeout 120 วิ:

```bash
set -a; source ~/stream.env; set +a
export ON_EXIT_CMD="python3 /home/ubuntu/stream/kgv_end.py --tokens /home/ubuntu/stream/auth/youtube_oauth_tokens.json"
./stream.sh
```

**ระบบครบวงจรแล้ว:** 22:00 เปิดสตรีมเอง → 06:00 หยุด ffmpeg → ยิง `transition → complete` ปิดรายการให้ → ไม่ต้องกดมือ

systemd ที่ควรใช้:
```ini
[Unit]
Description=K-GoodVibe live (22:00-06:00 BKK)
After=network-online.target

[Service]
WorkingDirectory=/home/ubuntu/stream
EnvironmentFile=/home/ubuntu/stream.env
Environment=ON_EXIT_CMD=/usr/bin/python3 /home/ubuntu/stream/kgv_end.py --tokens /home/ubuntu/stream/auth/youtube_oauth_tokens.json
ExecStart=/bin/bash /home/ubuntu/stream/stream.sh
ExecStopPost=/usr/bin/python3 /home/ubuntu/stream/kgv_end.py --tokens /home/ubuntu/stream/auth/youtube_oauth_tokens.json
Restart=always
RestartSec=15
User=ubuntu

[Install]
WantedBy=multi-user.target
```
> ใส่ทั้ง `ON_EXIT_CMD` และ `ExecStopPost` ไว้ได้ — ถ้าตัวหนึ่งพลาด อีกตัวยังปิดให้ (สคริปต์จะบอกว่า "ไม่มี broadcast ที่ต้องจบ" ถ้าจบไปแล้ว ไม่ error)

**ทดสอบแล้ว:** `ON_EXIT_CMD` ถูกเรียกตอนจบ budget จริง (log: `รัน ON_EXIT_CMD: ... → >>> ปิดรายการ broadcast แล้ว ✔`)
`kgv_end.py --help` และ error path (ไม่มีไฟล์ token) ทำงานถูกต้อง — ส่วนการยิง API จริงยังทดสอบไม่ได้จนกว่าจะมี token ที่มี scope `youtube.force-ssl`

### 9.3 ขึ้น GitHub — ผมเข้า GitHub ของคุณไม่ได้

**สถานะจริง:** Arena ไม่มี connector ของ GitHub (ลองแล้วได้ `unsupported` — ไม่ใช่ "ยังไม่เปิด" แต่คือไม่มีให้ใช้ในระบบนี้) เพราะฉะนั้นผม **เปิดดู repo ของคุณแทนไม่ได้** และ **push แทนไม่ได้**

ทางออกที่ผมเตรียมให้: `push_to_github.sh` — คำสั่งเดียวจบ (ใช้ GitHub CLI)

```bash
cd yt-live-loop
./push_to_github.sh kgv-live  public     # หรือ private
```
สคริปต์จะ:
1. เขียน `.gitignore` กัน `auth/`, `*.env`, `*oauth*tokens*.json`, `*.mp4` หลุดขึ้น repo
2. `git init` + commit
3. `gh repo create` + push (สร้าง repo ให้เลย ไม่ต้องไปกดบนเว็บ)
4. ถาม `STREAM_KEY` / `VIDEO_URL` / `DRIVE_FILE_ID` แล้ว `gh secret set` ให้ทันที
5. พิมพ์ลิงก์ Actions + คำสั่ง `gh workflow run live.yml`

**ก่อนรันต้องมี `gh`:**
```bash
sudo apt install gh        # Ubuntu/Debian
brew install gh            # macOS
gh auth login              # ล็อกอินครั้งเดียว
```

### 9.4 ถ้าอยากให้ผมรีวิว/อัปเดต workflow บน GitHub จริง ๆ

เลือกทางใดทางหนึ่ง (ผมทำได้ทั้งหมด):
- **วางลิงก์ repo สาธารณะ** → ผมเปิดอ่าน `.github/workflows/*.yml` ผ่านเว็บได้ แล้วบอกว่ามีอะไรผิด/ไม่ปลอดภัย และเขียนไฟล์ใหม่ให้
- **วางเนื้อหา workflow.yml เดิม** → ผมแก้ให้แล้วส่งกลับเป็นไฟล์เดียวให้เอาไปวางทับ
- **รัน `./push_to_github.sh`** แล้วบอกผมว่า error อะไร ผมไล่แก้ให้

> ผมไม่สามารถรับ stream key หรือไฟล์ token ของคุณในแชทได้ (และไม่ควรส่งให้ใคร) — สคริปต์ออกแบบให้คีย์เข้า `gh secret set` โดยตรง ไม่ผ่านผม

---

## 10. สิ่งที่ผมยังยืนยันให้ไม่ได้

- **GitHub ของคุณ:** connector ของ GitHub ไม่พร้อมใช้ในแชทนี้ (`unsupported`) → ผมเข้าไปดู repo จริงของคุณไม่ได้ ถ้าส่งชื่อ repo/ลิงก์มา ผมช่วยรีวิว `.github/workflows/` ให้ได้ว่า safe หรือมีอะไรผิด
- **repo สำเร็จรูปจาก GitHub:** ที่ผมคัดมาใน `README_th.md` หัวข้อ 4 (`rain-youtube-stream`, `247yt`, `hajilok/youtube-live-streaming`) ใช้แทนกันได้ แต่ของโปรเจกต์คุณเองดีกว่าอยู่แล้วเพราะมีไฟล์ + ปก + OAuth พร้อม
