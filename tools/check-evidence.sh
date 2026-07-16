#!/usr/bin/env bash
# Collect structured evidence about the flake checks for the attestation
# artifact: which checks exist, their store outputs, and (where available)
# their build logs. Run AFTER the checks have been built (e.g. after
# `om ci run` / `nix flake check`) so every `nix build` below is a cache hit.
#
# Honest by construction: this records what actually ran and passed — if any
# check had failed, CI would have stopped before this script. No synthetic
# JUnit; the logs are the evidence.
#
# Usage: tools/check-evidence.sh <output-dir>     (requires nix + jq)
set -euo pipefail

out="${1:?usage: tools/check-evidence.sh <output-dir>}"
mkdir -p "$out/logs"

system="$(nix eval --raw --impure --expr 'builtins.currentSystem')"
# Capture the eval separately: a failure inside a process substitution would
# not trip set -e, and an empty check list must be a loud error, not an
# artifact that silently attests to nothing.
checks_json="$(nix eval --json ".#checks.$system" --apply builtins.attrNames)"
mapfile -t checks < <(jq -r '.[]' <<<"$checks_json")
if [ "${#checks[@]}" -eq 0 ]; then
  echo "✗ no flake checks found for $system — refusing to write empty evidence" >&2
  exit 1
fi

rows=()
for name in "${checks[@]}"; do
  echo "▸ $name"
  out_path="$(nix build --no-link --print-out-paths ".#checks.$system.$name")"
  drv="$(nix path-info --derivation ".#checks.$system.$name" 2>/dev/null || true)"

  log_file=""
  if [ -n "$drv" ] && nix log "$drv" > "$out/logs/$name.log" 2>/dev/null && [ -s "$out/logs/$name.log" ]; then
    log_file="logs/$name.log"
  else
    # Substituted from a cache without a log — record the absence honestly.
    rm -f "$out/logs/$name.log"
  fi

  rows+=("$(jq -n \
    --arg name "$name" \
    --arg outPath "$out_path" \
    --arg drv "$drv" \
    --arg log "$log_file" \
    '{name: $name, status: "pass", outPath: $outPath,
      drv: (if $drv == "" then null else $drv end),
      log: (if $log == "" then null else $log end)}')")
done

jq -n \
  --arg system "$system" \
  --arg commit "${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}" \
  --arg run_id "${GITHUB_RUN_ID:-}" \
  --arg run_url "${GITHUB_SERVER_URL:-}/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID:-}" \
  --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --slurpfile rows <(printf '%s\n' "${rows[@]}") \
  '{
    schema: "policypress/check-evidence/v1",
    timestamp: $timestamp,
    system: $system,
    commit: $commit,
    ci_run: (if $run_id == "" then null else {id: $run_id, url: $run_url} end),
    checks: $rows
  }' > "$out/checks.json"

echo "✓ $(jq '.checks | length' "$out/checks.json") checks recorded in $out/checks.json"
