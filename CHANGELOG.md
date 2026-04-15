# Changelog

All notable changes to PolicyPress are documented here.

Versions track the tool and theme API. The major version will remain 0.x
until the public API (action inputs/outputs, config.toml schema, front matter
keys) is considered stable.

## [Unreleased]

### Added

- **`policypress new <name>`** CLI subcommand — scaffolds a new policy Markdown file with
  complete YAML front matter (title, date, draft flag, revision history) in `policy_dir`.
  Accepts `--config <path>` to use a non-default config file.
- **Security and governance guide** (`content/guides/securing-your-repository.md`) —
  covers branch protection, CODEOWNERS, policy revision gitflow for ISO/SOC audits, and
  step-by-step deployment guides for GitHub Pages, Azure Static Web Apps + Azure AD SSO,
  and Cloudflare Pages + Zero Trust.
- **Print / Export PDF button** on compliance report pages — expands all collapsed sections
  and triggers the browser print dialog. Paired with a print media query that hides
  navigation chrome and renders a clean, paginated document.
- **macOS CI** — CI matrix now runs on both `ubuntu-latest` and `macos-latest`.
  `mermaid-filter` is skipped on `aarch64-darwin` (already handled in the Nix flake).

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

  # After (this release)
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
