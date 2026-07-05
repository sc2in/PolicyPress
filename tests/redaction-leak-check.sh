#!/usr/bin/env bash
# Redaction leak check (integration).
#
# Builds the demo site and the redacted PDFs, then asserts that content wrapped
# in {% redact() %} ... {% end %} never survives into any published artifact:
#   - the site HTML, client-side search index, and RSS/Atom/sitemap feeds
#     (with redact_web = true the shortcode must emit bars, never the text);
#   - the policypress output directory must contain PDFs only — no Markdown or
#     Typst work files.
#
# The PDF text layer is verified in the Zig test suite (the "typst source:
# redaction produces solid bars" golden test), which needs no external tools;
# if pdftotext is available here we additionally scan the rendered PDFs.
#
# Run from the repo root, inside the devshell:  bash tests/redaction-leak-check.sh
set -euo pipefail

cd "$(dirname "$0")/.."

fail=0
tmp_pdfs="$(mktemp -d)"
site_out="public"
trap 'rm -rf "$tmp_pdfs"' EXIT

# Sentinel strings that live inside {% redact() %} blocks in the demo content.
# Each MUST be absent from every published artifact.
sentinels=(
  "Customer data, financial records, trade secrets"
  "sensitive information that should not be disclosed"
)

echo "▸ Building site (zola build)…"
# The action copies theme shortcodes to the site root; mirror that so a
# standalone build resolves the redact shortcode.
mkdir -p templates/shortcodes
zola build >/dev/null

echo "▸ Scanning site output for redacted content…"
for s in "${sentinels[@]}"; do
  if grep -rqF "$s" "$site_out"; then
    echo "  ✗ LEAK: '$s' found in $site_out:"
    grep -rlF "$s" "$site_out" | sed 's/^/      /'
    fail=1
  else
    echo "  ✓ absent: '$s'"
  fi
done

# A rendered redaction bar must exist (proves the shortcode ran, not that the
# block was simply dropped).
if ! grep -rq 'class="redaction"' "$site_out"/policies; then
  echo "  ✗ no redaction bars rendered — is redact_web enabled and are there redact blocks?"
  fail=1
else
  echo "  ✓ redaction bars present in policy pages"
fi

echo "▸ Building redacted PDFs to a scratch dir…"
./zig-out/bin/policypress -c config.toml -o "$tmp_pdfs" --redact >/dev/null 2>&1 \
  || { echo "  ✗ policypress --redact failed"; exit 1; }

echo "▸ Checking the PDF output dir holds PDFs only (no work files)…"
# Ignore the internal incremental-build cache (.pp-stamps-*); it holds empty
# touch files, not content. The check targets accidental work-file output
# (stray .md source or .typ intermediates) alongside the PDFs.
strays="$(find "$tmp_pdfs" -type f ! -name '*.pdf' -not -path '*/.pp-stamps-*' 2>/dev/null || true)"
if [ -n "$strays" ]; then
  echo "  ✗ non-PDF work files written to the output dir:"
  echo "$strays" | sed 's/^/      /'
  fail=1
else
  echo "  ✓ only PDFs in the output dir"
fi

if command -v pdftotext >/dev/null 2>&1; then
  echo "▸ Scanning redacted PDFs' text layer…"
  for pdf in "$tmp_pdfs"/*.pdf; do
    [ -e "$pdf" ] || continue
    text="$(pdftotext "$pdf" - 2>/dev/null || true)"
    for s in "${sentinels[@]}"; do
      if printf '%s' "$text" | grep -qF "$s"; then
        echo "  ✗ LEAK: '$s' in $(basename "$pdf")"
        fail=1
      fi
    done
  done
  [ "$fail" -eq 0 ] && echo "  ✓ no sentinels in any redacted PDF"
else
  echo "▸ pdftotext not available — PDF text layer covered by the Zig golden test."
fi

if [ "$fail" -ne 0 ]; then
  echo "✗ redaction leak check FAILED"
  exit 1
fi
echo "✓ redaction leak check passed"
