---
title: "Policy Editing"
description: "How to edit the ISMS documentation"
summary: "How to edit the ISMS documentation"
date: 2023-09-07T16:04:48+02:00
lastmod: 2023-09-07T16:04:48+02:00
draft: false
menu:
  guides:
    parent: ""
weight: 810
toc: true
---

## Editing

ISMS documentation is located in `content/docs/isms`.

Editing the repository follows a [standard git](https://uidaholib.github.io/get-git/3workflow.html) model. Any changes to documents are build as artifacts for review. They will be automatically watermarked with "DRAFT."

The master branch is protected and requires a pull request review from the Director of Security to sign off prior to merge if changes are made to any of the ISMS documentation.

## Building

The site is built using Hugo. The build process is automated using Azure Pipelines. The build process is as follows:

1. The site is built using Hugo
1. The PDFs are generated using Pandoc
1. The site is deployed to Azure Static Web Apps

Run `devbox services up` or `pnpm dev` to start the Doks server. The site will be available at `http://localhost:1313`.

### Pipelines

There are two pipelines as part of this repo, both run under the Monhaven project.

- [PDF Builder](https://dev.azure.com/sc2/Monahven/_build?definitionId=429): The docker image containing the tools listed in `devbox.json`. This is to cache the latex and pandoc installations.
- [Security Center](https://dev.azure.com/sc2/Monahven/_build?definitionId=430): The main pipelines file is in the root of this repo. It builds in 3 steps:

  1. Build and publish the web bundle
  1. Build the non-redacted PDFs
  1. Build the redacted PDFs

  If the branch being built is not `master`, no web bundle will be deployed and all PDFs will be watermarked with DRAFT.

### PDF Generation

The PDFs are generated using Pandoc. The script for generating the PDFs is located in `pandoc.sh`. The script is run as part of the Azure Pipelines build process.

```kroki {type=mermaid}
---
title: Merging and Deploying
---
sequenceDiagram
participant U as User
participant GR as Git Repo
participant AP as Azure Pipeline
participant SWA as Static Web App
participant SP as AD Service Principal

U ->> GR: Merge branch into master
GR -X +AP: Trigger build
AP -X SWA: Artifact: Web bundle
U -->> SWA: Acess new build
AP -X -AP: Atrifact: PDF bundles
```