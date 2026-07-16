+++
title = "Assurance"
description = "PolicyPress attests to itself: audit bundle, SBOM, and accessibility evidence, regenerated on every deploy"
weight = 4
+++

PolicyPress is a compliance tool, so it should hold itself to the standard it
helps you meet. Everything linked below is **generated evidence, regenerated on
every deploy of this demo site** — not a static claim. Your own PolicyPress
site can produce the same audit bundle by setting one input on the GitHub
Action (`audit_bundle: "true"`).

> **What this is — and is not.** These artifacts are produced by automated
> tooling and published as-is. They are evidence you can verify yourself, not
> a certification, audit opinion, or attestation under any framework (SOC 2,
> ISO 27001, or otherwise).

## Audit bundle

Machine-readable exports of this site's compliance state, exactly as the
[`audit_bundle` option](@/guides/configuration.md) produces for any
PolicyPress site:

- [`manifest.json`](/audit/manifest.json) — one entry per published policy:
  title, version, review date, owner, approver, classification, and the
  sha-256 of both the PDF and its Markdown source.
- [`revisions.json`](/audit/revisions.json) — every policy's revision history,
  flattened and queryable in one place.
- [`coverage.json`](/audit/coverage.json) / [`coverage.csv`](/audit/coverage.csv)
  — structured SCF and SOC 2 (TSC 2017) control coverage, the same numbers the
  [reports](@/reports/_index.md) render.

To verify a PDF you downloaded from this site against the manifest:

```bash
sha256sum Example_Security_Policy__Redacted__-_v2.1.pdf
# compare with .policies[].pdf_sha256 in manifest.json
```

This demo publishes its **redacted** build, so the hashes describe the
redacted PDFs you can download here.

## Software bill of materials

- [`sbom.cdx.json`](/assurance/sbom.cdx.json) — CycloneDX 1.5 SBOM of the Zig
  dependencies compiled into the `policypress` binary, generated from the
  dependency lock file's pinned source URLs and integrity hashes. The build
  toolchain itself (Zig, Typst, Zola, …) is pinned by `flake.lock` and
  published on [FlakeHub](https://flakehub.com/flake/sc2in/PolicyPress).

## Accessibility evidence

Both reports below are the **CI gates' own output** — the same runs that must
pass before any change reaches this site:

- PDF/UA-1 conformance of every PDF on this site, validated with veraPDF:
  [`verapdf-report.txt`](/assurance/verapdf-report.txt) ·
  [`verapdf-report.json`](/assurance/verapdf-report.json)
- WCAG 2.1/2.2 AA scan (axe-core) of every page template, light and dark mode:
  [`a11y-report.json`](/assurance/a11y-report.json)

## Build & release integrity

- Every release ships binaries with a
  [`SHA256SUMS.txt`](https://github.com/sc2in/PolicyPress/releases/latest)
  and an SBOM; the GitHub Action verifies the checksum of any binary it
  downloads **before running it**, and fails closed on a mismatch.
- [CI](https://github.com/sc2in/PolicyPress/actions/workflows/ci.yml) gates
  every change behind required status checks (tests, golden snapshots,
  fuzz smoke, redaction leak check, veraPDF, axe-core). Each main-branch run
  uploads an `attestation-evidence` artifact with the full check records and
  logs.
- The flake is published on
  [FlakeHub](https://flakehub.com/flake/sc2in/PolicyPress) for reproducible,
  pinned consumption.

## A note on the numbers

The demo's SCF coverage percentage is intentionally small — a handful of demo
policies mapped against 1,200+ controls. The point of this page is the
*machinery*: the same exports, hashes, and gates apply to a real policy
library.
