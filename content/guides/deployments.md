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

After the build, push `public/` to your static host. For access-controlled deployments (restricting who can view the site), see [Securing Your Repository](@/guides/securing-your-repository.md#deployment-options) first — that guide covers setting up Azure AD SSO, GitHub Pages org access, and Cloudflare Zero Trust.

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

If you need to build outside of CI:

```sh
nix develop github:sc2in/policypress

zola build                                     # static site → public/
policypress -c config.toml -o public           # PDFs → public/pdfs/
policypress -c config.toml -o dist --redact    # redacted PDFs → dist/pdfs/
```
