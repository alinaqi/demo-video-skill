#!/usr/bin/env bash
# validate-video.sh — prove a demo video actually CHANGES, not just renders.
#
# Catches the classic failure where every "chapter" looks the same (e.g. a modal
# whose top is identical each time) so the caption changes but the screen does
# not — the video looks like one frozen screen.
#
# Usage: validate-video.sh <video.mp4> [sample_fps] [max_ssim]
#   sample_fps : frames sampled per second for the scan (default 1)
#   max_ssim   : two consecutive distinct holds scoring ABOVE this are "the same
#                screen" (default 0.985; 1.0 == identical)
#
# Exit 0 = healthy (enough visually-distinct content). Exit 1 = too static.
set -euo pipefail

VID="${1:?usage: validate-video.sh <video.mp4> [sample_fps] [max_ssim]}"
FPS="${2:-1}"
MAX_SSIM="${3:-0.985}"

DIR="$(mktemp -d)"
trap 'rm -rf "$DIR"' EXIT
ffmpeg -nostdin -v error -y -i "$VID" -vf "fps=${FPS},scale=640:-1" "$DIR/f_%04d.png"

frames=("$DIR"/f_*.png)
n=${#frames[@]}
if [ "$n" -lt 3 ]; then echo "too few frames ($n) to judge"; exit 1; fi

transitions=0   # consecutive sampled frames that differ (motion / new screen)
run=1; maxrun=1  # longest run of near-identical frames (a frozen stretch)
echo "scanning $n sampled frames (fps=$FPS)…"
for ((k=1;k<n;k++)); do
  # NB: do NOT pass -v error here — the SSIM summary line is logged at info level
  # and -v error would hide it, making every pair look identical.
  s=$(ffmpeg -nostdin -i "${frames[k-1]}" -i "${frames[k]}" \
        -lavfi ssim -f null - 2>&1 | sed -n 's/.*All:\([0-9.]*\).*/\1/p' | tail -1)
  [ -z "$s" ] && s=1
  if awk "BEGIN{exit !($s < $MAX_SSIM)}"; then
    transitions=$((transitions+1)); run=1
  else
    run=$((run+1)); [ "$run" -gt "$maxrun" ] && maxrun=$run
  fi
done

dur=$(ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 "$VID")
echo "duration=${dur}s  transitions=${transitions}  longest_static_run=${maxrun} frames (~${maxrun}s at ${FPS}fps)"

# Heuristics: a real multi-chapter walkthrough shows several screen changes and
# never sits on one identical frame for most of its length.
min_transitions=4
if [ "$transitions" -lt "$min_transitions" ]; then
  echo "FAIL: only ${transitions} screen change(s) (need >= ${min_transitions}). The video looks static/repetitive."
  exit 1
fi
# longest_static_run as a share of the whole scan
if awk "BEGIN{exit !($maxrun > 0.6*$n)}"; then
  echo "FAIL: one screen fills >60% of the video (frozen for ~${maxrun}s). Vary the shot per chapter."
  exit 1
fi
echo "PASS: video changes across chapters."
