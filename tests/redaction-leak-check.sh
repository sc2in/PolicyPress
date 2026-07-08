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
tmp_content=""      # populated by the raw-HTML divergence check below
tmp_html_out=""
site_out="public"
trap 'rm -rf "$tmp_pdfs" "$tmp_content" "$tmp_html_out"' EXIT

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

echo "▸ Rendering mermaid diagrams to inline SVG (render-diagrams)…"
./zig-out/bin/policypress render-diagrams "$site_out" >/dev/null 2>&1 \
  || { echo "  ✗ render-diagrams failed"; exit 1; }

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

echo "▸ Checking mermaid diagrams became inline SVG (no client-side bundle)…"
if grep -rq '<pre class="mermaid">' "$site_out"; then
  echo "  ✗ unrendered <pre class=\"mermaid\"> left in the site:"
  grep -rlF '<pre class="mermaid">' "$site_out" | sed 's/^/      /'
  fail=1
else
  echo "  ✓ no unrendered mermaid placeholders"
fi
if ! grep -rq 'class="mermaid-diagram"' "$site_out"; then
  echo "  ✗ no inline mermaid SVG found — did render-diagrams run?"
  fail=1
else
  echo "  ✓ inline mermaid SVG present"
fi
if grep -rqE 'mermaid\.min|plugins/mermaid' "$site_out"; then
  echo "  ✗ site still references a client-side mermaid bundle:"
  grep -rlE 'mermaid\.min|plugins/mermaid' "$site_out" | sed 's/^/      /'
  fail=1
else
  echo "  ✓ no client-side mermaid bundle referenced"
fi

echo "▸ Building redacted PDFs to a scratch dir…"
./zig-out/bin/policypress -c config.toml -o "$tmp_pdfs" --redact >/dev/null 2>&1 \
  || { echo "  ✗ policypress --redact failed"; exit 1; }

echo "▸ Checking stale PDFs are swept on rebuild…"
# A PDF that matches no current policy (e.g. from a renamed/deleted source) must
# be removed on the next build so it can't linger at a guessable URL.
touch "$tmp_pdfs/ZZZ_Stale_Removed_Policy_-_v9.9.pdf"
./zig-out/bin/policypress -c config.toml -o "$tmp_pdfs" --redact >/dev/null 2>&1 \
  || { echo "  ✗ rebuild failed"; exit 1; }
if [ -e "$tmp_pdfs/ZZZ_Stale_Removed_Policy_-_v9.9.pdf" ]; then
  echo "  ✗ stale PDF was not removed on rebuild"
  fail=1
else
  echo "  ✓ stale PDF removed on rebuild"
fi

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

echo "▸ Checking raw-HTML divergence pre-flight (#117)…"
# Raw/inline HTML renders on the Zola site but the Typst/PDF path silently
# drops it, so the two artifacts would diverge. The build pre-flight must warn
# by default and fail under --strict. Uses -i to re-root onto a fixture policy
# dir (policy_dir = "policies/" per config.toml) so the demo content is untouched.
tmp_content="$(mktemp -d)"
tmp_html_out="$(mktemp -d)"
mkdir -p "$tmp_content/policies"
cat > "$tmp_content/policies/html-divergence-fixture.md" <<'EOF'
---
title: "HTML Divergence Fixture"
description: "Raw HTML that the site would render but PDFs would drop"
extra:
  last_reviewed: "2026-01-01"
  major_revisions:
    - date: "2026-01-01"
      description: Initial.
      revised_by: Test
      approved_by: Test
      version: "1.0"
---
Before.

<div class="tab-group">site-only markup</div>

After.
EOF

# Default: warn about the raw HTML but still build (exit 0).
out="$(./zig-out/bin/policypress -c config.toml -i "$tmp_content" -o "$tmp_html_out" 2>&1)" \
  || { echo "  ✗ non-strict build failed on the raw-HTML fixture"; fail=1; }
if grep -q "raw HTML" <<<"$out"; then
  echo "  ✓ raw HTML warned by default"
else
  echo "  ✗ no raw-HTML warning emitted:"; sed 's/^/      /' <<<"$out"; fail=1
fi

# --strict: must abort with a non-zero exit.
if ./zig-out/bin/policypress -c config.toml -i "$tmp_content" -o "$tmp_html_out" --strict >/dev/null 2>&1; then
  echo "  ✗ --strict did not fail on raw HTML"; fail=1
else
  echo "  ✓ --strict fails on raw HTML"
fi

# Regression guard: the real demo content must stay warning-free under --strict
# (e.g. email autolinks like <security-team@…> must not be misclassified).
demo_strict=""
if ! demo_strict="$(./zig-out/bin/policypress -c config.toml -o "$tmp_html_out" --strict 2>&1)"; then
  echo "  ✗ demo policies failed the --strict build:"; sed 's/^/      /' <<<"$demo_strict"; fail=1
elif grep -q "raw HTML" <<<"$demo_strict"; then
  echo "  ✗ demo policies tripped the raw-HTML rule under --strict:"
  grep "raw HTML" <<<"$demo_strict" | sed 's/^/      /'; fail=1
else
  echo "  ✓ demo policies pass --strict (no raw-HTML false positives)"
fi

if [ "$fail" -ne 0 ]; then
  echo "✗ redaction leak check FAILED"
  exit 1
fi
echo "✓ redaction leak check passed"
