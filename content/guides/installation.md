---
title: Installation
weight: 0
description: Setting up PolicyPress for your organization
summary: Setting up PolicyPress for your organization
---

PolicyPress is used as a GitHub Action - there is nothing to install. Your policies live in your own repository and PolicyPress is pulled in at build time.

## Prerequisites

- A GitHub repository (public or private)
- A `config.toml` configured for PolicyPress (see below)
- Your policy files as Markdown in `content/policies/`

## Quickstart

### 1. Create your repository structure

```text
config.toml
static/
  logo.png           ← your organization logo
content/
  policies/
    _index.md
    acceptable-use.md
    access-control.md
```

### 2. Add the workflow

Create `.github/workflows/publish.yml`:

```yaml
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

### 3. Configure `config.toml`

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

### 4. Push to main

The action runs automatically on every push to `main`. PDFs and the static site are uploaded as artifacts.

## Optional: local editing environment

For live preview while writing policies, you can run the site locally using the PolicyPress devshell:

```sh
nix develop github:sc2in/policypress
zola serve
```

This requires [Nix](https://nixos.org/download/). A markdown editor with Git integration ([VSCode](https://code.visualstudio.com/download) or [Zed](https://zed.dev/download)) works well alongside it.
