#!/usr/bin/env bash
# publish_media_to_github.sh — เก็บไฟล์วิดีโอใหญ่ (ไม่เกิน 2 GB/ไฟล์) ไว้บน GitHub Release
#
# ทำไม: workspace/sandbox รับไฟล์ได้แค่ 100 MB และ repo รับได้ 100 MB/ไฟล์
#       แต่ GitHub Release asset รับได้ถึง 2 GB/ไฟล์ และ runner ดาวน์โหลดได้ตรงๆ
#
# ใช้:
#   ./publish_media_to_github.sh live-media loop_3h_1080p.mp4
#   GH_TOKEN=ghp_xxx ./publish_media_to_github.sh live-media loop_3h_1080p.mp4
#
# ต้องมี env: GH_TOKEN (หรือ gh auth login ไว้แล้ว)
# repo ปลายทาง: ตั้ง REPO=owner/name หรือปล่อยว่างให้อ่านจาก git remote
set -euo pipefail

TAG="${1:?usage: $0 <release-tag> <file>}"
FILE="${2:?ระบุไฟล์ที่ต้องการอัปโหลด}"
[ -f "$FILE" ] || { echo "ไม่พบไฟล์: $FILE"; exit 1; }

SIZE=$(stat -c%s "$FILE" 2>/dev/null || stat -f%z "$FILE")
LIMIT=$(( 2 * 1024 * 1024 * 1024 ))
if [ "$SIZE" -ge "$LIMIT" ]; then
  cat <<EOF
❌ ไฟล์ ${SIZE} bytes เกิน 2 GB/ไฟล์ ของ GitHub Release
   แก้ได้ 3 ทาง:
   1) ลด bitrate:  ./make_3hr_loop.sh --fit-check --hours 3 --max-gb 1.8   แล้ว encode ใหม่
   2) แยกเป็นหลายพาร์ท (part1/part2) แล้วใช้ playlist concat ในสตรีม
   3) ใช้ host อื่น: Cloudflare R2 (ฟรี 10 GB, ไม่มีค่า egress) / B2 / S3
EOF
  exit 1
fi

GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
if [ -z "$GH_TOKEN" ]; then
  command -v gh >/dev/null || { echo "ไม่มี gh และไม่มี GH_TOKEN"; exit 1; }
  GH_TOKEN=$(gh auth token)
fi

REPO="${REPO:-$(git config --get remote.origin.url 2>/dev/null | sed -E 's#.*github\.com[:/]([^/]+/[^/.]+)(\.git)?#\1#')}"
[ -n "$REPO" ] || { echo "ระบุ REPO=owner/name"; exit 1; }
echo "repo: $REPO | tag: $TAG | file: $FILE ($(du -h "$FILE" | cut -f1))"

api() { # method path [json]
  local m="$1" p="$2" d="${3:-}"
  if [ -n "$d" ]; then
    curl -sS -X "$m" -H "Authorization: Bearer $GH_TOKEN" \
      -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" \
      -H "Content-Type: application/json" -d "$d" "https://api.github.com$p"
  else
    curl -sS -X "$m" -H "Authorization: Bearer $GH_TOKEN" \
      -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com$p"
  fi
}

# 1) หา release จาก tag หรือสร้างใหม่
RID=$(api GET "/repos/$REPO/releases/tags/$TAG" | python3 -c "
import json,sys
try: print(json.load(sys.stdin).get('id',''))
except Exception: print('')
")
if [ -z "$RID" ]; then
  echo "→ สร้าง release '$TAG'"
  RID=$(api POST "/repos/$REPO/releases" "{\"tag_name\":\"$TAG\",\"name\":\"Live media — $TAG\",\"body\":\"ไฟล์วิดีโอสำหรับสตรีม 24/7 (อัปโหลดอัตโนมัติ)\",\"draft\":false,\"prerelease\":false}" \
        | python3 -c "import json,sys; print(json.load(sys.stdin).get('id',''))")
  [ -n "$RID" ] || { echo "สร้าง release ไม่สำเร็จ"; exit 1; }
else
  echo "→ ใช้ release เดิม id=$RID"
fi

# 2) อัปโหลด asset (แทนที่ของเดิมชื่อเดียวกันถ้ามี)
NAME=$(basename "$FILE")
EXIST=$(api GET "/repos/$REPO/releases/$RID/assets" | python3 -c "
import json,sys
n='$NAME'
for a in json.load(sys.stdin):
    if a['name']==n: print(a['id']); break
")
if [ -n "$EXIST" ]; then
  echo "→ ลบ asset เดิม id=$EXIST"
  api DELETE "/repos/$REPO/releases/assets/$EXIST" >/dev/null
fi

echo "→ กำลังอัปโหลด (ไม่มีความคืบหน้าแสดงจนจบ)..."
RESP=$(curl -sS -X POST \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -H "Content-Type: application/octet-stream" \
  --data-binary "@$FILE" \
  "https://uploads.github.com/repos/$REPO/releases/$RID/assets?name=$NAME")

URL=$(printf '%s' "$RESP" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(d.get('browser_download_url') or d.get('message',''))
")
case "$URL" in
  http*) echo "✔ อัปโหลดสำเร็จ"; echo "URL: $URL"
         echo
         echo "ตั้งเป็น secret ให้ workflow ใช้:"
         echo "  VIDEO_URL=$URL"
         echo
         echo "หรือบันทึกเป็น secret อัตโนมัติ (ถ้าใช้ gh):"
         echo "  printf '%s' \"$URL\" | gh secret set VIDEO_URL --repo $REPO" ;;
  *) echo "❌ อัปโหลดไม่สำเร็จ: $URL"; exit 1 ;;
esac
