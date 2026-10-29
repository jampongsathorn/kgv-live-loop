# 24/7 looping live stream on YouTube — built with GitHub

Two things you can do, and the honest limits of each.

---

## 0. First, the reality check (read this before you spend time)

"Host a 24/7 loop on YouTube using GitHub" = you need something that never stops pushing a video to YouTube's RTMP server. GitHub is the free place people use for that. It works, but with four catches:

| Catch | Detail | Workaround |
|---|---|---|
| **6-hour job cap** | Any job on a GitHub-hosted runner is cancelled after 6 h. There is no way around it. | Cron every 6 h + a script that exits cleanly at 5 h 45 m so the next job takes over. Viewers see a ~30–120 s reconnect gap each time. |
| **Cron is not a clock** | Scheduled runs start late (often 1–15 min) and can be skipped at peak times. Also, GitHub **disables scheduled workflows after 60 days of repo inactivity**. | Push a commit / hit "Run workflow" every few weeks to keep it alive. |
| **GitHub's usage rules** | Actions is meant for "the production, testing, deployment, or publication of the software project". Long-running media streaming is not that. Repos have been suspended for it. | Use a private-ish, low-key repo at your own risk — or better, run it on a tiny VPS (see §5). This is the real answer for 24/7. |
| **Free minutes** | Public repos = unlimited minutes on standard runners. Private repos = 2,000 min/month on Free, then billed. 24/7 burns ~720 h/month, so a private repo costs money fast. | Keep the repo **public** but never put the stream key in a file — only in repo Secrets. |

Also on the YouTube side, before anything works:

- Verify your channel with a phone number at `youtube.com/verify`, enable live streaming in YouTube Studio, then **wait 24 hours** (one time only).
- No Community Guidelines strikes in the last 90 days.
- A 24/7 loop is fine technically, but **looping other people's videos = copyright strikes and demonetisation**. Use your own footage, art, or licensed music, and read YouTube's "reused content" policy if you want to monetise.

---

## 1. The two architectures

**A. GitHub Actions (free, fragile, restart-gap every 6 h)** — what the files in `yt-live-loop/` do.

**B. Always-on machine** (Oracle Cloud Always Free VM, old laptop, Raspberry Pi 4, self-hosted GitHub runner) — one `ffmpeg` process for months, no gaps. Same `stream.sh`, run it under `systemd` or `tmux`. This is what people actually use for money-making lo-fi channels.

Try A first to learn, move to B when you care about uptime.

---

## 2. YouTube side: get the stream key (5 min)

1. YouTube Studio → **Create → Go live → Stream** (not "Webcam").
2. Title, thumbnail, category, **set visibility Public/Unlisted**.
3. Latency: **Normal** (low-latency adds instability on 24/7 loops). Turn DVR on.
4. Copy **Stream key** (`xxxx-xxxx-xxxx-xxxx`) and the **Stream URL** `rtmp://a.rtmp.youtube.com/live2`.
5. Open **Stream settings → Auto-start / Auto-stop** and enable it. With auto-start on, your channel goes live whenever the encoder connects — exactly what you want for a loop that restarts every 6 h.
6. Treat the key like a password. Anyone with it can broadcast to your channel. If it leaks, click **Reset**.

---

## 3. GitHub side: 10-minute setup

```bash
# 1. Create an empty public repo on github.com (e.g. "live-loop"), then:
cd yt-live-loop
git init && git add . && git commit -m "24/7 loop"
git branch -M main
git remote add origin https://github.com/YOURNAME/live-loop.git
git push -u origin main
```

```bash
# 2. Add the video. Keep it under 100 MB per file or use a release asset / Drive link.
cp /path/to/your-loop.mp4 ./loop.mp4
git add loop.mp4 && git commit -m "video" && git push
```

**Add your secrets** → repo **Settings → Secrets and variables → Actions → New repository secret**:

| Name | Value |
|---|---|
| `YOUTUBE_STREAM_KEY` | the key from YouTube Studio |
| `VIDEO_URL` *(optional)* | a direct HTTP link to the mp4 (Google Drive `uc?export=download&id=…`, a GitHub release asset, S3/R2 public URL). If set, it downloads instead of using the committed file. |

**Start it** → **Actions** tab → `24-7 YouTube live loop` → **Run workflow**. Within ~60 s YouTube Studio should show "Stream is live" and auto-start the broadcast.

That's it. It will now relaunch itself every 6 hours and keep looping.

### What's in the scaffold

| File | Job |
|---|---|
| `.github/workflows/live.yml` | Installs ffmpeg, fetches the video, runs `stream.sh` for up to 5 h 45 m, cron-chained every 6 h |
| `stream.sh` | Infinite `ffmpeg -re -stream_loop -1` loop with reconnect-on-crash and a clean exit before the 6 h cap |

