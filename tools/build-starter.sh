#!/usr/bin/env bash
# Build the starter/ template through the full pipeline and assert it produces a
# working, private-by-default site + PDFs.
#
# This is the regression guard that keeps the theme and the shipped starter in
# lock-step. It reproduces exactly what the `sc2in/policypress` GitHub Action does
# for a user's repo: the tracked starter/ tree is the site, and this repo is the
# theme it pulls in at build time (templates/shortcodes, data files, and the draft
# watermark are copied into the site root, same as action.yml).
#
# Run in CI on every PR (via `nix run .#build-starter`) and locally the same way.
# A bare `bash tools/build-starter.sh` works too when zola, typst, and the
# policypress binary are already on PATH (e.g. inside `nix develop`).
set -euo pipefail

REPO="${PWD}"
[ -d "${REPO}/starter" ] || {
  echo "✗ run from the repository root (starter/ not found in ${REPO})" >&2
  exit 1
}

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
SITE="${WORK}/site"
mkdir -p "${SITE}"

# 1) What a template user actually has: the tracked starter/ tree. Strip any
#    local build outputs (the ones starter/.gitignore keeps out of git).
cp -r "${REPO}/starter/." "${SITE}/"
rm -rf "${SITE}/public" "${SITE}/static/pdfs"

# 2) What the Action injects at build time from the theme (this repo). Mirrors
#    the "Copy theme shortcodes / data files / draft watermark" steps in
#    action.yml, plus the theme checkout itself into themes/policypress.
mkdir -p "${SITE}/themes/policypress"
for item in templates static data sass config.toml theme.toml content; do
  cp -r "${REPO}/${item}" "${SITE}/themes/policypress/" 2>/dev/null || true
done
mkdir -p "${SITE}/templates/shortcodes" "${SITE}/data" "${SITE}/static"
cp -n "${REPO}"/templates/shortcodes/*.html "${SITE}/templates/shortcodes/" 2>/dev/null || true
cp -n "${REPO}"/data/* "${SITE}/data/" 2>/dev/null || true
cp -n "${REPO}"/static/draft.png "${SITE}/static/" 2>/dev/null || true

cd "${SITE}"

echo "▸ stage-site"
SITE_ROOT="$(policypress stage-site -c config.toml -o "${WORK}/stage")"
echo "▸ zola build (root: ${SITE_ROOT})"
zola --root "${SITE_ROOT}" build --output-dir "${SITE}/public" --force
echo "▸ render-diagrams"
policypress render-diagrams public
echo "▸ PDFs"
policypress -c config.toml -o public/pdfs --no-draft

# 3) Assert the site + PDFs exist and the private-by-default posture holds. These
#    are exactly the things that broke silently before: an unguarded theme
#    reference (policyteam / news) fails the site build, and a config drift would
#    drop the noindex/robots protection.
fail() { echo "✗ starter build check FAILED: $*" >&2; exit 1; }
[ -f public/index.html ]                          || fail "no homepage (public/index.html)"
[ -f public/policies/access-control/index.html ]  || fail "policy pages did not render"
[ -f public/search_index.en.json ]                || fail "no search index"
ls public/pdfs/*.pdf >/dev/null 2>&1              || fail "no PDFs generated"
grep -q "Disallow: /" public/robots.txt 2>/dev/null \
  || fail "robots.txt is not private (expected 'Disallow: /' — private-by-default lost)"
grep -q 'name="robots" content="noindex' public/policies/access-control/index.html \
  || fail "policy pages are not noindex (private=true not applied)"

echo "✓ starter builds clean: $(ls public/pdfs/*.pdf | wc -l) PDFs, private-by-default posture verified"
