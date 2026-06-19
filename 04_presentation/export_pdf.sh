#!/bin/bash
# Export the reveal.js deck to PDF exactly as it looks on screen (logo, progress
# indicator, scaled content) using decktape — NOT reveal's ?print-pdf reflow.
# Requires: node/npx + Google Chrome. Run from anywhere.
set -e
cd "$(dirname "$0")"
PUPPETEER_SKIP_DOWNLOAD=1 npx -y decktape@latest reveal \
  --chrome-path "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --chrome-arg=--no-sandbox -s 1280x720 --pause 700 \
  "file://$(pwd)/presentation.html" presentation.pdf
echo "Wrote presentation.pdf"
