# 3 ชั่วโมงทำงานยังไง + เก็บไฟล์ใหญ่บน GitHub

## 1. คำตอบสั้น: ไม่ต้องมีไฟล์ 3 ชม. เลย

`stream.sh` ใช้ `ffmpeg -re -stream_loop -1 -i VIDEO -t <ความยาว>` — วนไฟล์ "สั้นแค่ไหนก็ได้" ซ้ำไม่จำกัด
แล้วตัดจบที่วินาทีที่กำหนด นี่คือกลไกทั้งหมด:

```
ไฟล์ 36 วินาที  ──(-stream_loop -1)──►  วนซ้ำไม่จำกัด  ──(-t 10800)──►  live 3 ชั่วโมงพอดี
```

**ทดสอบแล้วในแซนด์บ็อกซ์:** ไฟล์ 3 วินาที + `-t 12` → ได้ไฟล์ยาว **12.02 วินาที** (ไม่ใช่ 3 วิ ไม่ใช่ 6 วิ)

### สองค่าที่ต่างกัน (คนมักสับสน)

| ค่า | หมายถึง | ตั้งที่ |
|---|---|---|
| `STREAM_MINUTES` (input ตอนกด Run workflow) | **ความยาวของ live** — default `180` = 3 ชม. | หน้า GitHub Actions |
| `MAX_SECONDS` (คำนวณให้เอง = นาที × 60 − 60) | หยุด ffmpeg ก่อน GitHub ฆ่าที่ 6 ชม. | ใน `live.yml` |

กด Run workflow → ใส่ `180` → ได้ live 3 ชม. จบเองในงานเดียว **ไม่ต้องมีไฟล์ 3 ชม.**

### งบเวลาบน GitHub Actions

| ต้องการ | จำเป็นต้องมี |
|---|---|
| live 3 ชม. | จบใน 1 job (ลิมิต job = 6 ชม.) ✅ |
| live 24/7 | ต่อ job ทุก 3 ชม. → cron ทุก 2 ชม. ที่ตั้งไว้จะต่อคิวให้ชิดกัน |
| live 12 ชม. | ต้องใช้ 2-stage relay (เกิน 6 ชม./job) |

> ไฟล์ 60 วินาทีที่วนซ้ำ = ใช้ bandwidth เท่าเดิมแต่ได้ live ยาวเท่าที่ต้องการ
> ข้อควรระวังเดียว: ถ้าไฟล์สั้นเกินไป ภาพจะดูซ้ำเร็ว — แนะนำ **60 วินาที – 5 นาที** สำหรับภาพนิ่ง/ลูปอนิเมชัน และ **20–60 นาที** ถ้าเป็นเพลงที่มีท่อนชัดเจน

---

## 2. ถ้าไฟล์ใหญ่เกิน จะเก็บบน GitHub ยังไง

มี 3 เพดานที่ต่างกัน — ตัวเลขนี้คือเหตุผลที่ต้องมี Release:

| ที่เก็บ | ลิมิต/ไฟล์ | ใช้กับ |
|---|---|---|
| workspace/sandbox | **100 MB** | สร้าง/แก้ไฟล์ชั่วคราว |
| repo (git) | **100 MB** (เตือนที่ 50 MB) | โค้ด, สคริปต์, ภาพปก |
| **GitHub Release asset** | **2 GB** | ไฟล์วิดีโอสำหรับสตรีม ✅ |

### ทางเลือกฟรีที่ใหญ่กว่า (ถ้าต้องการ 1080p 3 ชม. ~6 GB)
- Cloudflare R2 — ฟรี 10 GB, **egress ฟรีไม่จำกัด** (ดีที่สุดสำหรับงานนี้)
- Backblaze B2 — ฟรี 10 GB
- เก็บเป็นหลายพาร์ทใน Release แล้วใช้ `concat` รวมตอนสตรีม

