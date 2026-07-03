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

### Theme submodule

The GitHub Action (`sc2in/policypress@v1`) handles theme checkout automatically. For Azure DevOps and any custom pipeline that doesn't use the Action, add policypress as a git submodule:

```bash
git submodule add https://github.com/sc2in/policypress themes/policypress
git submodule update --init
```

Zola does not automatically propagate certain files from a theme into the build. After adding the submodule, copy these assets once into your repository and commit them:

```bash
mkdir -p templates/shortcodes
cp -n themes/policypress/templates/shortcodes/*.html templates/shortcodes/

mkdir -p data
cp -n themes/policypress/data/* data/

mkdir -p static
cp -n themes/policypress/static/draft.png static/ 2>/dev/null || true
```

Your pipeline's checkout step must initialize the submodule. The ADO example below already includes `submodules: true`. For a manual GitHub Actions workflow, add the `with` block to the checkout step:

```yaml
- uses: actions/checkout@v4
  with:
    submodules: recursive
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
      - feature/*
  paths:
    include:
      - content
      - config.toml

pr:
  branches:
    include:
      - main
  paths:
    include:
      - content
      - config.toml

variables:
  # Automatically true on main; all other branches produce draft PDFs.
  ${{ if eq(variables['Build.SourceBranchName'], 'main') }}:
    publish: 'true'
  ${{ else }}:
    publish: 'false'
  # Pin to a specific release. Update this when you want to upgrade policypress.
  POLICYPRESS_VERSION: 'v1.4.0'

pool:
  vmImage: ubuntu-latest

stages:
  - stage: Build
    displayName: Build
    jobs:
      - job: BuildSite
        displayName: Build with PolicyPress
        steps:
          - checkout: self
            submodules: true

          - bash: |
              set -euo pipefail
              # Ubuntu 22.04+ requires this before Nix can create user namespaces.
              sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0
              curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
                | sh -s -- install linux --no-confirm \
                    --extra-conf "sandbox = false" \
                    --extra-conf "trusted-users = root vsts"
              . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
              nix --version
            displayName: Install Nix

          - bash: |
              set -euo pipefail
              curl --retry 3 -fsSL \
                "https://github.com/sc2in/policypress/releases/download/$(POLICYPRESS_VERSION)/policypress-x86_64-linux" \
                -o /tmp/policypress
              chmod +x /tmp/policypress
            displayName: Download policypress binary

          - bash: |
              set -euo pipefail
              . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
              nix develop "github:sc2in/policypress/$(POLICYPRESS_VERSION)#ci" --command bash -c "
                set -euo pipefail
                zola build
                if [ '$(publish)' = 'true' ]; then
                  /tmp/policypress -c config.toml -o public/pdfs
                  /tmp/policypress -c config.toml -o public/pdfs --redact
                else
                  /tmp/policypress -c config.toml -o public/pdfs --draft
                  /tmp/policypress -c config.toml -o public/pdfs --draft --redact
                fi
              "
            displayName: Build site and PDFs

          - publish: $(Build.SourcesDirectory)/public
            artifact: WebApp

          - task: AzureStaticWebApp@0
            condition: and(succeeded(), eq(variables.publish, 'true'))
            inputs:
              app_location: public
              output_location: public
              skip_app_build: true
              azure_static_web_apps_api_token: $(deployment_token)
```

Link it to a pipeline in **Azure DevOps → Pipelines → New pipeline** and point it at this file. Store the Azure Static Web Apps deployment token as a pipeline secret variable named `deployment_token`.

> [!NOTE]
> The first run downloads the Nix CI environment (a few hundred MB for Zola, Typst, and fonts), which takes a minute or two. The policypress binary itself is fetched as a pre-compiled release artifact, so no Zig compilation is needed. To upgrade policypress, update the `POLICYPRESS_VERSION` variable. For additional Nix store caching between runs, see [Determinate Systems FlakeHub Cache](https://docs.determinate.systems/flakehub-cache/).

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
