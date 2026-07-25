#!/usr/bin/env bash
# Publish the tracked starter/ tree to the sc2in/policypress-template repository -
# the "Use this template" repo the docs point new users to. Regenerating it from
# starter/ on every release is what keeps the template from drifting away from
# the toolchain (the pre-launch failure mode was a stale template shipping an
# insecure, public-by-default config that contradicted the docs).
#
# Requires a deploy key with write access to policypress-template, provided as
# the TEMPLATE_DEPLOY_KEY environment variable (wired from a repo secret by
# publish-template.yml). Refuses to run without it.
#
# Usage: TEMPLATE_DEPLOY_KEY=... bash tools/publish-template.sh [sync-ref]
set -euo pipefail

: "${TEMPLATE_DEPLOY_KEY:?TEMPLATE_DEPLOY_KEY is not set - provide a deploy key with write access to sc2in/policypress-template}"
TEMPLATE_REPO="${TEMPLATE_REPO:-git@github.com:sc2in/policypress-template.git}"
SYNC_REF="${1:-manual}"

REPO="${PWD}"
[ -d "${REPO}/starter" ] || { echo "run from the repository root (starter/ not found)" >&2; exit 1; }

# Isolated SSH setup: write the deploy key to a temp file and point git at it,
# so we never read or modify the runner's default SSH config.
WORK="$(mktemp -d)"; trap 'rm -rf "${WORK}"' EXIT
KEY="${WORK}/deploy_key"
printf '%s\n' "${TEMPLATE_DEPLOY_KEY}" > "${KEY}"
chmod 600 "${KEY}"
export GIT_SSH_COMMAND="ssh -i ${KEY} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"

CLONE="${WORK}/template"
git clone "${TEMPLATE_REPO}" "${CLONE}"

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
git push origin HEAD:main
echo "✓ published starter/ to policypress-template (${SYNC_REF})"
