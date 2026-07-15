#!/usr/bin/env bash
# Web accessibility scan: build + serve the site, then run axe-core (vendored,
# MIT) against a representative page of every template in light and dark mode.
# Fails on any WCAG A/AA violation. Uses Chromium + Node from nixpkgs (no npm).
#
# Run from the repo root, inside the devshell:  bash tests/a11y/scan.sh
set -euo pipefail

cd "$(dirname "$0")/../.."
here="tests/a11y"
port=1219
profile="$(mktemp -d)"
zola_pid=""
chrome_pid=""
cleanup() {
  [ -n "$zola_pid" ] && kill "$zola_pid" 2>/dev/null || true
  [ -n "$chrome_pid" ] && kill "$chrome_pid" 2>/dev/null || true
  rm -rf "$profile"
}
trap cleanup EXIT

# The action copies theme shortcodes to the site root; mirror that so a
# standalone build resolves the redact/mermaid shortcodes.
mkdir -p templates/shortcodes

echo "▸ Serving the site (zola serve)…"
zola serve --interface 127.0.0.1 --port "$port" >/tmp/a11y-zola.log 2>&1 &
zola_pid=$!

echo "▸ Launching headless Chromium…"
chromium --headless=new --remote-debugging-port=9222 --no-sandbox \
  --disable-gpu --disable-dev-shm-usage --hide-scrollbars \
  --user-data-dir="$profile" about:blank >/tmp/a11y-chrome.log 2>&1 &
chrome_pid=$!

echo "▸ Waiting for both to come up…"
ready=""
for _ in $(seq 1 90); do
  if curl -s "http://127.0.0.1:9222/json/version" >/dev/null 2>&1 \
     && curl -s "http://127.0.0.1:$port/" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
if [ -z "$ready" ]; then
  echo "✗ Chromium (:9222) and/or zola (:$port) did not come up in time." >&2
  echo "  zola log:" >&2; tail -5 /tmp/a11y-zola.log >&2 || true
  exit 1
fi

echo "▸ Running axe-core…"
node "$here/run-axe.mjs" "http://127.0.0.1:$port"
