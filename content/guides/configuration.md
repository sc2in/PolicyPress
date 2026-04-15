---
title: Configuration Reference
weight: 5
description: All config.toml fields for PolicyPress
summary: Complete reference for every config.toml setting recognized by PolicyPress
---

PolicyPress is configured through a single `config.toml` file at the repository root. It is a [Zola](https://www.getzola.org/documentation/getting-started/configuration/) configuration file. PolicyPress-specific settings live under `[extra.policypress]`, keeping them cleanly separated from theme-level settings in `[extra]`.

## Required fields

These fields must be present or PolicyPress will exit with an error before building anything.

| Field | Location | Description |
|---|---|---|
| `base_url` | top-level | Canonical URL of the published site (e.g. `"https://security.example.com"`) |
| `organization` | `[extra.policypress]` | Organization name — injected into PDFs and via `{{ org() }}` shortcode |
| `logo` | `[extra.policypress]` | Filename of the logo image relative to `static/` (e.g. `"logo.png"`) |
| `pdf_color` | `[extra.policypress]` | Hex accent color used on PDF cover pages (e.g. `"#0e90f3"`) |
| `policy_dir` | `[extra.policypress]` | Path to the policy directory **relative to `content/`** (e.g. `"policies/"`) |

Example minimal configuration:

```toml
base_url = "https://security.example.com"
title = "Example Co Security Center"
compile_sass = true
theme = "policypress"

[[taxonomies]]
name = "SCF"
render = false

[[taxonomies]]
name = "TSC2017"
render = true

[extra.policypress]
organization = "Example Co"
logo = "logo.png"
pdf_color = "#0e90f3"
policy_dir = "policies/"
```

## PDF and build options

| Field | Location | Type | Default | Description |
|---|---|---|---|---|
| `redact_web` | `[extra.policypress]` | bool | `false` | When `true`, renders a redaction bar over `{% redact() %} … {% end %}` blocks on the website. Does **not** affect PDF generation — use `--redact` on the CLI. |
| `show_draft_pdfs` | `[extra.policypress]` | bool | `false` | When `true`, links to draft PDFs appear on the policy index page |

> [!NOTE]
> Draft and redact modes can also be set at build time via GitHub Action inputs or CLI flags (`--draft` / `--redact`). Action inputs always override `config.toml`.

## Site content fields

| Field | Location | Type | Default | Description |
|---|---|---|---|---|
| `lead` | `[extra.policypress]` | string | - | Subtitle shown below the site title on the homepage |
| `policy_root` | `[extra.policypress]` | string | - | Zola internal link to the policies section index (e.g. `"@/reports/scf.md"`) |
| `scf_report_page` | `[extra.policypress]` | string | - | Internal link to the SCF compliance report page |
| `soc2_report_page` | `[extra.policypress]` | string | - | Internal link to the SOC 2 report page |

## Navigation

The main navigation bar is controlled by `[[extra.menu.main]]` entries. Each entry accepts:

| Field | Type | Description |
|---|---|---|
| `title` | string | Display label |
| `url` | string | Target URL |
| `icon` | string | Font Awesome class (e.g. `"fas fa-file-alt"`) |
| `weight` | integer | Sort order - lower numbers appear first |

```toml
[[extra.menu.main]]
title = "Policies"
url = "/policies/"
icon = "fas fa-file-alt"
weight = 10
```

## Team directory

The team page is populated from `[[extra.policyteam.members]]` entries:

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Full name |
| `title` | string | yes | Job title |
| `email` | string | no | Contact email |
| `phone` | string | no | Contact phone |
| `image` | string | no | Filename under `static/` |
| `page` | string | no | Path to a content page for the team member |

## Homepage

The dashboard homepage layout is controlled by `[extra.frontpage]`. All sub-keys are optional - omit any section to hide it.

| Section | Description |
|---|---|
| `[extra.frontpage.hero]` | `title` and `subtitle` for the hero banner |
| `[extra.frontpage.cta]` | Primary call-to-action button: `text` and `url` |
| `[extra.frontpage.secondary_cta]` | Secondary call-to-action button |
| `[extra.frontpage.features]` | Feature cards grid (`title`, `subtitle`, `[[cards]]`) |
| `[extra.frontpage.quick_actions]` | Quick-action tiles (`title`, `subtitle`, `[[actions]]`) |
| `[[extra.frontpage.statistics]]` | Statistics strip - each entry has `number` and `label` |

## Taxonomies

Taxonomies let you cross-reference policies against compliance frameworks. Each taxonomy declared in `config.toml` can appear in policy front matter.

```toml
[[taxonomies]]
name = "TSC2017"    # SOC 2 Trust Services Criteria
render = true       # generates a browseable taxonomy page

[[taxonomies]]
name = "SCF"        # Secure Controls Framework
render = false      # indexed for reports but no public page
```

Values used in policy front matter must match exactly (case-sensitive).

## Social links and Open Graph

```toml
[[extra.menu.social]]
name = "GitHub"
pre  = '<svg …></svg>'   # inline SVG icon
url  = "https://github.com/your-org"
weight = 10
```

Open Graph tags for link previews:

```toml
[extra.open]
enable  = true
image   = "logo.png"        # fallback OG image
og_locale = "en_US"
```

## Footer

```toml
[extra.footer]
info = 'Powered by <a href="…">PolicyPress</a>'

[[extra.footer.nav]]
name   = "Privacy"
url    = "/policies/privacy/"
weight = 10
```

## Standard Zola fields

These standard Zola settings are relevant to PolicyPress deployments:

| Field | Recommended value | Notes |
|---|---|---|
| `compile_sass` | `true` | Required - PolicyPress ships SCSS |
| `theme` | `"policypress"` | Required |
| `build_search_index` | `true` | Powers the site search widget |
| `generate_feeds` | `true` or `false` | Optional Atom feed |
| `minify_html` | `false` | Safe to enable for production |
| `[markdown].smart_punctuation` | `true` | Recommended for policy prose |
| `[markdown].github_alerts` | `true` | Enables `> [!NOTE]` callouts |
| `[markdown].bottom_footnotes` | `true` | Recommended |
