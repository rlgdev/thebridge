#!/usr/bin/env bash
# Install the speckit-cobol-harness into a target repo. Usage: ./install.sh [/path/to/repo]
set -euo pipefail
TARGET="${1:-.}"
SRC="$(cd "$(dirname "$0")/payload" && pwd)"
mkdir -p "$TARGET/scripts" "$TARGET/eval/crs" "$TARGET/eval/runs"
cp "$SRC/scripts/extract_structure.py" "$SRC/scripts/fill_prose.py" "$TARGET/scripts/"
cp "$SRC/eval/cr-template.md" "$SRC/eval/rubric.md" "$TARGET/eval/"
if [ ! -f "$TARGET/eval/runsheet.csv" ]; then cp "$SRC/eval/runsheet.csv" "$TARGET/eval/"; fi
if [ -f "$TARGET/CLAUDE.md" ] && grep -q "^## COBOL context" "$TARGET/CLAUDE.md"; then
  echo "CLAUDE.md block already present - skipped"
else
  if [ -f "$TARGET/CLAUDE.md" ]; then printf '\n' >> "$TARGET/CLAUDE.md"; fi
  cat "$SRC/CLAUDE-block.md" >> "$TARGET/CLAUDE.md"
  echo "Appended COBOL context block to CLAUDE.md"
fi
echo "Installed harness into: $TARGET"
echo "Next: see README.md (generate context -> fill prose -> spec-kit init -> run CRs -> score)"
