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
tmp_audit_out=""    # populated by the audit-bundle check below
site_stage=""       # populated by the site staging step (#173) below
tmp_cf=""           # populated by the control-footnotes strictness leg below
tmp_sub=""          # populated by the base_url sub-path leg below
site_out="public"
trap 'rm -rf "$tmp_pdfs" "$tmp_content" "$tmp_html_out" "$tmp_audit_out" "$site_stage" "$tmp_cf" "$tmp_sub"' EXIT

# Sentinel strings that live inside {% redact() %} blocks in the demo content.
# Each MUST be absent from every published artifact.
sentinels=(
  "Customer data, financial records, trade secrets"
  "sensitive information that should not be disclosed"
)

echo "▸ Staging site root + building (stage-site → zola --root)…"
# The action copies theme shortcodes to the site root; mirror that so a
# standalone build resolves the redact shortcode.
mkdir -p templates/shortcodes
# Mirror the action's build exactly: stage-site synthesises [^CONTROL-ID]
# footnote definitions into a disposable copy when control_footnotes is enabled
# (#173), then zola builds from that root. With the flag off it prints "." and
# this degenerates to a plain in-place build. Capturing the printed root keeps
# both cases correct.
site_stage="$(mktemp -d)"
site_root="$(./zig-out/bin/policypress stage-site -c config.toml -o "$site_stage")"
zola --root "$site_root" build --output-dir "$site_out" --force >/dev/null

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

echo "▸ Checking native control footnotes (#173)…"
# The demo enables control_footnotes and example-security-policy.md uses a native
# [^IAC-01] reference. Assert stage-site is append-only (never modifies the
# authored tree) and that the synthesised definition renders on the web.
if [ "$site_root" != "." ]; then
  staged_policy="$site_root/content/policies/example-security-policy.md"
  # 1. The staged copy carries an appended, catalog-derived definition.
  if grep -qE '^\[\^IAC-01\]: \[IAC-01\]\(/reports/scf/#IAC-01\)' "$staged_policy"; then
    echo "  ✓ synthesised [^IAC-01] definition appended to the staged policy"
  else
    echo "  ✗ no synthesised [^IAC-01] definition in the staged policy"; fail=1
  fi
  # 2. The authored source is untouched — no definition line leaked into content/.
  if grep -qE '^\[\^IAC-01\]: ' content/policies/example-security-policy.md; then
    echo "  ✗ authored content/ was modified by stage-site"; fail=1
  else
    echo "  ✓ authored content/ untouched by staging (append-only)"
  fi
  # 3. The definition renders on the web as a bottom-of-page footnote linking to
  #    the report-page anchor (the <li id="fn-IAC-01"> is Zola's def anchor).
  policy_html="$site_out/policies/example-security-policy/index.html"
  if grep -q 'id="fn-IAC-01"' "$policy_html" && grep -qF 'href="/reports/scf/#IAC-01"' "$policy_html"; then
    echo "  ✓ native footnote renders on the web with its report-page link"
  else
    echo "  ✗ native footnote did not render on the web"; fail=1
  fi
else
  echo "  … control_footnotes disabled; skipping native-footnote checks"
fi

echo "▸ Checking base_url sub-path prefixing of footnote links (#173)…"
# Under a sub-path deployment, a synthesised link must carry the base_url path
# component (Zola does not add it to plain absolute Markdown links). stage-site
# takes --base-url (the same value the action passes to `zola build`) for this.
if [ "$site_root" != "." ]; then
  tmp_sub="$(mktemp -d)"
  ./zig-out/bin/policypress stage-site -c config.toml -o "$tmp_sub" --base-url "https://example.com/sub" >/dev/null
  if grep -qF '[^IAC-01]: [IAC-01](/sub/reports/scf/#IAC-01)' "$tmp_sub/content/policies/example-security-policy.md"; then
    echo "  ✓ synthesised link carries the base_url sub-path (/sub)"
  else
    echo "  ✗ synthesised link missing the base_url sub-path prefix"; fail=1
  fi
else
  echo "  … control_footnotes disabled; skipping sub-path check"
fi

echo "▸ Building redacted PDFs to a scratch dir…"
# --no-audit-bundle: the demo config enables the audit bundle, but this leg
# checks that the PDF output dir holds PDFs only (below); the bundle is
# generated and scanned in its own leg further down.
./zig-out/bin/policypress -c config.toml -o "$tmp_pdfs" --redact --no-audit-bundle >/dev/null 2>&1 \
  || { echo "  ✗ policypress --redact failed"; exit 1; }