Tuning knobs (env vars in the workflow): `V_BITRATE` (4500k ≈ 1080p30, 2500k ≈ 720p), `A_BITRATE` (use 192k for music), `MAX_SECONDS`.

Requirement reminder: H.264 + AAC, **keyframe every 2 s** (`-g 60` at 30 fps), FLV over RTMP, stereo AAC ≥128 kbps. Miss the keyframe rule and YouTube throttles or drops you.

### Adding a playlist instead of one file
Loop files in order — replace the single `-i` with a concat list:

```bash
printf "file '%s'\n" /path/videos/*.mp4 > list.txt
ffmpeg -re -f concat -safe 0 -stream_loop -1 -i list.txt -c:v libx264 ... -f flv "$RTMP_URL/$STREAM_KEY"
```

### Cheapest CPU win: pre-encode once, then copy
Encoding on a 2-core runner is the usual cause of frame drops. Encode the file locally to exactly YouTube's spec (H.264 High, yuv420p, `keyint=60`, CBR) and then stream with `-c:v copy -c:a copy` — near-zero CPU:

```bash
ffmpeg -re -stream_loop -1 -i loop.mp4 -c:v copy -c:a copy -f flv "$RTMP_URL/$STREAM_KEY"
```

---

## 4. If you'd rather copy someone else's repo (GitHub search)

Search queries that surface working examples:

- `github.com/search?q=stream_loop+-1+rtmp+youtube+live+path%3A.github%2Fworkflows&type=code`
- `github.com/search?q=24%2F7+youtube+live+stream+ffmpeg&type=repositories&s=stars`
- `github topics: "youtube-live" "ffmpeg"`

Known starting points (read before trusting):

- `mohdwashi976-stack/Youtube-Live` — minimal workflow, infinite `while true` ffmpeg loop. Note its RTMP URL is malformed; fix to `rtmp://a.rtmp.youtube.com/live2/${KEY}`.
- `Gopu09934/flight-tracker` — headless Chromium → ffmpeg → RTMP, chained every 6 h, with notes on hitting the 6 h cap. Good reference for the cron-chaining trick.
- `anishbhattarai-asm/247yt` — self-hosted (VPS) version with a web panel, playlist mode, auto-reconnect. Use this if you go route B.

**How to vet any of them:**
1. Read `.github/workflows/*.yml` line by line. A repo can exfiltrate secrets by curling your env to an unknown host — never add secrets to a workflow you haven't read.
2. Never hard-code the stream key. Fork → fix → put the key in Secrets only.
3. Check commits and stars/forks; many of these repos are dead or written by people who never got it stable.
4. First test with visibility **Unlisted** and a short 2-minute video.

---

## 5. The reliable path (recommended for real 24/7)

Oracle Cloud **Always Free** ARM VM (4 cores / 24 GB RAM, free forever) is the standard free host for this:

```bash
sudo apt update && sudo apt install -y ffmpeg
mkdir -p ~/stream && cd ~/stream     # put stream.sh + loop.mp4 here
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
journalctl -u youtube-loop -f      # watch it
```

Bandwidth needed: ~4.5 Mbps up, sustained, ~1.5 TB/month. Watch your host's egress cap. Free-tier hosts that **sleep** (Render free, Fly.io scale-to-zero, Replit) will kill a stream — don't use them.

GitHub-only alternative: register your own machine as a **self-hosted runner** — that raises the job cap to 5 days and costs no Actions minutes. Middle ground between A and B.

---

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Job green, but YouTube says "No data" | Wrong RTMP URL or key | URL must be `rtmp://a.rtmp.youtube.com/live2/<KEY>`; no trailing slash, no `https` |
| "Stream key is invalid" | Key pasted with spaces, or a "persistent" key was reset | Re-copy from Studio → Stream settings |
| Bufferbloat / "poor connection" warnings | Runner CPU maxed by encoding | Pre-encode + `-c:v copy`; drop to 720p/2500k |
| Stream dies every 6 h and doesn't come back | Cron delayed or workflow disabled (60 days inactivity) | Check Actions tab; push a commit; or move to a VPS |
| Black screen, audio only | `-pix_fmt yuv420p` missing | Keep the flag in `stream.sh` |
| Audio out of sync after loop wraps | Source file has odd audio length | Re-encode to a single clean file with `-video_track_timescale` fix, or concat playlist |
| YouTube mutes / strikes you | Copyrighted music or footage in the loop | Use licensed/own content |
| ffmpeg exits instantly, log shows "Input/output error" | Key was reset or another encoder is connected | Reset key, update secret, or stop the other encoder |

---

## TL;DR

1. YouTube Studio → Go live → Stream → copy key, enable auto-start.
2. Push this repo with `loop.mp4` + secret `YOUTUBE_STREAM_KEY`.
3. Actions → Run workflow. It self-relaunches every 6 h.
4. When you get tired of the 6-hour reconnect gaps, move the same `stream.sh` to a free Oracle VM under systemd and it runs for months.
