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
mapfile -t checks < <(nix eval --json ".#checks.$system" --apply builtins.attrNames | jq -r '.[]')

rows=()
for name in "${checks[@]}"; do
  echo "▸ $name"
  out_path="$(nix build --no-link --print-out-paths ".#checks.$system.$name")"
  drv="$(nix path-info --derivation ".#checks.$system.$name" 2>/dev/null || echo null)"

  log_file="null"
  if nix log "$drv" > "$out/logs/$name.log" 2>/dev/null && [ -s "$out/logs/$name.log" ]; then
    log_file="logs/$name.log"
  else
    # Substituted from a cache without a log — record the absence honestly.
    rm -f "$out/logs/$name.log"
  fi

  rows+=("$(jq -n \
    --arg name "$name" \
    --arg outPath "$out_path" \
    --arg drv "$drv" \
    --argjson log "$([ "$log_file" = "null" ] && echo null || jq -n --arg l "$log_file" '$l')" \
    '{name: $name, status: "pass", outPath: $outPath, drv: $drv, log: $log}')")
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
