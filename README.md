# PolicyPress

[![CI](https://github.com/sc2in/policypress/actions/workflows/ci.yml/badge.svg)](https://github.com/sc2in/policypress/actions/workflows/ci.yml)
[![Latest Release](https://img.shields.io/github/v/release/sc2in/policypress)](https://github.com/sc2in/policypress/releases/latest)
[![License: PolyForm Noncommercial](https://img.shields.io/badge/license-PolyForm%20Noncommercial-blue)](LICENSE)

A compliance policy management platform for small and mid-size businesses. Write policies in Markdown, version them in Git, publish a branded static site, and generate audit-ready PDFs — all from a single GitHub Action.

PolicyPress is built on [Zola](https://www.getzola.org/) and [Pandoc](https://pandoc.org/). It is designed to be hosted by your customers in their own repositories; PolicyPress itself is the theme and toolchain, not the content.

## Who this is for

> *"I run a small business. My employees need an acceptable use policy, a data handling policy, maybe an employee handbook - right now it's a Word doc someone emailed around and nobody knows which version is current. I want something that looks professional, is always current, and doesn't require SharePoint."*

PolicyPress is for that person. If you are comfortable enough with GitHub to click a button and edit a text file, you can have a professional policy library with version-controlled PDFs in an afternoon. You do not need to know anything about web development, LaTeX, or compliance frameworks.

What you get:

- A policy website your employees can bookmark
- A PDF for every policy, named by title and version, ready to hand to an auditor or attach to a vendor questionnaire
- A full revision history:  who approved what, and when
- Draft watermarks for policies under review
- Redaction tags for internal notes that should not appear in distributed copies

## How it works

1. Your policies live in a Git repository as Markdown files
2. On every push, the `sc2in/policypress` GitHub Action builds the policy site and generates PDFs
3. The site deploys to GitHub Pages; PDFs are uploaded as artifacts for download

## Quick start

**The fastest path:** use the [policypress-template](https://github.com/sc2in/policypress-template) repository. Click **Use this template → Create a new repository**, edit `config.toml` with your organization name and brand color, replace the logo, enable GitHub Pages, and push.

If you need Azure DevOps or a custom setup, see the [Installation guide](https://sc2in.github.io/policypress/guides/installation/).

## Policy front matter

Every policy file starts with a YAML metadata block:

```yaml
---
title: "Acceptable Use Policy"
description: "Policy governing acceptable use of company resources"
weight: 10

taxonomies:
  SCF:
    - HRS-05
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
| `output_dir` | `public` | Output directory for the build |
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
[extra.policypress]
scf_controls     = "templates/opencontrols/standards/SCF.yml"
tsc2017_controls = "templates/opencontrols/standards/TSC-2017 (SOC2).yml"
scf_report_page  = "@/reports/scf.md"
soc2_report_page = "@/reports/soc2.md"
```

Control data files are customer-supplied - PolicyPress does not ship them. The format matches the [OpenControl](https://open-control.org/) standard.

## Local development

Requires [Nix](https://nixos.org/download/).

```sh
# Live preview with hot reload (recommended)
nix run github:sc2in/policypress#serve

# Generate PDFs only
nix run github:sc2in/policypress -- -c config.toml -o public

# Generate redacted PDFs
nix run github:sc2in/policypress -- -c config.toml -o public/redacted --redact

# Verbose output (shows pandoc args)
nix run github:sc2in/policypress -- -v -c config.toml -o public

# CI-friendly JSON log output
nix run github:sc2in/policypress -- --json -c config.toml -o public
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
