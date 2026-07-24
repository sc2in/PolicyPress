---
title: Deploying to Production
weight: 10
description: Deploying the policy center
summary: Deploying the policy center
---

## Building the site and PDFs

PolicyPress builds both the static site and all PDFs in a single pipeline run. See [Installation](@/guides/installation.md) for the full pipeline definition (GitHub Actions or Azure DevOps).

The outputs:

- **Static site** → `public/` (Zola output, ready to serve)
- **PDFs** → `public/pdfs/` (one per policy, named by title and version)

## Deploying the site

After the build, push `public/` to your static host. Sites created from the template are **private by default** (`[extra.policypress] private = true`: every page is `noindex, nofollow`, `robots.txt` is `Disallow: /`, and no sitemap is published) and ship a ready-to-fill `static/staticwebapp.config.json` that gates the site behind Azure AD SSO. For access-controlled deployments (restricting *who* can view the site), see [Website visibility](@/guides/securing-your-repository.md#website-visibility) and [Deployment options](@/guides/securing-your-repository.md#deployment-options) first — that guide covers Azure AD SSO, GitHub Pages org access, and Cloudflare Zero Trust.

<div class="tab-group" data-default="Azure Static Web Apps">
<div class="tab-pane" data-tab="Azure Static Web Apps">

Add the deploy step after the build in your pipeline:

<div class="tab-group">
<div class="tab-pane" data-tab="GitHub Actions">

```yaml
- uses: Azure/static-web-apps-deploy@v1
  with:
    azure_static_web_apps_api_token: ${{ secrets.AZURE_STATIC_WEB_APPS_API_TOKEN }}
    repo_token: ${{ secrets.GITHUB_TOKEN }}
    action: "upload"
    app_location: "public"
```

Store the SWA deployment token in **Settings → Secrets and variables → Actions** as `AZURE_STATIC_WEB_APPS_API_TOKEN`. Get the token from the SWA resource in the Azure Portal.

</div>
<div class="tab-pane" data-tab="Azure DevOps">

```yaml
- task: AzureStaticWebApp@0
  inputs:
    azure_static_web_apps_api_token: $(AZURE_STATIC_WEB_APPS_API_TOKEN)
    action: upload
    app_location: public
```

Store the SWA deployment token as a pipeline variable (`AZURE_STATIC_WEB_APPS_API_TOKEN`) in **Pipelines → [your pipeline] → Edit → Variables**. Mark it as secret. Get the token from the SWA resource in the Azure Portal.

</div>
</div>

</div>
<div class="tab-pane" data-tab="GitHub Pages">

Add a deploy step after the build in your GitHub Actions workflow:

```yaml
- uses: actions/deploy-pages@v4
  with:
    artifact_name: site
```

In **Settings → Pages**, set source to **GitHub Actions**.

</div>
<div class="tab-pane" data-tab="Cloudflare Pages">

The simplest option is the [Cloudflare Pages GitHub Action](https://github.com/cloudflare/pages-action):

```yaml
- uses: cloudflare/pages-action@v1
  with:
    apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
    accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
    projectName: your-project-name
    directory: public
```

Or connect your repository directly in the Cloudflare dashboard (Pages → Create a project → Connect to Git). Set the build output directory to `public` and leave the build command blank — PolicyPress pre-builds everything.

</div>
<div class="tab-pane" data-tab="Self-hosted">

Copy `public/` to any web server that can serve static files:

```yaml
- name: Deploy to server
  run: rsync -az --delete public/ user@your-server:/var/www/policies/
```

nginx, Caddy, S3 static hosting, and any CDN that can serve a directory all work. No server-side processing is required.

</div>
</div>

## Distributing PDFs

PDFs land in the `pdfs` artifact (GitHub Actions) or pipeline artifact (Azure DevOps). From there you can:

- Attach them to a GitHub/ADO release for versioned archival
- Copy them to an S3 bucket or SharePoint library for auditor access
- Send them directly to auditors as email attachments

To generate a redacted build for external distribution while keeping the full build for internal use, run the pipeline a second time with `redact_mode: true`:

```yaml
# GitHub Actions — manual trigger with redact_mode: true
- uses: sc2in/policypress@v1
  with:
    redact_mode: 'true'

# Azure DevOps — set parameter at queue time, or add a separate pipeline stage
- bash: policypress --redact -c config.toml -o dist-redacted
  displayName: Build redacted PDFs
```

## Manual / local build

If you need to build outside of CI, use the Nix app (no devshell required):

```sh
# Live preview with hot reload
nix run github:sc2in/policypress#serve

# One-shot build: static site + PDFs
nix run github:sc2in/policypress#preview

# PDFs only
nix run github:sc2in/policypress -- -c config.toml -o public

# Redacted PDFs only
nix run github:sc2in/policypress -- -c config.toml -o dist --redact
```

### Local preview with native control footnotes

If you enable `control_footnotes` (see
[Inline control references](@/guides/compliance-frameworks.md#inline-control-references))
and write native `[^IAC-01]` references, a plain `zola serve` / `zola build`
does **not** synthesise the footnote definitions — those references show as
literal `[^IAC-01]` text, because synthesis happens in the `policypress
stage-site` step that CI runs before Zola. To preview the resolved footnotes
locally, stage first and point Zola at the staged root:

```sh
zola --root "$(policypress stage-site -c config.toml -o .pp-stage)" serve
```

The staged copy is a snapshot: re-run `stage-site` after editing a policy to
pick up the change. The `{{/* control() */}}` shortcode has no such caveat — it
resolves in a plain `zola serve` — so it remains the simplest option for quick
local iteration.