### คำนวณขนาดล่วงหน้า
```bash
./make_3hr_loop.sh --fit-check --hours 3 --max-gb 1.8
# เป้าหมาย : 3 ชม. (10800 วิ) @ 1080p30
# เพดานไฟล์: 1.8 GB  ->  total 1431 kbps  (video 1303k + audio 128k)
# คาดว่าได้ : ~1.8 GB
```
เทียบให้เห็น: 3 ชม. ที่ 1080p ปกติ (4500k) = **6.04 GB** ❌ เกิน 2 GB
แต่ภาพนิ่ง/ลูปเบาๆ ที่ 1300k ก็ดูดีได้ เพราะเนื้อหาแทบไม่เปลี่ยนเฟรม

---

## 3. ขั้นตอนใช้งานจริง

### ทาง A — ลูปสั้น (แนะนำ, ไม่ต้องเก็บไฟล์ใหญ่เลย)
```bash
# 1) สร้าง loop สั้นๆ จากปก (หรือใช้ไฟล์ที่คุณมี)
./make_3hr_loop.sh --image K-Cover1/Autumn_Glow_01.jpg --audio song.mp3 --hours 0.05   # 3 นาที

# 2) อัปขึ้น GitHub Release (ไฟล์ละไม่เกิน 2 GB)
./publish_media_to_github.sh live-media loop_0h_1080p.mp4

# 3) เอา URL ที่ได้ไปใส่ secret VIDEO_URL แล้วกด Run workflow ใส่ 180 (นาที)
```
ได้ live 3 ชม. จากไฟล์ 3 นาที

### ทาง B — ไฟล์ 3 ชม. เดี่ยว (ถ้าอยากได้ archive ที่ตรงกับ long-form)
```bash
./make_3hr_loop.sh --image cover.jpg --audio full_track.mp3 --hours 3 --max-gb 1.8
./publish_media_to_github.sh live-media loop_3h_1080p.mp4
```
ไฟล์จะถูกบีบให้พอดี 1.8 GB เพื่อผ่านลิมิต 2 GB ของ Release

---

## 4. ผลทดสอบ end-to-end ที่ทำจริง (ไม่ใช่ทฤษฎี)

| ขั้น | ผล |
|---|---|
| encode 36 วิจากภาพ | `Duration: 00:00:36.00` / H.264 High / 1280×720 / keyint 2s / AAC 44.1k stereo ✅ |
| อัปขึ้น Release | `✔ https://github.com/.../releases/download/live-media/test_loop.mp4` ✅ |
| runner ดาวน์โหลดไม่ต้อง auth | `http=200 size=812176` ✅ (repo public) |
| workflow รัน | run #1 **completed success** ใน 1 นาที 48 วิ ✅ |
| สตรีมจริง | `speed=1.01x`, `ffmpeg exited rc=0`, 60 วิตาม budget ✅ |
| **ฝั่ง YouTube** | `streamStatus: active` / `healthStatus: good` / broadcast **`live` + `public`** ✅ |
| ปิดรายการ | `kgv_end.py` → `live -> complete` ✅ (`streamStatus: inactive`) |

url ของ live ที่ขึ้นจริง: `https://youtube.com/watch?v=absVeqJ9_SM`
run log: `https://github.com/jampongsathorn/kgv-live-loop/actions/runs/40951260317`

> หมายเหตุ: การทดสอบใช้ไฟล์ทดสอบ (ภาพไล่สี ไม่มีเพลง) 60 วินาที แล้วปิดรายการทิ้งแล้ว
> — ครั้งต่อไปที่รันด้วยไฟล์จริง จะขึ้นไลฟ์ใหม่บน broadcast เดิม (reusable) ได้เลย

---

## 5. ไฟล์ที่เพิ่มในเทิร์นนี้

| ไฟล์ | หน้าที่ |
|---|---|
| `make_3hr_loop.sh` | สร้างลูป/ไฟล์ยาว N ชั่วโมง, คำนวณ bitrate ให้พอดีเพดาน, `--fit-check` ดูก่อนได้ |
| `publish_media_to_github.sh` | อัปไฟล์ใหญ่ (≤2 GB) ขึ้น GitHub Release + คืน URL ให้เอาไปใส่ secret |
| `.github/workflows/live.yml` | เพิ่ม input `minutes` (default 180 = 3 ชม.), รองรับ Drive/Release URL |
