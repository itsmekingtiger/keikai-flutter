#!/usr/bin/env bash
# Assembles PNG frames written by captureKkFrames into an animated WebP.
# Usage: tool/assemble_frames.sh <frames-dir> <out.webp> [fps] [quality]
set -euo pipefail
frames="$1"; out="$2"; fps="${3:-25}"; quality="${4:-82}"
ffmpeg -hide_banner -loglevel error -y -framerate "$fps" -i "$frames/%04d.png" \
  -loop 0 -c:v libwebp_anim -lossless 0 -q:v "$quality" -compression_level 6 "$out"
