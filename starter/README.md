# PolicyPress Starter

A ready-to-use template for managing information security policies with [PolicyPress](https://github.com/sc2in/policypress).

Write policies in Markdown. Push to GitHub. Get a PDF library and a policy website automatically.

## Quick Start

1. **Click "Use this template"** → "Create a new repository"
2. Edit `config.toml` — set `organization`, `base_url`, and drop your `logo.png` in `static/`
3. Push to `main` — the action builds your PDFs and deploys your site

That's it.

## GitHub Action

The [`sc2in/policypress`](https://github.com/sc2in/policypress) action handles everything:

```yaml
- uses: sc2in/policypress@v1
  with:
    config_path: config.toml   # path to your config.toml
    draft_mode: false          # true → DRAFT watermark on all PDFs
    redact_mode: false         # true → redact {% redact() %}...{% end %} blocks
```

On every push to `main` it:
- Compiles all policies to PDF
- Builds the policy website
- Deploys to GitHub Pages
- Uploads PDFs as a build artifact

Draft and redacted builds can be triggered manually via **Actions → Build Policies → Run workflow**.

## Adding a Policy

Copy any `.md` file in `content/policies/` as a starting point. The frontmatter fields that matter:

```yaml
---
title: "Policy Name"
extra:
  owner: Team Name
  last_reviewed: 2025-01-01
  major_revisions:
    - date: 2025-01-01
      description: Initial policy.
      revised_by: Author
      approved_by: Approver
      version: "1.0"
---
```

## Shortcodes

| Shortcode | What it does |
|---|---|
| `{{ org() }}` | Inserts the organization name from `config.toml` |
| `{% redact() %}...{% end %}` | Redacts content when `--redact` is active |
| `{% admonition(type="note") %}...{% end %}` | Callout box (note / tip / warning / important / danger) |

## GitHub Pages Setup

Enable Pages in your repo: **Settings → Pages → Source → GitHub Actions**.

The workflow deploys automatically on every push to `main`.
