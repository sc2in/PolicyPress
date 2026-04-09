# PolicyPress

A compliance policy management platform for small and mid-size businesses. Write policies in Markdown, version them in Git, publish a branded static site, and generate audit-ready PDFs - all from a single GitHub Action.

PolicyPress is built on [Zola](https://www.getzola.org/) and [Pandoc](https://pandoc.org/). It is designed to be hosted by your customers in their own repositories; PolicyPress itself is the theme and toolchain, not the content.

## How it works

1. Your policies live in a Git repository as Markdown files with YAML front matter
2. On push, the `sc2in/policypress` GitHub Action builds the static site and generates PDFs
3. Artifacts are uploaded - PDFs for distribution, static site for hosting

Policies support:

- Version tracking with per-revision approval records
- Redaction tags for internal notes that should not appear in distributed PDFs
- Draft watermarks for review copies
- Compliance framework mapping (SCF, SOC 2 TSC, ISO 27001, and any custom taxonomy)

## Quick start

Create a repository with this structure:

```text
config.toml
static/
  logo.png
content/
  policies/
    _index.md
    acceptable-use.md
```

Add a workflow:

```yaml
# .github/workflows/publish.yml
name: Publish Policies
on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      draft_mode:
        type: boolean
        default: false
      redact_mode:
        type: boolean
        default: false

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build site and PDFs
        id: policypress
        uses: sc2in/policypress@main
        with:
          draft_mode: ${{ inputs.draft_mode || 'false' }}
          redact_mode: ${{ inputs.redact_mode || 'false' }}

      - uses: actions/upload-artifact@v4
        with:
          name: pdfs
          path: ${{ steps.policypress.outputs.pdf_path }}

      - uses: actions/upload-artifact@v4
        with:
          name: site
          path: ${{ steps.policypress.outputs.site_path }}
```

Add a minimal `config.toml`:

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

[extra]
organization = "Example Co"
logo = "logo.png"
pdf_color = "#0e90f3"
policy_dir = "policies/"
redact = false
```

### Policy front matter

```yaml
---
title: "Acceptable Use Policy"
description: "Policy governing acceptable use of company resources"
date: 2024-01-15
weight: 10

taxonomies:
  SCF:
    - HRS-05
    - HRS-05.1
  TSC2017:
    - CC2.1

extra:
  owner: Jane Smith
  last_reviewed: "2025-01-15"
  major_revisions:
    - date: "2025-01-15"
      description: Annual review.
      revised_by: Jane Smith
      approved_by: John Doe
      version: "1.2"
---

Policy content goes here.

{% redact() %}
Internal notes - stripped from redacted PDFs.
{% end %}
```

## Action inputs

| Input | Default | Description |
| --- | --- | --- |
| `config_path` | `config.toml` | Path to Zola config file |
| `output_dir` | `public` | Output directory for PDFs |
| `draft_mode` | `false` | Stamp PDFs with a DRAFT watermark |
| `redact_mode` | `false` | Strip content inside redaction tags |

## Action outputs

| Output | Description |
| --- | --- |
| `pdf_path` | Directory containing generated PDFs |
| `site_path` | Directory containing built static site (`public/`) |
| `report_path` | Directory containing compliance reports |

## PDF output

PDFs are named `{Title}_-_v{version}.pdf`. With `redact_mode: true`, the name becomes `{Title}_(Redacted)_-_v{version}.pdf`. With `draft_mode: true`, it becomes `{Title}_(Draft)_-_v{version}.pdf`.

PDFs are generated using the [Eisvogel](https://github.com/Wandmalfarbe/pandoc-latex-template) Pandoc LaTeX template via XeLaTeX.

## Compliance reports

The site includes optional compliance coverage views. To enable them, add your control data files and configure the paths:

```toml
[extra]
scf_controls     = "templates/opencontrols/standards/SCF.yml"
tsc2017_controls = "templates/opencontrols/standards/TSC-2017 (SOC2).yml"
scf_report_page  = "@/reports/scf.md"
soc2_report_page = "@/reports/soc2.md"
```

Control data files are customer-supplied - PolicyPress does not ship them. The format matches the [OpenControl](https://open-control.org/) standard. Example files for SCF and SOC 2 are available in the policypress repository under `templates/opencontrols/standards/` for reference.

## Local development

Requires [Nix](https://nixos.org/download/). The devshell provides Zola, Pandoc, XeLaTeX, ImageMagick, mermaid-filter, and Zig.

```sh
nix develop github:sc2in/policypress

# Build the static site
zola build

# Generate PDFs
policypress -c config.toml -o public

# Generate redacted PDFs
policypress -c config.toml -o public/redacted --redact

# Preview with live reload
zola serve
```

### Building from source

```sh
git clone https://github.com/sc2in/policypress
cd policypress
nix develop
zig build
zig build test
```

## Dependencies

| Dependency | Purpose |
| --- | --- |
| [Zola](https://www.getzola.org/) | Static site generator |
| [Pandoc](https://pandoc.org/) | PDF generation |
| [Eisvogel](https://github.com/Wandmalfarbe/pandoc-latex-template) | PDF template |
| [zigmark](https://github.com/sc2in/zigmark) | YAML/TOML frontmatter parsing |
| [tomlz](https://github.com/tsunaminoai/tomlz) | TOML config parsing |
| [zap](https://github.com/zigzap/zap) | Local preview server |
| [clap](https://github.com/Hejsil/zig-clap) | CLI argument parsing |
| [mvzr](https://github.com/mnemnion/mvzr) | Regex for markdown transforms |
| [zig-datetime](https://github.com/frmdstryr/zig-datetime) | Date handling |

## Credits

PolicyPress is developed and maintained by [Star City Security Consulting, LLC (SC2)](https://sc2.in).

**Primary contributors:**

- [Ben Craton](https://github.com/TsunamiNoAi) - architecture, implementation, security design

**With assistance from:**

- [Perplexity.ai](https://www.perplexity.ai) - research assistance
- [Github Copilot](https://copilot.github.com/) - pair programming and code review
- [Claude](https://claude.ai) (Anthropic) - pair programming and code review

**Built on:**

- [Zola](https://www.getzola.org/) - static site generator
- [Eisvogel](https://github.com/Wandmalfarbe/pandoc-latex-template) - PDF template by Pascal Wagler
- [Secure Controls Framework (SCF)](https://securecontrolsframework.com/) - control taxonomy
- [AICPA Trust Services Criteria (TSC)](https://www.aicpa-cima.com/resources/landing/2017-trust-services-criteria) - SOC 2 control framework

## License

[PolyForm Noncommercial License 1.0.0](LICENSE)

Copyright © 2026 Star City Security Consulting, LLC (SC2) - [sc2.in](https://sc2.in)

Free for noncommercial use including personal projects, research, education, nonprofits, and government. For commercial licensing, contact [sc2.in](https://sc2.in).
