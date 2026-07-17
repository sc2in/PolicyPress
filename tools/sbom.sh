#!/usr/bin/env bash
# Generate a CycloneDX 1.5 SBOM (JSON, stdout) for PolicyPress.
#
# Scope, in two parts, distinguished by the `policypress:dependency-kind`
# property and the `dependencies` graph:
#   - compiled-in: the transitive Zig dependencies statically compiled into the
#     shipped binary, from build.zig.zon2json-lock (name, pinned source URL
#     with commit, SRI hash).
#   - runtime-tool: the tools PolicyPress invokes as subprocesses (typst,
#     zola), with the exact version of the binary on PATH (pinned by
#     flake.lock). These are not linked into the binary but a CVE in either
#     affects the output pipeline, so an SBOM consumer needs to see them.
#
# The build toolchain itself (zig, glibc, the JVM veraPDF pulls in, …) is
# pinned by flake.lock and published on FlakeHub; a full build-environment
# closure SBOM (e.g. sbomnix) is intentionally out of scope — it would
# describe the CI machine, not the artifact users actually run.
#
# Usage: tools/sbom.sh > sbom.cdx.json
#   Requires jq. typst/zola should be on PATH for their versions (they are
#   inside `nix develop`, which is how CI invokes this); a missing tool is
#   recorded with version "unknown" rather than dropped. Run from the repo root.
set -euo pipefail

cd "$(dirname "$0")/.."

LOCK=build.zig.zon2json-lock
[ -f "$LOCK" ] || { echo "missing $LOCK (regenerate with zon2json-lock)" >&2; exit 1; }

VERSION="$(sed -n 's/^\s*\.version = "\([^"]*\)".*/\1/p' build.zig.zon | head -1)"
COMMIT="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Version of a runtime tool from the actual binary on PATH; "unknown" when the
# tool is absent, so the component is never silently dropped from the SBOM.
tool_version() {
  local v=""
  if command -v "$1" >/dev/null 2>&1; then
    v="$("$1" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
  fi
  printf '%s' "${v:-unknown}"
}
TYPST_VERSION="$(tool_version typst)"
ZOLA_VERSION="$(tool_version zola)"

jq -n \
  --arg version "$VERSION" \
  --arg commit "$COMMIT" \
  --arg timestamp "$TIMESTAMP" \
  --arg typst "$TYPST_VERSION" \
  --arg zola "$ZOLA_VERSION" \
  --slurpfile lock "$LOCK" \
  '
  # Compiled-in Zig deps. A lock key looks like "name-1.2.3-<fingerprint>";
  # naked commit pins (spec-test corpora) use an "N-V-…" key with no version.
  # Emit a pkg:github purl when the source is a GitHub URL (so CVE scanners can
  # resolve it), else pkg:generic.
  def zig_components:
    $lock[0]
    | to_entries
    | sort_by(.key)
    | map(
        ((.key | capture("^(?<n>.+?)-(?<v>[0-9][^-]*)-(?<fp>.+)$")?) // {v: "unknown"}) as $kv
        | ((.value.url | capture("github\\.com/(?<o>[^/?#]+)/(?<r>[^/?#.]+)")?) // null) as $gh
        | {
            type: "library",
            "bom-ref": .key,
            name: .value.name,
            version: $kv.v,
            purl: (if $gh then "pkg:github/" + $gh.o + "/" + $gh.r + "@" + $kv.v
                   else "pkg:generic/" + .value.name + "@" + $kv.v end),
            externalReferences: [ { type: "vcs", url: .value.url } ],
            properties: [
              { name: "policypress:dependency-kind", value: "compiled-in" },
              { name: "nix:sri-hash", value: .value.hash },
              { name: "zig:package-id", value: .key }
            ]
          }
      );

  # Runtime tools invoked as subprocesses (not linked into the binary).
  def tool_components:
    [
      { name: "typst", version: $typst, url: "https://typst.app" },
      { name: "zola",  version: $zola,  url: "https://www.getzola.org" }
    ]
    | map({
        type: "application",
        "bom-ref": (.name + "@" + .version),
        name: .name,
        version: .version,
        purl: ("pkg:generic/" + .name + "@" + .version),
        externalReferences: [ { type: "website", url: .url } ],
        properties: [
          { name: "policypress:dependency-kind", value: "runtime-tool" },
          { name: "nixpkgs:pinned-by", value: "flake.lock" }
        ]
      });

  (zig_components + tool_components) as $all
  | ("policypress@" + $version) as $root
  | {
      bomFormat: "CycloneDX",
      specVersion: "1.5",
      version: 1,
      metadata: {
        timestamp: $timestamp,
        component: {
          type: "application",
          "bom-ref": $root,
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
          { name: "policypress:sbom-scope", value: "compiled-in-zig-deps + runtime-tools" }
        ]
      },
      components: $all,
      dependencies: [
        { ref: $root, dependsOn: ($all | map(.["bom-ref"])) }
      ]
    }
  '
