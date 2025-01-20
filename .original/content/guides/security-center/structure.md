---
title: "Repository Structure"
description: "The structure of the ISMS/PIMS documentation repository"
summary: "The structure of the ISMS/PIMS documentation repository"
date: 2023-09-07T16:04:48+02:00
lastmod: 2023-09-07T16:04:48+02:00
draft: false
menu:
  guides:
    parent: ""
weight: 810
toc: true
---

The respository, located in [Azure DevOps](https://dev.azure.com/sc2/Information%20Security/_git/Security%20Center), is structured as follows:

Listed below are the main directories and files in this repository. Other directories and files may be present, but these are the most important ones.

- `assets` contains the CSS, JS, and images for the web
- `content` contains all of the markdown files
  - `docs/isms` contains the ISMS documentation
  - `news` contains newsletters, blog posts, and other updates the team wants to share
- `data` directory for data files, usually in YAML or JSON format
  - `opencontrols` contains the SOC2 and other controls in [Opencontrol](https://github.com/opencontrol/schemas) format
  - `riskAssessment` contains files to build the risk assessment tables
- `layouts` contains the HTML templates used by Doks to render the web pages
  - `partials` contains the partials used by the templates
  - `news` contains the templates for the news section
  - `docs` contains the templates for the ISMS documentation
  - `shortcodes` contains the shortcodes used in the markdown files
  - `index.html` is the template for the main landing page
- `config`
  - `_default` contains the default configuration for the website
    - `menus` contains the menus for the header and footer
    - `hugo.toml` is the configuration file for Hugo
    - `params.toml` is the configuration file for most tweaks and styling
  - `production` contains the production configuration for the website
- `scripts` contains scripts for generating the compliance report and checking the last review dates
- `static` contains static files that are copied as-is to the final web directory
  - `staticwebapp.config.json` contains the configuration for the Azure Static Web App
- `themes` contains the theme for the PDF generation
- `devbox.toml` is the configuration file for [Devbox](devbox.md)
- `package.json` is the configuration file for npm, required by Doks
- `pandoc.sh` is the script for generating the PDFs
- `pnpm-lock.yaml` is the lockfile for [pnpm](https://pnpm.io/), an npm alternative

Build artifacts are stored in the `public` directory. This directory is ignored by git.