---
title: Installation
weight: 0
description: Setting up PolicyPress for your organization
summary: Setting up PolicyPress for your organization
---

PolicyPress builds your policy site and PDFs on every push to `main`. Your policies live in your own repository; PolicyPress is pulled in at build time. It runs as a GitHub Action or as a standalone binary in Azure DevOps pipelines.

## Prerequisites

- A Git repository (GitHub or Azure DevOps)
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

### 2. Add the pipeline

<div class="tab-group" data-default="Azure DevOps">
<div class="tab-pane" data-tab="GitHub Actions">

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
        uses: sc2in/policypress@v1
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

Then link it to a pipeline in **Azure DevOps → Pipelines → New pipeline**, point it at this file, and set the pipeline to trigger on changes to `main`.

> [!NOTE]
> The first run downloads the Nix environment (~1–2 GB). Subsequent runs are faster if you configure a Nix binary cache. See the [Determinate Systems docs](https://docs.determinate.systems/flakehub-cache/) for caching options compatible with ADO agents.

</div>
</div>

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

[extra.policypress]
organization = "Example Co"
logo = "logo.png"
pdf_color = "#0e90f3"
policy_dir = "policies/"
```

### 4. Push to main

The pipeline runs automatically on every push to `main`. PDFs and the static site are uploaded as artifacts. See [Deploying to Production](@/guides/deployments.md) for how to publish the site and ship PDFs to auditors.

## Optional: local editing environment

For live preview while writing policies, you can run the site locally using the PolicyPress devshell:

```sh
nix develop github:sc2in/policypress
zola serve
```

This requires [Nix](https://nixos.org/download/). A markdown editor with Git integration ([VSCode](https://code.visualstudio.com/download) or [Zed](https://zed.dev/download)) works well alongside it.
