---
title: Installation
weight: 0
description: Setting up PolicyPress for your organization
summary: Setting up PolicyPress for your organization
---

PolicyPress builds your policy site and PDFs on every push to `main`. Your policies live in your own repository; PolicyPress is pulled in at build time.

## GitHub: use the template (recommended)

The fastest way to get started on GitHub is the [policypress-template](https://github.com/sc2in/policypress-template) repository. It includes a working pipeline, example policies, and a `config.toml` ready to customize.

1. Click **Use this template → Create a new repository** on the template page.
2. Edit `config.toml` — set `base_url`, `organization`, and `pdf_color` at minimum.
3. Replace `static/logo.png` with your organization's logo.
4. Enable GitHub Pages: **Settings → Pages → Source: GitHub Actions**.
5. Push to `main` — the pipeline builds your PDFs and deploys the site automatically.

The template's workflow builds PDFs on every push and pull request, and deploys the policy site to GitHub Pages on pushes to `main`.

## Manual setup

Use this path if you need Azure DevOps, a custom pipeline structure, or if you started from scratch.

### Repository structure

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

### Pipeline

<div class="tab-group" data-default="GitHub Actions">
<div class="tab-pane" data-tab="GitHub Actions">

Create `.github/workflows/publish.yml`:

```yaml
name: Publish Policies
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:
    inputs:
      draft:
        description: "Stamp PDFs with DRAFT watermark"
        default: "false"
      redact:
        description: "Redact content inside redaction tags"
        default: "false"

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pages: write
      id-token: write
    steps:
      - uses: actions/checkout@v4

      - name: Build site and PDFs
        uses: sc2in/policypress@v1
        with:
          draft_mode: ${{ github.event.inputs.draft || 'false' }}
          redact_mode: ${{ github.event.inputs.redact || 'false' }}

      - uses: actions/upload-artifact@v4
        with:
          name: pdfs
          path: public/pdfs/
          retention-days: 90

      - uses: actions/upload-pages-artifact@v3
        if: github.ref == 'refs/heads/main'
        with:
          path: public/

  deploy:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    permissions:
      pages: write
      id-token: write
    steps:
      - uses: actions/deploy-pages@v4
```

Enable GitHub Pages under **Settings → Pages → Source: GitHub Actions** before the first run.

</div>
<div class="tab-pane" data-tab="Azure DevOps">

Create `azure-pipelines.yml` at the repository root:

```yaml
trigger:
  branches:
    include:
      - main

pool:
  vmImage: ubuntu-latest

parameters:
  - name: draft_mode
    type: boolean
    default: false
  - name: redact_mode
    type: boolean
    default: false

steps:
  - checkout: self

  - bash: |
      set -euo pipefail
      # Install Nix — required for Pandoc, mermaid-filter, and Chromium
      curl --proto '=https' --tlsv1.2 -sSfL https://install.determinate.systems/nix \
        | sh -s -- install linux --no-confirm
      echo '/nix/var/nix/profiles/default/bin' >> "$BASH_ENV"
    displayName: Install Nix

  - bash: |
      set -euo pipefail
      FLAGS=()
      [[ "${{ parameters.draft_mode }}" == "True" ]] && FLAGS+=(--draft)
      [[ "${{ parameters.redact_mode }}" == "True" ]] && FLAGS+=(--redact)
      nix develop github:sc2in/policypress --command bash -c "
        zola build
        policypress ${FLAGS[*]:-} -c config.toml -o public
      "
    displayName: Build site and PDFs

  - publish: $(Build.SourcesDirectory)/public/pdfs
    artifact: pdfs

  - publish: $(Build.SourcesDirectory)/public
    artifact: site
```

Link it to a pipeline in **Azure DevOps → Pipelines → New pipeline**, point it at this file, and set it to trigger on changes to `main`.

> [!NOTE]
> The first run downloads the Nix environment (~1–2 GB). Subsequent runs are faster if you configure a Nix binary cache. See the [Determinate Systems docs](https://docs.determinate.systems/flakehub-cache/) for caching options compatible with ADO agents.

</div>
</div>

### `config.toml`

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

See the [Configuration Reference](@/guides/configuration.md) for all available fields.

## Local editing environment

For live preview while writing policies, run the `serve` app directly — no devshell setup required:

```sh
nix run github:sc2in/policypress#serve
```

This requires [Nix](https://nixos.org/download/). A markdown editor with Git integration ([VSCode](https://code.visualstudio.com/download) or [Zed](https://zed.dev/download)) works well alongside it. See [Live Editing](@/guides/live-editing.md) for details.
