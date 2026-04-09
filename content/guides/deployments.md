---
title: Deploying to Production
weight: 10
description: Deploying the policy center
summary: Deploying the policy center
---

## GitHub Actions (recommended)

The canonical deployment path is the `sc2in/policypress` GitHub Action. On every push to `main` it builds the static site and all PDFs, then uploads them as artifacts.

See the [installation guide](@/guides/installation.md) for the full workflow definition.

### Deploying the site

The static site is output to `public/` (or the path set by `output_dir`). Deploy it to any static host:

**GitHub Pages** - add a deploy step after the policypress step:

```yaml
- uses: actions/deploy-pages@v4
  with:
    artifact_name: site
```

**Cloudflare Pages / Netlify / Vercel** - point the build output at the `site` artifact path (`public/`).

**Self-hosted** - copy `public/` to any web server capable of serving static files (nginx, Caddy, S3, etc.).

### Distributing PDFs

PDFs are uploaded as the `pdfs` artifact. You can attach them to a GitHub release, copy them to an S3 bucket, or send them directly to auditors.

To generate a redacted build for external distribution while keeping the full build for internal use, trigger the workflow manually with `redact_mode: true`:

```yaml
- uses: sc2in/policypress@main
  with:
    redact_mode: 'true'
```

## Manual / local build

If you need to build outside of GitHub Actions:

```sh
nix develop github:sc2in/policypress

zola build                                     # static site → public/
policypress -c config.toml -o public           # PDFs → public/
policypress -c config.toml -o dist --redact    # redacted PDFs → dist/
```
