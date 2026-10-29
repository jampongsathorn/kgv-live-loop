# กติกาการจัดเพลง (build_playlist.py)

## ข้อกำหนดที่บังคับใช้
1. **1 รอบ = 1 การไลฟ์** → ทุกเพลงในรอบต้องไม่ซ้ำกัน (assert ไว้ในสคริปต์ ถ้าซ้ำจะ error ทันที)
2. **สุ่มลำดับทุกครั้ง** → seed = วันที่ (YYYYMMDD) ทำให้ตรวจสอบย้อนหลังได้ว่ารอบนั้นเรียงแบบไหน
3. **ถ้าคลังเพลงสั้นกว่าเวลาที่ต้องการ** → ขึ้นรอบใหม่ (สลับลำดับใหม่) แต่บังคับว่า
   *เพลงแรกของรอบใหม่ ≠ เพลงสุดท้ายของรอบก่อน* (กันฟังแล้วสะดุดว่าเพลงเดิมมาต่อ)
4. **โหมด PLAY_ONCE=1** → สตรีมเล่นจบไฟล์แล้วหยุด ไม่วนซ้ำ (ถ้าไฟล์ = 1 รอบเต็ม จะไม่มีเพลงซ้ำเลย)

## คลังปัจจุบัน
- `K-Song1.zip` → **63 เพลง** (.m4a, 86–95 kbps)
- รวม **2.96 ชั่วโมง** (177.9 นาที) → 1 รอบเต็มพอดีกับ live ~3 ชม.
- เฉลี่ย 2.82 นาที/เพลง (สั้นสุด 139 วิ, ยาวสุด 182 วิ)

## คำสั่ง
```bash
# 1 รอบเต็ม (ใช้ทั้ง 63 เพลง สุ่มลำดับ ไม่ซ้ำ)
python3 build_playlist.py --dir songs --minutes 177 --out concat.txt --json playlist.json

# หลายรอบ (ถ้าอยากได้ 24/7 ต่อเนื่องในไฟล์เดียว)
python3 build_playlist.py --dir songs --minutes 300 --rounds 2 --out concat.txt

# ระบุ seed เอง (ทำซ้ำลำดับเดิมได้)
python3 build_playlist.py --dir songs --seed 20261101 --minutes 177
```

## ทางไปที่ใช้จริงรอบนี้
```
K-Song1.zip (120 MB, Drive)
   └─ curl → unzip → 63 × .m4a
        └─ build_playlist.py (seed 20261029) → concat.txt + playlist.json (63 เพลง, 0 ซ้ำ)
             └─ cover.png (AI 16:9) → คลิป zoom ping-pong 20 วิ
                  └─ ffmpeg: -stream_loop -1 (วิดีโอ) + concat (เสียง) -c:v copy
                       └─ loop_3h_720p.mp4  1.43 GB / 2:57:53 / 1280×720 / AAC 160k
                            └─ GitHub Release (ลิมิต 2 GB) → VIDEO_URL secret
                                 └─ Actions: PLAY_ONCE=1 → เล่นจบรอบเดียว ไม่ซ้ำ
```
