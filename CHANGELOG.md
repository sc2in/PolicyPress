# Changelog

All notable changes to PolicyPress are documented here.

Versions track the tool and theme API. The major version will remain 0.x
until the public API (action inputs/outputs, config.toml schema, front matter
keys) is considered stable.

## [Unreleased]

## [1.0.0] - 2026-04-09

First public release.

### Added

- **GitHub Action** (`action.yml`) — composite action for building PDFs and deploying a
  Zola policy site from any repository with a single `uses: sc2in/policypress@v1` step.
  Inputs: `config_path`, `output_dir`, `draft_mode`, `redact_mode`.
- **Typst PDF engine** — fast, dependency-light alternative to the pandoc/xelatex pipeline.
  Matches eisvogel layout: title page with logo, version, coloured rule; running header;
  footer with org name, "Confidential", and page number; alternating table row colours;
  Version History table from `extra.major_revisions` frontmatter.
  Enable with `--engine typst` (pandoc remains default until Mermaid support lands).
- **Parallel PDF compilation** — policies compiled concurrently via a thread pool with
  stamp-file caching to skip unchanged policies on incremental builds.
- **Redaction mode** — `{% redact() %}...{% end %}` shortcode blocks are replaced with
  solid black bars in PDF output when `--redact` is active. Redacted filename suffix
  applied to output file only, not to PDF content.
- **Draft watermark** — diagonal "DRAFT" overlay on all pages including title page when
  `--draft` is active. Draft suffix applied to output filename only.
- **Configuration** — `config.toml` driven setup via Zola's `[extra]` section.
  Required fields: `organization`, `logo`, `pdf_color`, `policy_dir`.
  Optional: `redact`, `draft` defaults.
- **Starter template** (`starter/`) — ready-to-use repository template with three example
  policies (access control, incident response, data classification), a pre-configured
  `config.toml`, and a GitHub Actions workflow.
- **Policy website** — Zola-based static site with policy listing, SCF/SOC 2 coverage
  badges, full-text search, and dark mode support.
- **SCF and SOC 2 TSC compliance reports** — JSON coverage reports mapping framework
  controls to policy documents.
- **Cross-platform release binaries** — CI produces pre-built binaries for
  `x86_64-linux`, `aarch64-linux`, `x86_64-macos`, `aarch64-macos`, and `x86_64-windows`
  on every tagged release.
- **Nix flake** — reproducible devshell with Zig, Zola, Pandoc, XeLaTeX, Typst, and all
  runtime dependencies. Published to FlakeHub as `sc2in/PolicyPress`.
- **Error messages** — actionable error output for common failure modes: missing config
  fields, malformed frontmatter, missing `title`/`last_reviewed`/`major_revisions`.
- **Documentation** — configuration guide, writing policies guide, and live editing guide
  under `content/guides/`.
- **PDF naming convention** — `{Title}_-_v{version}.pdf` with `(Redacted)` or `(Draft)`
  variants appended to filename (not to content).
