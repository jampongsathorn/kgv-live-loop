#!/usr/bin/env bash
# push_to_github.sh — ดันโปรเจกต์ขึ้น GitHub พร้อมใส่ secrets ให้ครบในคำสั่งเดียว
#
# ใช้:  ./push_to_github.sh <ชื่อ-repo> [public|private]
# ต้องมี: git, GitHub CLI (gh) และล็อกอินแล้ว (gh auth login)
#
# ทำอะไร:
#   1) ตรวจว่า gh ล็อกอินแล้ว
#   2) git init + commit ไฟล์ในโฟลเดอร์นี้ (ไม่รวมไฟล์ลับ)
#   3) สร้าง repo บน GitHub + push
#   4) ใส่ secrets YOUTUBE_STREAM_KEY / VIDEO_URL ให้ workflow ใช้ได้ทันที
set -euo pipefail

REPO_NAME="${1:-kgv-live-loop}"
VISIBILITY="${2:-public}"   # public = GitHub Actions ฟรีไม่จำกัดนาที

say() { printf "\n\033[1m%s\033[0m\n" "$*"; }

command -v git >/dev/null || { echo "ไม่มี git"; exit 1; }
command -v gh  >/dev/null || {
  cat <<'EOF'
ยังไม่มี GitHub CLI (gh) — ติดตั้งก่อน:
  Ubuntu/Debian : sudo apt install gh
  macOS         : brew install gh
  Windows       : winget install GitHub.cli
แล้วรัน: gh auth login
EOF
  exit 1
}

gh auth status >/dev/null 2>&1 || { echo "ยังไม่ล็อกอิน — รัน: gh auth login"; exit 1; }
USER_NAME="$(gh api user --jq .login)"

say "1/4 เตรียม git"
if [ ! -d .git ]; then
  git init -q
  git branch -M main 2>/dev/null || true
fi

# กันไฟล์สำคัญหลุดขึ้น repo
cat > .gitignore <<'EOF'
# secrets / tokens — ห้ามขึ้น git
auth/
*.env
stream.env
.env
*oauth*tokens*.json
kgv_*.log
loop*.mp4
*.mp4
*.flv
__pycache__/
EOF

git add -A
if git diff --cached --quiet; then
  echo "ไม่มีอะไรเปลี่ยน (working tree ว่าง)"
else
  git -c user.name="$USER_NAME" -c user.email="${USER_NAME}@users.noreply.github.com" \
      commit -q -m "K-GoodVibe 24/7 live loop: ffmpeg + GitHub Actions + Live API"
  echo "commit แล้ว"
fi

say "2/4 สร้าง repo และ push"
if git remote get-url origin >/dev/null 2>&1; then
  git push -u origin main
else
  gh repo create "$REPO_NAME" --"$VISIBILITY" --source=. --remote=origin --push
fi

say "3/4 ใส่ secrets"
read -r -p "วาง STREAM_KEY จาก YouTube Studio (เว้นว่างเพื่อข้าม): " STREAM_KEY
if [ -n "${STREAM_KEY:-}" ]; then
  printf '%s' "$STREAM_KEY" | gh secret set YOUTUBE_STREAM_KEY --repo "$USER_NAME/$REPO_NAME"
  echo "✔ YOUTUBE_STREAM_KEY"
else
  echo "ข้าม (ไปใส่เองที่ Settings → Secrets → Actions)"
fi

read -r -p "วาง VIDEO_URL (ลิงก์ตรงไป mp4, เว้นว่างเพื่อข้าม): " VIDEO_URL
if [ -n "${VIDEO_URL:-}" ]; then
  printf '%s' "$VIDEO_URL" | gh secret set VIDEO_URL --repo "$USER_NAME/$REPO_NAME"
  echo "✔ VIDEO_URL"
fi

read -r -p "วาง DRIVE_FILE_ID ของไฟล์ mp4 (เว้นว่างเพื่อข้าม): " DRIVE_FILE_ID
if [ -n "${DRIVE_FILE_ID:-}" ]; then
  printf '%s' "$DRIVE_FILE_ID" | gh secret set DRIVE_FILE_ID --repo "$USER_NAME/$REPO_NAME"
  echo "✔ DRIVE_FILE_ID"
fi

say "4/4 เสร็จแล้ว"
cat <<EOF
repo    : https://github.com/$USER_NAME/$REPO_NAME
actions : https://github.com/$USER_NAME/$REPO_NAME/actions
 secrets: https://github.com/$USER_NAME/$REPO_NAME/settings/secrets/actions

เริ่มสตรีม:
  1. เปิด $USER_NAME/$REPO_NAME/actions
  2. เลือก workflow "24-7 YouTube live loop" → Run workflow
หรือใช้ CLI:
  gh workflow run live.yml --repo $USER_NAME/$REPO_NAME

⚠ เตือน: repo public = workflow ของคุณถูก fork ได้ (แต่ secret ไม่ติดไปด้วย)
   และ GitHub Actions ไม่ได้ออกแบบมาสำหรับสตรีมมีเดีย 24/7 — ใช้ทดสอบแล้วย้ายไป VPS
EOF
