#!/usr/bin/env bash
# GitHub Marketplace metadata guards for action.yml, runnable locally
# (`bash tools/check-action-metadata.sh`) and as the `action-metadata` flake
# check on every PR.
#
# Why this exists: GitHub validates this metadata only when a release is
# published to the Marketplace, in the release UI. Nothing in `zola check`, the
# formatter, the test suite, or the release guards looks at it. So an invalid
# value merges green, releases green, and the only symptom is the Marketplace
# listing going 404 — which is exactly how v1.7.2 delisted the action: the
# `description` had grown to 133 characters against a 125-character cap, and the
# failure surfaced only as "Your action.yml needs changes before it can be
# published" in the UI, after the tag was already immutable.
#
# Limits below are GitHub's documented Marketplace requirements. `::error::`
# lines are GitHub Actions annotations; harmless when run locally.
set -euo pipefail

file="${1:-action.yml}"
status=0

# GitHub's cap. The message says "less than 125 characters", so 125 itself is
# over the line and the check is >=.
readonly DESCRIPTION_MAX=125

field() { yq -r ".$1 // \"\"" "$file"; }

name="$(field name)"
description="$(field description)"
icon="$(field branding.icon)"
color="$(field branding.color)"

# A listing needs a name, and GitHub rejects one containing "GitHub".
if [ -z "$name" ]; then
  echo "::error file=$file::action.yml has no 'name'; the Marketplace listing requires one."
  status=1
elif printf '%s' "$name" | grep -qi 'github'; then
  echo "::error file=$file::action name '$name' contains \"GitHub\", which the Marketplace rejects."
  status=1
else
  echo "name: '$name' ✓"
fi

# The limit that actually bit us.
if [ -z "$description" ]; then
  echo "::error file=$file::action.yml has no 'description'; the Marketplace listing requires one."
  status=1
elif [ "${#description}" -ge "$DESCRIPTION_MAX" ]; then
  echo "::error file=$file::action.yml 'description' is ${#description} characters; the Marketplace requires fewer than ${DESCRIPTION_MAX}. Publishing a release to the Marketplace will fail and the existing listing will 404. Shorten it — put runner requirements and other detail in the README, which is the listing body."
  status=1
else
  echo "description: ${#description}/${DESCRIPTION_MAX} characters ✓"
fi

# branding drives the listing's icon and tile colour; absent, the listing cannot
# be published. GitHub accepts a fixed colour set.
if [ -z "$icon" ]; then
  echo "::error file=$file::action.yml has no 'branding.icon'; required to publish to the Marketplace."
  status=1
else
  echo "branding.icon: '$icon' ✓"
fi

case "$color" in
  white | yellow | blue | green | orange | red | purple | gray-dark)
    echo "branding.color: '$color' ✓"
    ;;
  "")
    echo "::error file=$file::action.yml has no 'branding.color'; required to publish to the Marketplace."
    status=1
    ;;
  *)
    echo "::error file=$file::branding.color '$color' is not one of GitHub's accepted values (white, yellow, blue, green, orange, red, purple, gray-dark)."
    status=1
    ;;
esac

if [ "$status" -ne 0 ]; then
  echo "action.yml would be rejected by the GitHub Marketplace." >&2
fi
exit "$status"
