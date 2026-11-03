#!/usr/bin/env bash
# Make English placeholder clips N01–N21 for development only (research R10).
# The real clips are recorded by a partner-approved Swahili voice and replace these (tasks T097).
#
# Usage: tools/make_placeholder_narration.sh   (from the repository root, macOS only)
set -euo pipefail

script="docs/narration/script.en.md"
out="ios/CleanHands/Resources/Narration"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$out"

grep -E '^\| N[0-9]{2} \|' "$script" | while IFS='|' read -r _ clip _ text _; do
  clip="$(echo "$clip" | xargs)"
  text="$(echo "$text" | sed -e 's/^ *//' -e 's/ *$//')"
  say -o "$tmp/$clip.aiff" "$text"
  afconvert -f m4af -d aac "$tmp/$clip.aiff" "$out/$clip.m4a"
  echo "$clip"
done
