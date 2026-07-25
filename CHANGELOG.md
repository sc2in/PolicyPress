# Changelog

All notable changes to PolicyPress are documented here.

Versions track the tool and theme API. The public API - GitHub Action
inputs/outputs, `config.toml` schema, and front-matter keys - follows semantic
versioning; breaking changes to it bump the major version.

## [Unreleased]

### Changed

- Marketplace listing polish: a clearer Action tagline (`action.yml` description)
  and a README banner that makes the "free for your own organization; commercial
  license only to serve others" split unmissable above the fold (the GitHub
  Marketplace listing renders the README).

## [1.7.0] - 2026-07-25

### Added

- **Private-by-default site visibility + turnkey SSO deploy.** A new
  `[extra.policypress] private` key (default off; the starter template ships it
  **on**) marks a policy site as confidential/internal: every page is served
  `noindex, nofollow` and `robots.txt` becomes `Disallow: /`, so policies stay
  out of search engines even if a URL leaks. The build prints an advisory when a
  `private` site would still publish a `/sitemap.xml`; the starter pairs the flag
  with `generate_sitemap = false`. The starter also ships a ready-to-fill
  `static/staticwebapp.config.json` (Azure AD SSO gating every route, redirect to
  Microsoft login, `X-Robots-Tag: noindex`) and a hardened `static/_headers`, so
  putting the site behind SSO is a fill-in-your-tenant-ID step rather than a
  hand-authored config. `private` governs discoverability only — access control
  is still the hosting layer's job (see the "Securing your repository" guide).
