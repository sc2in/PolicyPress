# Changelog

All notable changes to PolicyPress are documented here.

Versions track the tool and theme API. The major version will remain 0.x
until the public API (action inputs/outputs, config.toml schema, front matter
keys) is considered stable.

## [Unreleased]

### Added

- **Raw HTML in policy bodies is now flagged by the build pre-flight** (#117).
  The website renders raw/inline HTML but the PDF pipeline (zigmark → Typst)
  silently drops it, so a site and its audit PDF could diverge without warning.
  The pre-flight now parses each policy body and reports raw HTML as
  audit-critical: a warning by default, fatal with `--strict`. Detection is
  AST-based, so `<div>` inside a code fence or inline code and `<user@host>`
  autolinks never false-positive. HTML examples belong in fenced code blocks;
  site-only pages (the guides) may still use HTML since only the policy
  directory is rendered to PDF.

## [1.4.2] - 2026-07-06

### Security

- **Web redaction now renders visible bars server-side.** Building on 1.4.1
  (which stopped emitting the body), the `{% redact() %}` shortcode now emits
  solid `█` bars sized to the hidden content when `redact_web = true`, so a
  redacted policy shows a clear redaction mark while the text still never
  reaches the HTML, the client-side search index, or the RSS/Atom feed.
- **Composite action pins and verifies the binary.** The action downloads the
  release binary for the exact pinned action ref (e.g. `@v1.4.1`) instead of the
  latest release, verifies it against a published `SHA256SUMS.txt`, and falls
  back to building from source for refs without a release. `ci` now publishes
  the checksums alongside the release binaries.
- **Action inputs are no longer spliced into the build script.** Inputs such as
  `base_url` are passed through the environment instead of `${{ }}`
  interpolation, removing a shell-injection surface on the consumer's runner.
- **Dev preview server binds loopback by default.** `policypress` no longer
  serves the built site on `0.0.0.0` (all interfaces) while printing
  `127.0.0.1`; it binds `127.0.0.1` and takes an explicit `--interface`
  (e.g. `0.0.0.0`) to expose drafts/internal policies on the LAN. (#117)
- **Front-matter validation runs during the build.** The previously dead
  `validatePolicyFiles`/`validateFrontMatter` checks now run on every build:
  missing audit fields (title, approvals, revision dates/versions) — and a
  blank `approved_by` — are reported, and `--strict` turns them into a build
  failure. Missing `description` stays advisory. (#117)
- **Search suggestions and policy descriptions are HTML-escaped.** The search
  teaser (built from page bodies and injected via `innerHTML`) and the
  front-matter `description` (previously `| safe`) are now escaped, closing a
  stored-XSS surface. (#117)
- **CI runs with least privilege and stops moving release tags.** Build/test
  now runs read-only; only a separate tag-gated `release` job holds
  `contents: write`. The release tag is no longer force-moved after the publish
  triggers fire (versions must be stamped with `nix run .#bump` before tagging,
  now guarded in CI), and the `@main`-pinned third-party actions are pinned to
  release commit SHAs. (#117)
- **The action fails closed on an unverified binary.** A missing
  `SHA256SUMS.txt` or a missing/failed checksum entry now aborts the action
  instead of downgrading to a warning and running the binary anyway. (#117)
- **Starter deploy is safer by default.** The starter build job drops the
  unused Pages/OIDC write scopes (only the deploy job keeps them), `redact_web`
  defaults to `true` so a public Pages deploy masks redaction blocks on the
  site, and the README carries a prominent Pages-visibility warning. (#117)

### Fixed

- **Redacted PDFs no longer corrupt legitimate underscores.** Redaction masked
  spans with underscores and then converted *every* `_` in the body to `█`,
  mangling snake_case identifiers, `_emphasis_`, and URLs in the redacted PDF.
  Redacted spans are now masked with `█` directly and only the spans change.
- **Whitespace-trim redaction tags are honored.** `{%- redact() -%}` /
  `{%- end -%}` variants are now redacted (and still caught when orphaned)
  rather than passing through unmasked.
- **Policy version is chosen by date, not string order.** Selection now matches
  the website (most recent by `date`, numeric version tiebreak), so `1.10` no
  longer loses to `1.9` and the PDF and site never disagree on the version.
- **Incremental-build stamps are keyed by full path.** Two policies with the
  same file name in different directories no longer share a stamp, which could
  cause the second to be skipped as "up to date" with no PDF produced.
- **Colliding PDF names fail the build.** Two policies that resolve to the same
  `{Title}_-_v{version}.pdf` now stop the build (naming both files) instead of
  silently overwriting one another.
- **Site PDF links match the generated files.** The download links on policy
  pages and the PDF filenames now share one sanitizer, so a title with
  punctuation no longer produces a 404 link.
- **`draft: true` policies are excluded from PDF generation**, matching Zola
  (which omits drafts from the site) and the documentation, so an unapproved
  draft no longer gets an official-looking PDF at a guessable URL.
- **Mobile navigation works again.** The menu button is a real toggle wired to
  the collapse handler, so the nav and search are reachable below the `md`
  breakpoint.
- **Stale PDFs are swept from the output directory.** A policy that is renamed,
  retitled, deleted, or turned into a draft no longer leaves its old PDF behind
  at a guessable URL: each build removes PDFs that match no current policy (any
  variant), so it stays safe to build several variants into one directory. (#117)
- **Dead code cleaned up.** The advertised `-i/--input` flag now actually
  re-roots the content directory, the unused `reports` import was removed, and
  `control_report`'s standalone entrypoint points at the real
  `data/<standard>.json` path. The dev preview server compiles again (its
  argument parsing had drifted from the current CLI API). (#117)

### Changed

- **Mermaid diagrams render to inline SVG at build time.** The website no longer
  ships the ~30 MB vendored `mermaid` bundle or loads client-side JavaScript to
  draw diagrams. A new `policypress render-diagrams <dir>` step (run after
  `zola build`, wired into the action) rewrites each diagram to inline SVG with
  the same in-process renderer (pozeiden) used for PDFs, so diagrams are
  identical across site and PDF and render with JavaScript disabled. Dev preview
  via `zola serve` shows the diagram source as a fallback. (#114)

### Added

- `tests/redaction-leak-check.sh` builds the demo site and redacted PDFs and
  asserts no `{% redact() %}` content survives into the site (HTML, search
  index, feeds) or the PDF output directory. It runs in CI on Linux. It now also
  asserts mermaid diagrams became inline SVG (no client bundle referenced) and
  that stale PDFs are swept on rebuild.
- `--strict` build flag: fail the build on audit-critical front-matter problems.
- `render-diagrams` subcommand: render a built site's mermaid diagrams to inline
  SVG (see Changed).

## [1.4.1] - 2026-07-04

### Security (GHSA-j557-r6p7-8r3m)

- **Web redaction was CSS-only** — the `{% redact() %}` shortcode hid content
  with `color: transparent` but emitted the raw text into the HTML, leaving it
  fully readable in source and indexed by Zola's `search_index.en.js`. The
  shortcode now emits no body content when `redact_web = true`.
- **Starter kit workflow published unredacted PDFs** — the default
  `starter/.github/workflows/build.yml` had `redact_mode` defaulting to
  `false`, so a push to `main` would deploy unredacted PDFs to GitHub Pages
  without any opt-in. The default is now `true`.
- **PDF redaction silently skipped malformed blocks** — if a `{% redact() %}`
  tag had no matching `{% end %}` (or vice-versa), the block passed through
  unredacted without any error. `redact()` now returns `error.UnclosedRedaction`
  on any orphaned tag, failing the build before a PDF is written.

## [1.4.0] - 2026-07-03

### Changed

- **PDF engine migrated from pandoc/XeLaTeX/Eisvogel to Typst** (#58). Markdown
  is rendered to Typst markup in-process by zigmark and compiled by the `typst`
  CLI; the layout (title page, colored rule, logo, headers/footers, zebra
  tables, TOC, version-history table) reproduces the Eisvogel look. CLI flags,
  config options, and output filename patterns are unchanged.
- The GitHub Action's build shell is now pinned to the action's own version
  (previously it floated on `main`, so flake changes could break consumers
  running older release binaries).
- `-v/--verbose` now shows typst invocations instead of pandoc arguments.

### Added

- **Native mermaid rendering via pozeiden** - diagrams compile to inline SVG
  in-process with no browser, Node.js, or Chromium. Diagram-bearing policies
  now build inside the Nix sandbox and on macOS, and diagrams render at their
  natural size (capped at the text width) instead of being scaled to full page
  width.
- Full test suite now runs on macOS CI (previously only semantic analysis,
  blocked by mermaid-filter's Chromium dependency).

### Fixed

- `redact_web` no longer drives PDF redaction (#115). It was documented as
  web-only but seeded the PDF pipeline's redact default, so an org hiding
  content (e.g. phone numbers) on the website could not keep it in the PDFs
  without passing `--no-redact`. PDF redaction is now controlled solely by
  `--redact`/`--no-redact` and the action's `redact_mode` input (which always
  passes an explicit flag, so action consumers are unaffected). If you ran
  the bare CLI and relied on `redact_web = true` redacting PDFs, pass
  `--redact` explicitly.

### Removed

- pandoc, texlive/eisvogel-tex, and mermaid-filter (Node.js + Puppeteer +
  Chromium) from the toolchain, along with the `MERMAID_FILTER_CMD_MMDC`
  sandbox workaround, fontconfig plumbing, and the embedded `eisvogel.latex`
  template. The Nix CI closure shrinks from multiple GB to a few hundred MB.
- `Config.data_dir` (was only used to stage the LaTeX template).

## [1.3.0] - 2026-07-02

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
