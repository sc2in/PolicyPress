# Changelog

All notable changes to PolicyPress are documented here.

Versions track the tool and theme API. The major version will remain 0.x
until the public API (action inputs/outputs, config.toml schema, front matter
keys) is considered stable.

## [Unreleased]

### Changed

- **Zig 0.16.0 migration** — the codebase and Nix toolchain now target Zig 0.16.0. The new
  `std.Io` context is threaded through all filesystem, process, and concurrency code
  (`std.Thread.Pool` → `std.Io.Group`); dependencies were updated to 0.16-compatible
  versions; the direct `zig-datetime` and `zig-yaml` dependencies were dropped (today's
  date is now computed via `std.time.epoch`; `zig-yaml` remains in the lockfile as a
  transitive dependency of zigmark). `minimum_zig_version` is now `0.16.0`.

### Added

- **`nix run .#bump <version|patch|minor|major>`** — one-command release prep: bumps the
  version in `build.zig.zon` **and** `config.toml` (kept in sync), rolls the CHANGELOG
  `[Unreleased]` section into a dated release section, and commits. CI still builds
  binaries, cuts the GitHub release, and publishes to FlakeHub on tag push. The release
  workflow also stamps `config.toml` so a bare `git tag` push cannot drift.

## [1.2.6] - 2026-05-11

### Fixed