echo "▸ Checking stale PDFs are swept on rebuild…"
# A PDF that matches no current policy (e.g. from a renamed/deleted source) must
# be removed on the next build so it can't linger at a guessable URL.
touch "$tmp_pdfs/ZZZ_Stale_Removed_Policy_-_v9.9.pdf"
./zig-out/bin/policypress -c config.toml -o "$tmp_pdfs" --redact --no-audit-bundle >/dev/null 2>&1 \
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

echo "▸ Building the audit bundle (redacted) and scanning it…"
# Revision descriptions and titles flow into the bundle; prove nothing
# redacted leaks there, and that all four files exist and look structured.
tmp_audit_out="$(mktemp -d)"
./zig-out/bin/policypress -c config.toml -o "$tmp_audit_out/pdfs" --redact --audit-bundle >/dev/null 2>&1 \
  || { echo "  ✗ policypress --redact --audit-bundle failed"; exit 1; }
for f in manifest.json revisions.json coverage.json coverage.csv; do
  if [ ! -s "$tmp_audit_out/audit/$f" ]; then
    echo "  ✗ audit bundle file missing or empty: $f"
    fail=1
  fi
done
if ! grep -q '"schema": "policypress/audit-manifest/v1"' "$tmp_audit_out/audit/manifest.json" 2>/dev/null; then
  echo "  ✗ manifest.json lacks its schema marker"
  fail=1
fi
if ! grep -q '"pdf_sha256"' "$tmp_audit_out/audit/manifest.json" 2>/dev/null; then
  echo "  ✗ manifest.json lacks PDF hashes"
  fail=1
fi
audit_leak=0
for s in "${sentinels[@]}"; do
  if grep -rqF "$s" "$tmp_audit_out/audit"; then
    echo "  ✗ LEAK: '$s' found in the audit bundle"
    fail=1
    audit_leak=1
  fi
done
[ "$audit_leak" -eq 0 ] && echo "  ✓ audit bundle present, structured, no sentinels"

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

echo "▸ Checking the control-footnote strictness matrix (#173)…"
# A native [^CONTROL-ID] reference is a --strict error only when control_footnotes
# is off; when on, a KNOWN id is accepted but an UNKNOWN (well-formed) id is still
# critical (typo detection). Re-root onto fixtures with -i so the demo is untouched.
tmp_cf="$(mktemp -d)"
mkdir -p "$tmp_cf/ok/policies" "$tmp_cf/bad/policies" "$tmp_cf/out"
fixture_fm() {
  cat <<EOF
---
title: "$1"
description: "Native control footnote fixture"
extra:
  last_reviewed: "2026-01-01"
  major_revisions:
    - date: "2026-01-01"
      description: Initial.
      revised_by: Test
      approved_by: Test
      version: "1.0"
---
Access is least-privilege $2 enforced.
EOF
}
fixture_fm "Known Native Ref" '[^IAC-01]' > "$tmp_cf/ok/policies/ok.md"
fixture_fm "Unknown Native Ref" '[^ZZZ-99]' > "$tmp_cf/bad/policies/bad.md"
# A copy of the demo config with the flag forced off.
sed 's/^control_footnotes = true/control_footnotes = false/' config.toml > "$tmp_cf/config-off.toml"

# Flag OFF: a native ref (even a known id) must fail --strict.
if ./zig-out/bin/policypress -c "$tmp_cf/config-off.toml" -i "$tmp_cf/ok" -o "$tmp_cf/out" --strict >/dev/null 2>&1; then
  echo "  ✗ --strict passed a native [^IAC-01] with control_footnotes off"; fail=1
else
  echo "  ✓ --strict fails a native ref when control_footnotes is off"
fi
# Flag ON: a known id passes --strict.
if ./zig-out/bin/policypress -c config.toml -i "$tmp_cf/ok" -o "$tmp_cf/out" --strict >/dev/null 2>&1; then
  echo "  ✓ --strict passes a known native [^IAC-01] when control_footnotes is on"
else
  echo "  ✗ --strict wrongly failed a known native ref with control_footnotes on"; fail=1
fi
# Flag ON: an unknown well-formed id is still critical.
if ./zig-out/bin/policypress -c config.toml -i "$tmp_cf/bad" -o "$tmp_cf/out" --strict >/dev/null 2>&1; then
  echo "  ✗ --strict passed an unknown native [^ZZZ-99] with control_footnotes on"; fail=1
else
  echo "  ✓ --strict still fails an unknown native id when control_footnotes is on"
fi

if [ "$fail" -ne 0 ]; then
  echo "✗ redaction leak check FAILED"
  exit 1
fi
echo "✓ redaction leak check passed"
