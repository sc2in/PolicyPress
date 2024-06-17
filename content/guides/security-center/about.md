---
title: "About the Security Center"
description: "The goal of this repository is to hold all of the ISMS/PIMS documentation in a single source of truth with maximum auditing and review capabilities."
summary: "The goal of this repository is to hold all of the ISMS/PIMS documentation in a single source of truth with maximum auditing and review capabilities."
date: 2023-09-07T16:04:48+02:00
lastmod: 2023-09-07T16:04:48+02:00
draft: false
menu:
  guides:
    parent: ""
weight: 800
toc: true
---

Live site: [https://security.sc2.in](https://security.sc2.in)

The goal of this repository is to hold all of the ISMS/PIMS documentation in a single source of truth with maximum auditing and review capabilities.

The repository is based on [DOKS](https://getdoks.org/) and [Pandoc](https://pandoc.org/). The site is hosted on Azure Static Web Apps within the SC2 Microsoft365 tenant.

## Goals

The point of this repo is to have a single source of truth for ISMS docs. Git is preferred over MS Word doc sharing.

The end goal is to have PDFs automatically publish to selected endpoints. Currently this is manual.

## Rationale

The ISMS documentation is a living document. It is important to have a single source of truth for this documentation. **This repository is that source of truth.**

We subscribe to the idea that content and presentation are separate. The content of the ISMS and PIMS documentation is stored in markdown files for version control, auditing, and review using common, off-the-shelf tools. Presentation is handled by [DOKS](https://getdoks.org/) for the web and [Pandoc](https://pandoc.org/) for PDF generation.

