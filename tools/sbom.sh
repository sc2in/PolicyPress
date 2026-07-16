#!/usr/bin/env bash
# Generate a CycloneDX 1.5 SBOM (JSON, stdout) for the policypress binary.
#
# Scope: the transitive Zig dependencies compiled INTO the shipped static
# binary, taken from build.zig.zon2json-lock — which already pins every
# package by name, exact source URL (with commit), and SRI hash. The Nix
# toolchain that builds it (zig, typst, zola, …) is pinned separately by
# flake.lock and published on FlakeHub; a full build-environment SBOM
# (e.g. sbomnix over the closure) is a possible future addition.
#
# Usage: tools/sbom.sh > sbom.cdx.json     (requires jq; run from repo root)
set -euo pipefail

cd "$(dirname "$0")/.."

LOCK=build.zig.zon2json-lock
[ -f "$LOCK" ] || { echo "missing $LOCK (regenerate with zon2json-lock)" >&2; exit 1; }

VERSION="$(sed -n 's/^\s*\.version = "\([^"]*\)".*/\1/p' build.zig.zon | head -1)"
COMMIT="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

jq -n \
  --arg version "$VERSION" \
  --arg commit "$COMMIT" \
  --arg timestamp "$TIMESTAMP" \
  --slurpfile lock "$LOCK" \
  '
  # A lock key looks like "name-1.2.3-<fingerprint>"; the entry carries the
  # canonical name, the pinned url (with commit), and the SRI hash.
  def components:
    $lock[0]
    | to_entries
    | sort_by(.key)
    | map(
        # A versioned key looks like "name-1.2.3-<fingerprint>"; naked
        # commit pins (test corpora etc.) use an "N-V-…" key with no version.
        ((.key | capture("^(?<n>.+?)-(?<v>[0-9][^-]*)-(?<fp>.+)$")?) // {v: "unknown"}) as $kv
        | {
            type: "library",
            "bom-ref": .key,
            name: .value.name,
            version: $kv.v,
            purl: ("pkg:generic/" + .value.name + "@" + $kv.v),
            externalReferences: [
              { type: "vcs", url: .value.url }
            ],
            properties: [
              { name: "nix:sri-hash", value: .value.hash },
              { name: "zig:package-id", value: .key }
            ]
          }
      );

  {
    bomFormat: "CycloneDX",
    specVersion: "1.5",
    version: 1,
    metadata: {
      timestamp: $timestamp,
      component: {
        type: "application",
        "bom-ref": ("policypress@" + $version),
        name: "policypress",
        version: $version,
        description: "Compliance policy management - Markdown policies to a static site and audit-ready PDFs",
        externalReferences: [
          { type: "vcs", url: ("https://github.com/sc2in/PolicyPress/tree/" + $commit) },
          { type: "website", url: "https://policypress.sc2.in" }
        ]
      },
      properties: [
        { name: "policypress:git-commit", value: $commit },
        { name: "policypress:sbom-scope", value: "zig-dependencies-compiled-into-binary" }
      ]
    },
    components: components
  }
  '
