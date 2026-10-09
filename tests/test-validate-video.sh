#!/usr/bin/env bash
# Tests for skills/demo-video/validate-video.sh using synthetic ffmpeg videos.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATE="$ROOT/skills/demo-video/validate-video.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
failures=0

# Build an mp4 from "color:seconds" segments, e.g. segments out.mp4 black:2 white:2
segments() {
  local out="$1"; shift
  local inputs=() filter="" i=0
  for seg in "$@"; do
    inputs+=(-f lavfi -i "color=c=${seg%%:*}:s=320x200:d=${seg##*:}:r=10")
    filter+="[$i:v]"; i=$((i+1))
  done
  ffmpeg -nostdin -v error -y "${inputs[@]}" \
    -filter_complex "${filter}concat=n=$i:v=1:a=0" -pix_fmt yuv420p "$out"
}

expect() {
  local want="$1" name="$2" video="$3"
  bash "$VALIDATE" "$video" >"$TMP/$name.log" 2>&1
  local got=$?
  if [ "$got" -eq "$want" ]; then
    echo "ok   - $name (exit $got)"
  else
    echo "FAIL - $name: expected exit $want, got $got"; cat "$TMP/$name.log"
    failures=$((failures+1))
  fi
}

segments "$TMP/static.mp4" gray:10
expect 1 "static video fails" "$TMP/static.mp4"

segments "$TMP/chapters.mp4" black:2 white:2 red:2 blue:2 yellow:2 green:2
expect 0 "multi-chapter video passes" "$TMP/chapters.mp4"

segments "$TMP/dominant.mp4" gray:20 black:1 white:1 red:1 blue:1 yellow:1
expect 1 "one screen dominating fails" "$TMP/dominant.mp4"

segments "$TMP/short.mp4" black:1
expect 1 "too-short video fails" "$TMP/short.mp4"

[ "$failures" -eq 0 ] && echo "all tests passed" || { echo "$failures test(s) failed"; exit 1; }