- Additional implementation fixes following the draft.png/ADO changes. (#111)

## [1.2.5] - 2026-05-01

### Fixed

- `draft.png` resolution for PolicyPress-as-a-theme layouts, and Azure DevOps pipeline
  documentation. (#110)

## [1.2.4] - 2026-04-28

### Fixed

- **Windows binary** — cross-compilation to `x86_64-windows` (broken in 1.2.3 by a
  POSIX-only `getenv` call) is fixed with a compile-time platform guard.
- **Logo paths containing `%`** are copied to a temp path before being passed to LaTeX,
  which otherwise treats `%` as a comment delimiter. (#100)
- **Optional revision-table fields** — revision entries with missing optional fields no
  longer cause a render error; those cells are left blank. (#101)
- **`mermaid-filter`** is skipped silently when not found in `PATH` instead of failing the
  build. (#100)
- **CTA links** now correctly handle both absolute URLs and root-relative paths. (#99)

### Changed

- Cloudflare Pages preview deployments are deleted automatically when their source PR
  closes.

## [1.2.3] - 2026-04-28

### Fixed

- Logo path `%` escaping and optional revision-table fields. (#102)
- CTA links handle absolute and relative URLs. (#99)

### Changed

- Runtime dependency packaging improvements.

> Note: 1.2.3 regressed `x86_64-windows` cross-compilation; use 1.2.4 or later.

## [1.2.2] - 2026-04-19

### Added

- Draft-PDF generation and base-URL override in the reusable workflows. (#98)

### Changed

- Demo site verbiage improvements. (#96)

## [1.2.1] - 2026-04-18

### Changed

- Demo site verbiage improvements. (#96)

## [1.2.0] - 2026-04-17

### Changed

- Post-1.0 cleanup pass. (#94)

## [1.1.3] - 2026-04-17

### Fixed

- Corrected the action ref retrieval used when fetching the PolicyPress theme.

## [1.1.2] - 2026-04-16

### Added

- **`policypress new <name>`** CLI subcommand — scaffolds a new policy Markdown file with
  complete YAML front matter (title, date, draft flag, revision history) in `policy_dir`.
  Accepts `--config <path>` to use a non-default config file.
- **Print / Export PDF button** on compliance report pages — expands all collapsed sections
  and triggers the browser print dialog. Paired with a print media query that hides
  navigation chrome and renders a clean, paginated document.

### Changed

- **Breaking: PolicyPress config keys moved to `[extra.policypress]`** — all
  PolicyPress-specific settings are now namespaced under `[extra.policypress]` in
  `config.toml`. Keys that previously lived directly under `[extra]` must be moved.

  **Migration — update your `config.toml`:**

  ```toml
  # Before (1.0.x)
  [extra]
  organization = "Acme Corp"
  logo = "logo.png"
  pdf_color = "#0e90f3"
  policy_dir = "policies/"
  policy_root = "@/policies/_index.md"
  scf_report_page = "@/reports/scf.md"
  soc2_report_page = "@/reports/soc2.md"
  lead = "Security Policy Center"
  redact = false
  show_draft_pdfs = false

  # After (1.1.2+)
  [extra.policypress]
  organization = "Acme Corp"
  logo = "logo.png"
  pdf_color = "#0e90f3"
  policy_dir = "policies/"
  policy_root = "@/policies/_index.md"
  scf_report_page = "@/reports/scf.md"
  soc2_report_page = "@/reports/soc2.md"
  lead = "Security Policy Center"
  redact_web = false
  show_draft_pdfs = false
  ```

  Theme-level keys (`menu`, `policyteam`, `frontpage`, `open`, `footer`, etc.) remain
  under `[extra]` and are not affected.

- **Breaking: `redact` config key renamed to `redact_web`** — the old `redact` key
  controlled website rendering only and was easily confused with the `--redact` CLI flag
  for PDF generation. The new name `redact_web` makes the scope explicit. Update your
  `config.toml` as shown in the migration snippet above.

- **Control data moved from `templates/opencontrols/` to `data/`** — `SCF.yml`,
  `TSC-2017 (SOC2).yml`, and `SCF.json` now live at `data/scf.yml`, `data/tsc2017.yml`,
  and `data/scf.json`. If you overrode `scf_controls` or `tsc2017_controls` in your
  config, update the paths accordingly. Default paths are updated automatically.

## [1.1.1] - 2026-04-16

### Fixed

- Release-automation follow-ups: drop `[skip ci]` from release commits, make the CI cache
  fail gracefully, and run the macOS CI job only on PRs and release tags. (#93)

## [1.1.0] - 2026-04-15

Make-public milestone (#91).

### Added

- **Security and governance guide** (`content/guides/securing-your-repository.md`) —
  covers branch protection, CODEOWNERS, policy revision gitflow for ISO/SOC audits, and
  step-by-step deployment guides for GitHub Pages, Azure Static Web Apps + Azure AD SSO,
  and Cloudflare Pages + Zero Trust.
- **Platform-specific tabbed guide content** — guide pages with platform-specific
  instructions (GitHub Actions vs Azure DevOps, Azure SWA vs GitHub Pages vs Cloudflare)
  now use a tab component so readers see only the steps relevant to their stack. Tab
  selection persists across pages via `localStorage`.
- **macOS CI** — CI matrix now runs on both `ubuntu-latest` and `macos-latest`.
  `mermaid-filter` is skipped on `aarch64-darwin` (already handled in the Nix flake).

### Fixed

- **Release version stamp committed back to repo** — previously the `sed` patch to
  `build.zig.zon` on tag builds was ephemeral (applied in CI, never persisted). The
  release workflow now commits the stamped file and re-points the tag to that commit, so
  `build.zig.zon` in the repo always matches the release version.
- **Floating major version tag (`v1`) automated** — the `v1` tag is now force-updated to
  the latest `v1.x.x` release commit automatically in CI. No manual re-pointing needed.

## [1.0.1] - 2026-04-09

### Added

- Integration testing and the embedded eisvogel LaTeX template (bundled into the binary
  so consumers no longer vendor it). (#87)
- Compliance guide. (#90)

### Fixed

- Resource-leak fixes across the render pipeline. (#87)
- SCF intellectual-property cleanup (control descriptions stripped) and a release-pipeline
  fix. (#90)

## [1.0.0] - 2026-04-09

First public release.

### Added

- **GitHub Action** (`action.yml`) - composite action for building PDFs and deploying a
  Zola policy site from any repository with a single `uses: sc2in/policypress@v1` step.
  Inputs: `config_path`, `output_dir`, `draft_mode`, `redact_mode`.
- **Parallel PDF compilation** - policies compiled concurrently via a thread pool with
  stamp-file caching to skip unchanged policies on incremental builds.
- **Redaction mode** - `{% redact() %}...{% end %}` shortcode blocks are replaced with
  solid black bars in PDF output when `--redact` is active. Redacted filename suffix
  applied to output file only, not to PDF content.
- **Draft watermark** - diagonal "DRAFT" overlay on all pages including title page when
  `--draft` is active. Draft suffix applied to output filename only.
- **Configuration** - `config.toml` driven setup via Zola's `[extra]` section.
  Required fields: `organization`, `logo`, `pdf_color`, `policy_dir`.
  Optional: `redact`, `draft` defaults.
- **Starter template** (`starter/`) - ready-to-use repository template with three example
  policies (access control, incident response, data classification), a pre-configured
  `config.toml`, and a GitHub Actions workflow.
- **Policy website** - Zola-based static site with policy listing, SCF/SOC 2 coverage
  badges, full-text search, and dark mode support.
- **SCF and SOC 2 TSC compliance reports** - JSON coverage reports mapping framework
  controls to policy documents.
- **Cross-platform release binaries** - CI produces pre-built binaries for
  `x86_64-linux`, `aarch64-linux`, `x86_64-macos`, `aarch64-macos`, and `x86_64-windows`
  on every tagged release.
- **Nix flake** - reproducible devshell with Zig, Zola, Pandoc, XeLaTeX, Typst, and all
  runtime dependencies. Published to FlakeHub as `sc2in/PolicyPress`.
- **Error messages** - actionable error output for common failure modes: missing config
  fields, malformed frontmatter, missing `title`/`last_reviewed`/`major_revisions`.
- **Documentation** - configuration guide, writing policies guide, and live editing guide
  under `content/guides/`.
- **PDF naming convention** - `{Title}_-_v{version}.pdf` with `(Redacted)` or `(Draft)`
  variants appended to filename (not to content).
