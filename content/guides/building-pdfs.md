---
title: Building PDFs for Distribution
weight: 2
description: How to build a PDF from the policies
summary: How to build a PDF from the policies
---

## Prerequisites

The only prerequisite is that you have a working installation of devbox. If you don't have devbox installed, follow the instructions in the [installation guide](@/guides/installation.md).

## Configuration

The PDF is built using the `pandoc` tool and is driven directly from the YAML front matter in each policy. However, the following variables can be set in the `config.toml` site-wide configuration file to customize the PDF output:

```toml
[extra]
policy_root = "policies/_index.md"
organization = "Star City Security Consulting"
logo = "logo.png"
```

- `policy_root` is the path to the root section of the policies. This is usually `content/policies` or `content/standards`.
- `organization` is the name of the organization that the policies and displays on the cover page and in footers.
- `logo` is the path to the logo file relative to the `static` directory. The logo is displayed on the cover page and in headers.

## Building the PDF

From the root of the project, run the following command:

```bash
$> devbox run build-pdf
```

PDFs will be created in the `public/pdf` directory.