- **Native `[^CONTROL-ID]` footnote references (opt-in, #173).** Inline control
  references can now be written as standard Markdown footnote references
  (`[^IAC-01]`) instead of the `{{ control(id="IAC-01") }}` shortcode, enabled by
  `[extra.policypress] control_footnotes = true` (default off). A new
  `policypress stage-site` subcommand performs a pre-Zola content-synthesis pass:
  it writes a disposable copy of the site root with the matching
  `[^IAC-01]: …` footnote definitions appended to each content Markdown file —
  the web analogue of what the PDF pipeline already does — and the GitHub Action
  builds from that staged root (`zola --root "$SITE_ROOT" build`). The transform
  is append-only and its definitions derive only from the SCF catalog and the
  policy library, never from document bodies, so the redaction chokepoint (#116)
  is unaffected and the authored `content/` tree is never modified; the staged
  copy lives outside the workspace and is never published. With the flag off,
  `stage-site` prints `.` and the build is unchanged. Native references render as
  a bottom-of-page footnote linking to the SCF report-page anchor, whereas the
  shortcode renders an inline link — both are supported and may be mixed. Under
  `--strict`: with the flag off, any control-shaped `[^…]` is an error (use the
  shortcode); with it on, a known SCF id is accepted while an unknown one is
  still an error (typo detection). A non-fatal advisory additionally flags a
  control referenced inline (either syntax) but absent from `taxonomies.SCF`,
  since coverage is computed from the front-matter tags alone. The demo enables
  the flag and uses one native reference to exercise coexistence in CI.
- **Audit bundle praxis-join facet (`audit/join.json`).** When a praxis control
  join is configured (`[extra.policypress] praxis_join`), the audit bundle gains
  a new `join.json` file (schema `policypress/audit-join/v1`) exposing the
  policy↔praxis cross-check directly, so an external GRC system or auditor can
  consume it without recomputing it from `coverage.json`. It carries the praxis
  provenance, a spine summary that partitions every spine control into covered,
  excluded, or unaddressed (a control both covered and excluded counts as
  covered, so the three sum to the total), and one row per control in the union
  of the praxis spine, the SCF-tagged controls, and the declared-out-of-scope
  controls — each recording spine membership, the policies that declare it, the
  policies that declare it out of scope, and whether those conflict. The file is
  written **only** when a join is configured; without one the bundle is
  byte-for-byte unchanged. The generator (`nix run .#gen-praxis-join`) gained
  `-o -` to write to stdout, enabling a consumer-side CI drift check (see the
  Compliance Frameworks guide).
- The audit bundle's `coverage.json` / `coverage.csv` now carry an additive
  per-control `excluded_by` list — the policies that declare a control out of
  scope via `extra.scope_exclusions`. The `policypress/audit-coverage/v1` schema
  string is unchanged (consumers that exact-match it and ignore unknown keys are
  unaffected); an exclusion is a distinct third state, never counted as coverage.
- Scaffolds from `policypress new` now include commented `taxonomies:`/`SCF:`
  and `extra.scope_exclusions` stubs so authors discover both — still commented,
  so a fresh scaffold validates unchanged.
- **Praxis control-join plumbing.** A new optional `config.toml` key,
  `[extra.policypress] praxis_join`, points at a committed JSON file
  (`data/praxis-join.json`, schema `policypress/praxis-join/v1`) listing the bare
  SCF control ids an external GRC system (praxis) actively governs. A stdlib-only
  generator (`tools/gen-praxis-join.py`, flake app `nix run .#gen-praxis-join`)
  produces it deterministically from a praxis flake ref (or an offline id list),
  and the loader hard-errors on a missing or mismatched schema. This step is
  plumbing only — no rendering changes yet; the key is unset by default and every
  praxis surface degrades gracefully when it is absent.
- **Policy revisers, approvers, and owners now link to their team profiles, and
  each profile links back.** A revision table's *Revised by* / *Approved by*
  entries, the policy header's owner and approver, and news bylines all resolve a
  name to its team page when it is on the byline roster
  (`config.extra.policyteam.members`). Each team profile gained a **Contributions**
  section listing the policies and news it owns, revised, approved, or authored.
  Both directions are derived from front matter every build, so a name that isn't
  on the roster (a role like "CEO", or a former contributor) renders as plain
  text — no broken links and nothing to maintain by hand. A new `person_link`
  macro (`templates/macros/people.html`) centralizes the lookup.
- **The starter template is now a tracked, CI-verified source of truth.** The
  `starter/` tree is the canonical "Use this template" starting point: a lean,
  private-by-default site (example policies + the dashboard homepage, a neutral
  placeholder `static/logo.png`, and a `.gitignore` for build outputs). A new
  `nix run .#build-starter` — run in CI on every PR — builds it through the full
  Action pipeline and asserts a working, private-by-default site + PDFs, so a
  theme change can no longer silently break a real user's starter. On a release
  tag, `publish-template.yml` regenerates the `sc2in/policypress-template` repo
  from `starter/` (given a `TEMPLATE_DEPLOY_KEY` token), so the published
  template can never drift from the toolchain again.

### Changed

- **Licensing: PolicyPress is now free for any organization's own use.**
  Alongside PolyForm Noncommercial 1.0.0, it may now be used under **PolyForm
  Internal Use 1.0.0** — free for a company of any size to manage its own
  policies (internal business operations, affiliates included). A commercial
  license is required only to offer PolicyPress *to others* (an MSP/consultancy
  running it for clients, a hosted/SaaS offering, embedding, or redistribution);
  optional support subscriptions add SLAs and indemnification. Adds
  `LICENSE-PolyForm-Internal-Use-1.0.0.md` and a plain-language `LICENSING.md`,
  updates the `theme.toml`/README license metadata, and stamps dual SPDX headers
  (`PolyForm-Noncommercial-1.0.0 OR PolyForm-Internal-Use-1.0.0`) across the
  sources.
- **The demo Team section is now a five-person security & compliance team** — a
  CISO, a Compliance/GRC manager, a security engineer, an IT/infrastructure lead,
  and a data protection officer — following the A.B./C.D./E.F. initials scheme,
  with fresh photos and clearly-labelled fictional demo bios. The scattered
  example names (Alice Beuler, Charlie Brown, Jane Smith, John Doe, and a
  misspelled "Alice Bueler" in the guides) are reconciled onto this roster across
  the example policies, news posts, and guides, and two new release-note news
  posts (1.5, 1.6) were added.
- The byline roster (`config.extra.policyteam.members`) is slimmed to `name` +
  `page` — the only fields any template consumes — removing the previously
  duplicated and drift-prone `title`/`email`/`phone`/`image` fields.

### Fixed

- The news section-listing byline now reads the real `page.authors`; its previous
  branch referenced an undeclared `authors` taxonomy and rendered no author at
  all. Also removed a never-included `contributors.html` partial, an empty
  leftover `templates/pdf/policy.tex`, and a dead debug comment in
  `src/control_report.zig`.
- The homepage and policy templates no longer fail the site build on a site
  without a `[extra.policyteam]` roster or a `news/` section. `person_link` call
  sites default the roster to `[]` (and the macro renders a roster member with no
  `page` as plain text), and the homepage fetches a news section only when
  `[extra.policypress] news_page` is set — Zola's `get_section` has no `required`
  argument, so the prior `required=false` guard was a silent no-op that errored on
  any site without `news/`. Both paths were only ever exercised by the
  fully-populated demo (which defines both, keeping CI green), so a minimal
  starter would have broken the instant the next release shipped. The new starter
  build check guards them.
- `policypress --version` and `policypress --help` no longer segfault. The
  top-level flag path is now handled directly — printing the version and the
  top-level usage respectively and exiting 0 — instead of falling through to the
  build path (which knew nothing about `--version`). The underlying crash was a
  `std.Io.Writer` migration bug: `runBuild` took the `.interface` field off the
  temporary `File.Writer` returned by `stderr().writer(...)`, so once that
  temporary went out of scope the flush/drain vtable recovered a dangling parent
  via `@fieldParentPtr` and dereferenced a stale file handle. The writer is now
  kept in a named local (matching `stage-site`), which also fixes `build --help`
  and clap error reporting.

## [1.6.1] - 2026-07-21

### Added

- **GitHub Releases now include an `aarch64-windows` binary.** The release
  cross-compilation target list is now a single source of truth
  (`release-targets.json`) shared by `nix run .#release` and CI, which resolves
  a prior drift where the flake app built six targets but CI shipped only five
  (omitting `aarch64-windows`).

### Internal

- **CI cost/time reductions.** Pushing to a branch with an open PR no longer
  runs CI twice (the `push` trigger is scoped to `main` + tags; `pull_request`
  covers feature branches). The macOS matrix leg is skipped on docs-only PRs
  (`*.md` / `docs/`) and the `omnix` install is gated to the Linux path that
  actually uses it.
- **Release binaries cross-compile in parallel.** The release job fanned a
  sequential per-target loop into a matrix (one runner per target) plus a
  gather/publish job, cutting release wall-clock substantially. The publish
  job reuses the SBOM the CI job already produced instead of regenerating it.
- **FlakeHub publishing is gated on CI.** Tag publishing moved into the
  release-publish job (which runs only after CI and every cross-compile leg
  pass), so a tag whose tests fail no longer publishes to FlakeHub. The
  standalone FlakeHub workflow remains as a manual (`workflow_dispatch`)
  re-publish escape hatch.
- **All first-party GitHub Actions are now pinned to commit SHAs** (with a
  `# vX.Y.Z` comment), matching the third-party actions that were already
  pinned. `actions/checkout` is unified on v4. Removes the mutable-tag
  supply-chain risk of floating `@v4`/`@v5`/`@v7` references.
### Changed

- **The SCF control catalog is now generated, not hand-copied.**
  `data/scf.{json,yml}` regenerate from the pinned `scf` flake input
  (`github:sc2in/scf`, SC2's validated Secure Controls Framework
  pipeline) via `tools/gen-scf-catalog.py` / `nix run .#gen-scf-catalog`.
  The catalog jumps from the hand-committed 2025-vintage 1,239 controls to
  the full SCF 2026.1.1 set of 1,468. A new `scf-catalog-fresh` flake check
  fails CI whenever the committed catalog drifts from the pinned input, and
  a `scf.json`↔`scf.yml` control-ID parity test guards the two generated
  files against each other. Coverage-report floors raised accordingly.
  (`data/tsc2017.*` is AICPA content with separate provenance — untouched.)
### Removed

- **Dropped `x86_64-darwin` (Intel macOS) from the flake's supported systems**,
  following nixpkgs retiring it as a supported platform. `nix build`,
  `nix develop`, and `nix flake check` no longer evaluate for Intel-Mac hosts;
  CI runs on `aarch64-darwin` (`macos-latest` is Apple Silicon). The
  cross-compiled `x86_64-macos` release binary is unaffected — it is still
  built and shipped, since it cross-compiles from any host.

## [1.6.0] - 2026-07-18

### Internal

- **The SBOM now lists the `mitex` Typst package** as a `typst-package`
  component, modelled as a dependency of `typst` in the CycloneDX graph. It is
  vendored into the offline Typst cache and runs at compile time to render
  math, so a CVE in it affects the PDF output — the same rationale that already
  puts typst/zola in the SBOM. Version is read from the `@preview/mitex:`
  import in `src/typst.zig` (which CI's math build forces to match the vendored
  package).
- **CI now produces self-attestation evidence.** Every push to `main`, every
  release tag, **and every pull request to `main`** uploads an
  `attestation-evidence` artifact (90-day retention) containing: a CycloneDX
  1.5 SBOM (`tools/sbom.sh`); a structured record of every `nix flake check`
  with captured build logs (`tools/check-evidence.sh`); the veraPDF PDF/UA-1
  validation reports (text + JSON — the `pdf-accessibility` check now writes
  them into its own `$out`, so the published evidence is the CI gate's
  hermetic output); and the axe-core scan results as JSON (`A11Y_REPORT`, no
  behaviour change when unset). Running it on PRs keeps a broken generation
  step off `main` and lets a reviewer examine the SBOM/reports before merge.
  GitHub Releases additionally ship `sbom.cdx.json` beside `SHA256SUMS.txt`.
  - The SBOM covers both the Zig dependencies compiled into the binary (from
    the lock file's pinned URLs and SRI hashes, with `pkg:github` purls that
    CVE scanners can resolve) **and the runtime tools it invokes as
    subprocesses** — typst and zola, at the exact versions on `PATH` (pinned
    by `flake.lock`) — distinguished by a `policypress:dependency-kind`
    property and the CycloneDX `dependencies` graph. The build-environment
    closure (zig, glibc, …) stays out of scope: it is pinned by `flake.lock`
    and would describe the CI machine, not the artifact users run.
- Removed a dead `zig2nix` invocation from the devShell `shellHook` that
  printed "command not found" on every shell entry (no `zig2nix` binary is on
  `PATH`; the lock regenerator is the zig2nix flake app `zon2json-lock`, run
  deliberately via `nix run .#update-zon`).
- **CI logic moved out of the workflow YAML into flake apps and a shared
  script**, so it runs identically locally and in CI with pinned tools:
  `nix run .#sbom`, `.#check-evidence`, and `.#a11y-scan` (the last pins
  chromium/node/zola instead of a floating `nixpkgs#…` reference), plus
  `tools/check-release.sh` (the tag CHANGELOG + version-stamp guards, also
  `nix run .#check-release`). The redundant "Redaction leak check" workflow
  step was dropped — it duplicated the `redaction-leak` flake check that
  `om ci run` already runs.
- Build: the `mvzr`, `clap`, preview-server, and report modules now inherit the
  top-level `-Doptimize` instead of pinning `ReleaseSafe`/`ReleaseFast`, so a
  single build compiles each dependency at one optimize level instead of
  several (#138).

### Added

- **TeX math now renders in policy PDFs** (#140). Set `extra.math = true` in a
  policy's front matter — the same opt-in that already enables KaTeX on the
  website — and `$…$`/`$$…$$` math renders in the PDF via the Typst `mitex`
  package instead of appearing as literal dollar-text. Off by default, so
  every non-math policy's PDF is byte-identical. The `mitex` package is
  vendored into the offline Typst build, so no network access is needed at
  build time. Tagged (PDF/UA-1) builds stay conformant: each equation carries
  its own alt text (its TeX source, via zigmark v0.10.0), which typst's UA-1
  mode requires.
- **Markdown image alt text now carries into tagged PDFs** (#136). A Markdown
  image's alt text (`![description](…)`) becomes the Typst `image(alt: …)`
  argument, so images satisfy PDF/UA-1's alt-text requirement with a real
  description rather than only the document-wide "Diagram" fallback (kept for
  images with no alt source, such as rendered mermaid diagrams). Comes with the
  zigmark v0.10.0 upgrade.
- **Opt-in machine-readable audit bundle** (#135). `--audit-bundle` (or
  `[extra.policypress] audit_bundle = true`, or the action's `audit_bundle`
  input) writes an `audit/` directory beside the PDFs: `manifest.json` (one
  entry per published policy — title, version, review date, owner, approver,
  classification, PDF filename, and sha-256 of both the PDF bytes and the
  Markdown source), `revisions.json` (every policy's revision history,
  flattened), and `coverage.json`/`coverage.csv` (structured SCF + SOC 2
  control coverage with the same corrected numerator as the website and the
  report PDFs). Deterministically sorted; produced only by official (non
  draft) passes; the default build output is unchanged. The redaction leak
  check now also scans the bundle. New action output: `audit_path`.
- **The compliance reports now ship as real, versioned PDFs** — the same Typst
  engine, fonts, branding, and (when configured) tagged PDF/UA-1 output as the
  policy PDFs, replacing the print-this-page stopgap. Every build regenerates
  `SCF_Coverage_Report.pdf`, `SOC_2_Coverage_Report.pdf`, and
  `Policy_Review_Report.pdf` under stable names beside the policy PDFs (the
  generation date is on the title page, not in the filename), and the report
  pages grew a "Download PDF" button next to Print. Coverage uses the same
  corrected numerator as the website (distinct catalog controls with ≥1
  mapped published policy; drafts excluded), and the review report carries
  Current / Due soon / Overdue statuses driven by `review_overdue_days`.
  Disable with `[extra.policypress] report_pdfs = false`. The GitHub Action's
  `report_path` output now points at the PDF directory. Includes a JSON mirror
  of the TSC 2017 catalog (`data/tsc2017.json`, parity-tested against the
  YAML), golden snapshots of the generated report markup, and veraPDF
  coverage of the report PDFs in the `pdf-accessibility` gate.
- **The demo site publishes its own evidence on a new Assurance page**
  (`/reports/assurance/`): the live audit bundle (`/audit/`), the binary's
  CycloneDX SBOM, and the veraPDF PDF/UA-1 + axe-core reports — assembled on
  every deploy from the CI gates' own outputs (`/assurance/`), with an
  explicit note that this is verifiable automated evidence, not a
  certification. The demo build now runs with `audit_bundle: "true"`. Also
  fixed a real WCAG AA contrast failure it surfaced: the baked-in
  github-dark highlight palette renders code comments at ≈3.1:1; a CSS
  override lifts them to ≈4.6:1. PR previews build the same `/audit/` and
  `/assurance/` artifacts as production, so the page's evidence links
  resolve on the preview rather than 404ing before merge.
- **Reports and Guides joined the main navigation**, and both section indexes
  now render as card landings (new `section-cards.html` template with title,
  description, and link per page) instead of the bare default section list.
  Report pages carry explicit weights so the landing orders SCF → SOC 2 →
  Last Reviewed.

### Fixed

- **A trailing `# comment` after a front-matter value no longer breaks the
  build.** YAML like `last_reviewed: 2025-01-01  # last audit` or a commented
  revision date previously failed the whole policy with a parse error; the
  zigmark v0.10.0 upgrade (which pins the sc2in/zig-yaml 0.3.1 "comment
  terminates a plain scalar" fix) parses it cleanly.
- **Fixes from the batch self-review**: the two-row header offset now
  actually applies on tablet widths (a pre-existing `4rem !important` rule
  overrode it between 768–991px); the homepage "Reviews overdue" tile and
  badges follow `review_overdue_days` instead of a hardcoded year, so the
  dashboard, build pre-flight, and Policy Review PDF agree on "overdue";
  audit-bundle files are written via temp-file + rename (a crash can no
  longer leave a truncated manifest) and a frontmatter-string lifetime
  hazard in the coverage export was removed; a coverage report whose control
  catalog was removed is now swept like any orphaned PDF instead of served
  stale forever; `tools/check-evidence.sh` fails loudly when the check list
  can't be evaluated (instead of attesting to nothing) and records a missing
  derivation as JSON null; the docs deploy got the `id-token` permission the
  FlakeHub cache needs, so the assurance step reuses CI's veraPDF output
  instead of rebuilding it; and the demo enables `audit_bundle` in
  `config.toml` (not only via the action's input), so local previews
  (`nix run .#serve` / `.#preview`) serve `/audit/` just like the deployed
  site. Those two apps also now generate their PDFs with `--redact` (matching
  the demo's `redact_mode`): with `redact_web = true` the policy pages link
  the `__Redacted__` filenames, so the previous non-redacted local build
  404'd every PDF download link.
- **Navigation menu `weight` is honored.** It was documented as the sort
  order but entries always rendered in file order; entries are now sorted by
  weight when every entry carries one (file order otherwise, so existing
  configs without weights keep working).
- **Mobile and tablet layout fixes** across the site:
  - The navbar now expands at the `lg` breakpoint instead of `md`, and the
    search box shrinks instead of holding a fixed 20rem — five nav items plus
    search no longer overflow the header between 768px and 991px.
  - The docs sidebar starts collapsed behind its ☰ Menu button on small
    screens (it rendered fully expanded above the content, forcing a long
    scroll to reach the page; without JS it stays expanded).
  - Page content is offset below the taller two-row fixed header on small
    screens, so the sidebar toggle is no longer clipped underneath it.
  - Wide markdown tables scroll horizontally on phones instead of overflowing
    the page; the policy-review table wraps its columns cleanly.
  - The homepage statistics band stacks on phones and lets long stats wrap
    (previously `white-space: nowrap` clipped "Framework-ready" offscreen),
    quick-action cards collapse to one column on narrow phones, and dashboard
    stat tiles stack full-width instead of an asymmetric 8/12 column.

### Documentation

- **Two new persona guides**: *Editing Without Git* (#10) — maintain policies
  entirely from the browser via the GitHub web editor, github.dev, or an
  optional Sveltia CMS setup, with the approval-metadata discipline spelled
  out; and *Running Multiple PolicyPress Instances* — one central toolchain
  with one owned repo per entity or program from the template, exact theme
  pins with a rollout ritual, per-entity branding, audit bundles that roll up
  to a single central oversight dashboard, and the ownership/access model.

## [1.5.0] - 2026-07-15

### Security

- **The PDF colour is now validated as a bare hex value before it is
  interpolated into the Typst preamble.** `pdf_color` was written straight into
  `rgb("#…")`, so a malformed or hostile value could break out of the call and
  inject arbitrary Typst (which can read files within the build root). Non-hex
  values now fall back to black with a warning.
- **File-read byte caps are centralized and tightened.** The former 100 MB
  policy reads are capped at zigmark's 16 MiB parse ceiling (a larger file could
  not be parsed anyway), and config reads at 1 MiB, so a malformed or hostile
  file cannot drive an unbounded allocation.

### Internal

- Added rulesets-as-code (`.github/rulesets/*.json`) with a `sync-rulesets`
  workflow that reconciles the live branch rulesets by name on push to `main`.
  The `protect-main` ruleset now declares **required status checks**
  (`ci (ubuntu-latest)` / `ci (macos-latest)`) so main can no longer be merged
  red — previously main had no required checks. Inert until the repository
  owner creates a `RULESET_SYNC_TOKEN` secret.
- Added golden snapshots of the generated Typst markup (`golden_test.zig`,
  baselines in `tests/golden/`, regenerate with `zig build update-golden`). They
  render fixtures under a date-pinned config and diff byte-for-byte, so any
  unintended change to the PDF markup is caught in the existing `test` gate.
- Added a fuzz harness (`zig build fuzz`) for PolicyPress's own config/front
  matter/raw-HTML/redaction/shortcode surfaces, and new `nix flake check` gates:
  a fuzz smoke run, `zig fmt --check`, a ReleaseSafe test build (the shipped
  binary is ReleaseSafe but tests ran Debug only), and the redaction-leak
  integration check (previously only a GitHub step). Pinned the remaining
  third-party GitHub Actions to commit SHAs; GitHub-owned `actions/*` stay
  tag-pinned.

### Documentation

- Documented the release flow under branch protection. `main`'s rulesets require
  a PR and passing status checks with no bypass, so a release commit can no
  longer be pushed straight to `main`. `nix run .#bump` now prints the
  branch → PR → merge → tag steps (and warns when run on `main`) instead of the
  old `git push origin HEAD` one-liner, and `CONTRIBUTING.md` gained a
  "Releasing" section describing the same flow.

### Added

- **Opt-in tagged, accessible PDFs (PDF/UA-1)** (#119). Set
  `[extra.policypress] pdf_standard = "ua-1"` to emit PDFs with a structure
  tree, document title, and image alt text — the accessibility standard many
  procurement reviews require. It is opt-in because ua-1 is a hard-fail
  standard; to make policies conform, PolicyPress now unconditionally emits the
  title page as a real level-1 heading (so body headings are consecutive) and a
  fallback `#set image(alt: …)` (so mermaid diagrams and other images always
  carry alt text) — both are back-compatible with plain, untagged builds. When
  `pdf_standard` is set, the build pre-flight also flags a policy that skips a
  heading level and names the file, because Typst's own error points at an
  internal temp file that is deleted on failure. The demo docs site now builds
  as PDF/UA-1; the starter is left untagged. See the "Building PDFs" guide. A
  `nix flake check` gate (`checks.pdf-accessibility`) validates the demo PDFs
  against PDF/UA-1 with veraPDF, so a rendering change cannot silently break
  conformance.
- **The build pre-flight now flags overdue policy reviews** (#119). A policy
  whose `extra.last_reviewed` is older than `review_overdue_days` (default 365,
  relative to the build date) is reported as audit-critical: a warning by
  default, fatal with `--strict`. On a quiet repo the website's own time-based
  "Review overdue" badge only refreshes on a rebuild, so a PDF could keep
  asserting a review that was really years stale. An unparseable date is
  advisory. Configure the window with `[extra.policypress] review_overdue_days`.
- **Redacted PDFs now carry an in-document "REDACTED" title-page banner**, so a
  printed redacted copy is self-identifying rather than distinguishable only by
  filename (draft builds already carry a full-page watermark).
- **The PDF footer classification is configurable.** It defaults to
  "Confidential" (the previous hardcoded value); set a site-wide default with
  `[extra.policypress] classification`, or override per policy with
  `extra.classification` in front matter.
- **Policy pages now render the document owner** (`extra.owner`, previously
  documented but shown nowhere) and, in `--drafts` builds, a Draft badge.
- The starter workflow now runs a weekly scheduled rebuild so time-based
  "Review overdue" badges stay current on repositories that rarely push, and
  prints a GitHub Pages visibility reminder on deploy.

### Accessibility

- **Compliance report sections are now keyboard-operable and work without
  JavaScript** (#119). Each collapsible family/domain header is a real `<button>`
  with `aria-expanded`/`aria-controls`, so it is focusable and toggles with
  Enter/Space; the collapse styling is gated behind a `pp-js` flag so a no-JS
  visitor sees every section expanded rather than collapsed-and-stuck. Deep
  links into a collapsed section now expand it first. The pure-CSS print
  force-expand is unchanged.
- **Guide tab groups follow the ARIA tabs pattern** (#119): arrow keys move
  between tabs (wrapping), Home/End jump to the ends, Enter/Space activate, and
  each panel is a labelled, focusable `tabpanel`.
- **Accessibility sweep** (#119): every page's "Skip to main content" link now
  has a target (`id="main-content"` added to the default page/section, reports,
  team, news, and 404 templates; the news templates' duplicate skip link was
  removed); the policy title is an `<h1>`; the header logo has descriptive `alt`
  text; the search box is a proper ARIA combobox (`role="combobox"`, managed
  `aria-expanded`/`aria-activedescendant`, a `listbox` of `option`s, and a polite
  live-region result count); and rendered mermaid diagrams carry
  `role="img"` with a fallback label.
- **The site now passes automated WCAG 2.1/2.2 AA checks (axe-core) on every
  page type, in light and dark mode** (#119). Fixes surfaced by axe:
  - Report pages gained a real `<title>` and a `<main>` landmark; the default
    page/section, team, 404, and home templates now expose their content
    through a `<main>` landmark (clearing "no main landmark" / "content not in
    a landmark"); the marketing hero moved inside `<main>` and dropped its
    duplicate `role="banner"`.
  - **Brand-colour contrast**: the brand blue (`#0e90f3`) failed 4.5:1 both as
    link/label text and behind white text. A darkened `--pp-brand-strong`
    (with its rgb set so Bootstrap 5.3's `*-rgb` link colour picks it up) now
    backs links, primary/outline buttons, the active nav item, brand badges,
    the skip link, and the stats band; dark-mode brand text is lightened to
    stay legible on dark surfaces.
  - Muted/secondary text, control-count hints, satisfies tags, and admonition
    (callout) titles were darkened/blended to meet 4.5:1 in both themes.
  - In-prose links are underlined (not colour-only); heading anchor links are
    revealed on hover/focus (out of the "link in text block" check); a team
    heading-order skip and the section index's `<h3>` were corrected.
- **Automated accessibility gate**: a new CI step runs axe-core (vendored,
  self-hosted — no npm/CDN) over a representative page of every template in
  both colour schemes and fails on any A/AA violation. See `tests/a11y/`.

### Changed

- **Consolidated the two demo policies into one.** The separate
  "PolicyPress Feature Showcase" was folded into the **Example Security
  Policy**, which already demonstrates every shortcode, callout, diagram,
  redaction, and compliance mapping in context — so there is a single reference
  policy rather than two overlapping ones. Its taxonomy mappings were merged in
  to preserve coverage.
- Bumped `zigmark` to v0.8.0 and `pozeiden` to v0.3.0. Both upstream releases
  were written as production security & quality hardening rounds *for*
  PolicyPress, and PolicyPress now inherits their input caps and injection
  hardening: zigmark's 16 MiB / 128-depth parser caps and escaped-SVG-attribute
  emission, and pozeiden's 4 MiB input / 1000-node / 2000-edge diagram caps and
  thread-safe internals. No PolicyPress source changes were required; both APIs
  are additive.

### Fixed

- **Compliance coverage percentages are now computed honestly** (#119). The
  SOC 2 TSC and SCF report bars counted *distinct taxonomy terms used* as the
  numerator, so a typo'd control ID inflated coverage (and the SCF denominator
  double-counted multi-row controls). Coverage is now "data-file controls with
  at least one mapped policy" over the total number of controls, and the bar is
  clamped so it can never exceed 100%.
- Policy metadata no longer claims a document was "reviewed and approved on" the
  last-reviewed date. It now shows the review date and, separately, the approver
  and version from the latest revision — an approval date and a review date are
  not the same fact.


## [1.4.3] - 2026-07-14

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

### Changed

- Reworked the README and project metadata for launch: unified the product
  description, added a live-demo link, screenshots, a sample PDF, and a "Why
  PolicyPress" comparison; clarified the free-for-noncommercial licensing and
  the commercial path (#118).

### Fixed

- Corrected the theme license declaration in `theme.toml` to PolyForm
  Noncommercial 1.0.0, matching `LICENSE` and the source SPDX headers (#118).
- Repointed the README documentation links to the live docs site
  (`https://policypress.sc2.in`); the previous GitHub Pages URLs 404'd (#118).

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
