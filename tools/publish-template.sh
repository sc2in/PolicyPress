#!/usr/bin/env bash
# Publish the tracked starter/ tree to the sc2in/policypress-template repository -
# the "Use this template" repo the docs point new users to. Regenerating it from
# starter/ on every release keeps the template from drifting from the toolchain
# (the pre-launch failure mode was a stale template shipping an insecure,
# public-by-default config that contradicted the docs).
#
# Auth: a GitHub token with write access to policypress-template - a fine-grained
# PAT (Contents: read and write) owned by the org, or a deploy token - provided as
# TEMPLATE_DEPLOY_KEY (wired from a repo secret by publish-template.yml). It is
# used over HTTPS via a per-command Authorization header, so the token is never
# written to .git/config or a remote URL. Refuses to run without it.
#
# Usage: TEMPLATE_DEPLOY_KEY=<token> bash tools/publish-template.sh [sync-ref]
set -euo pipefail

: "${TEMPLATE_DEPLOY_KEY:?TEMPLATE_DEPLOY_KEY is not set - provide a token with write access to sc2in/policypress-template}"
TEMPLATE_REPO="${TEMPLATE_REPO:-https://github.com/sc2in/policypress-template.git}"
SYNC_REF="${1:-manual}"

REPO="${PWD}"
[ -d "${REPO}/starter" ] || { echo "run from the repository root (starter/ not found)" >&2; exit 1; }

# HTTPS basic-auth header (token as the password) passed per git invocation via
# -c http.extraheader, so the token never lands in .git/config or a remote URL.
# tr -d '\n' keeps the base64 single-line across GNU/BSD base64. In CI, mask the
# encoded form too (Actions already masks the raw secret, not its base64).
AUTH_B64="$(printf 'x-access-token:%s' "${TEMPLATE_DEPLOY_KEY}" | base64 | tr -d '\n')"
[ -n "${GITHUB_ACTIONS:-}" ] && echo "::add-mask::${AUTH_B64}"
GIT_AUTH=(-c "http.extraheader=Authorization: Basic ${AUTH_B64}")

WORK="$(mktemp -d)"; trap 'rm -rf "${WORK}"' EXIT
CLONE="${WORK}/template"
git "${GIT_AUTH[@]}" clone "${TEMPLATE_REPO}" "${CLONE}"

# Mirror starter/ into the template, preserving the template's own .git. rsync
# --delete makes the template an exact copy of starter/: dropping a file from
# starter/ (a slimmed demo policy, say) removes it downstream too, so no orphaned
# content is ever left behind.
rsync -a --delete --exclude='.git/' "${REPO}/starter/" "${CLONE}/"

cd "${CLONE}"
git config user.name  "policypress-bot"
git config user.email "bot@sc2.in"
git add -A
if git diff --cached --quiet; then
  echo "✓ policypress-template already matches starter/ - nothing to publish"
  exit 0
fi
git commit -m "chore: sync starter from policypress ${SYNC_REF}"
git "${GIT_AUTH[@]}" push origin HEAD:main
echo "✓ published starter/ to policypress-template (${SYNC_REF})"
