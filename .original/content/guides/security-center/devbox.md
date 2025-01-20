---
title: "Devbox"
description: "Scripts for managing the development environment"
summary: "Scripts for managing the development environment"
date: 2023-09-07T16:04:48+02:00
lastmod: 2023-09-07T16:04:48+02:00
draft: false
menu:
  guides:
    parent: ""
weight: 810
toc: true
---
The repository is configured to use [Devbox](devbox.md) for managing the development environment. This allows for a consistent development environment across all developers and contributors.

### Rationale

Not everyone in the company is technical and not everyone in the company is involved with policy. This is a middleground to allow for a consistent development environment without requiring everyone to be a developer.

Below is the output from `devbox generate readme`:
---


## Getting Started
This project uses [devbox](https://github.com/jetify-com/devbox) to manage its development environment.

Install devbox:
```sh
curl -fsSL https://get.jetpack.io/devbox | bash
```

Start the devbox shell:
```sh 
devbox shell
```

Run a script in the devbox environment:
```sh
devbox run <script>
```
## Scripts
Scripts are custom commands that can be run using this project's environment. This project has the following scripts:

- [Below is the output from `devbox generate readme`:](#below-is-the-output-from-devbox-generate-readme)
- [Getting Started](#getting-started)
- [Scripts](#scripts)
- [Shell Init Hook](#shell-init-hook)
- [Packages](#packages)
- [Script Details](#script-details)
  - [devbox run audit-policy-compliance](#devbox-run-audit-policy-compliance)
  - [devbox run audit-policy-review-dates](#devbox-run-audit-policy-review-dates)
  - [devbox run build-pdfs](#devbox-run-build-pdfs)
  - [devbox run build-pdfs-draft](#devbox-run-build-pdfs-draft)
  - [devbox run build-pdfs-draft-redact](#devbox-run-build-pdfs-draft-redact)
  - [devbox run build-pdfs-redact](#devbox-run-build-pdfs-redact)
  - [devbox run build-site](#devbox-run-build-site)
  - [devbox run ci](#devbox-run-ci)
  - [devbox run clean](#devbox-run-clean)
  - [devbox run create-news](#devbox-run-create-news)
  - [devbox run create-policy](#devbox-run-create-policy)
  - [devbox run initial-setup](#devbox-run-initial-setup)
  - [devbox run update-node-pkgs](#devbox-run-update-node-pkgs)

## Shell Init Hook
The Shell Init Hook is a script that runs whenever the devbox environment is instantiated. It runs 
on `devbox shell` and on `devbox run`.
```sh
test -z $DEVBOX_COREPACK_ENABLED || corepack enable --install-directory "/Users/bcraton/code/SC2/SecurityCenter/.devbox/virtenv/nodejs_18/corepack-bin/"
test -z $DEVBOX_COREPACK_ENABLED || export PATH="/Users/bcraton/code/SC2/SecurityCenter/.devbox/virtenv/nodejs_18/corepack-bin/:$PATH"
echo 'Welcome to devbox!' > /dev/null
```

## Packages

* [pandoc@latest](https://www.nixhub.io/packages/pandoc)
* [yq-go@latest](https://www.nixhub.io/packages/yq-go)
* [gawk@latest](https://www.nixhub.io/packages/gawk)
* [gnused@latest](https://www.nixhub.io/packages/gnused)
* [bash@latest](https://www.nixhub.io/packages/bash)
* [pnpm@latest](https://www.nixhub.io/packages/pnpm)
* [nodejs_18@latest](https://www.nixhub.io/packages/nodejs_18)
* [yq@latest](https://www.nixhub.io/packages/yq)
* github:sc2in/eisvogel-tex#

## Script Details

### devbox run audit-policy-compliance
```sh
./scripts/compliance_check_soc2.sh
```
&ensp;

### devbox run audit-policy-review-dates
```sh
./scripts/review_date_check.sh
```
&ensp;

### devbox run build-pdfs
```sh
./pandoc.sh
```
&ensp;

### devbox run build-pdfs-draft
```sh
./pandoc.sh -d
```
&ensp;

### devbox run build-pdfs-draft-redact
```sh
./pandoc.sh -d -r
```
&ensp;

### devbox run build-pdfs-redact
```sh
./pandoc.sh -r
```
&ensp;

### devbox run build-site
```sh
pnpm build
```
&ensp;

### devbox run ci
```sh
devbox run initial-setup
if [ $PUBLISH == "true" ]; then
devbox run build-site
devbox run build-pdfs
else
devbox run build-pdfs-draft
fi
```
&ensp;

### devbox run clean
```sh
echo Cleaning the project of all build artifacts and node_modules...
rm -rf .direnv node_modules public resources internal .pnpm-store *.err *.log *.core 2>/dev/null
```
&ensp;

### devbox run create-news
```sh
if [ -z "$1" ]; then echo 'Please provide a title for the news post.'; exit 1; fi
echo 'Creating a new news post at $1...'
pnpm run create content/news/$1.md
```
&ensp;

### devbox run create-policy
```sh
if [ -z "$1" ]; then echo 'Please provide a title for the policy document.'; exit 1; fi
echo 'Creating a new policy document at $1...'
pnpm run create content/docs/isms/$1.md
```
&ensp;

### devbox run initial-setup
```sh
pnpm install
```
&ensp;

### devbox run update-node-pkgs
```sh
pnpm update --latest
```
&ensp;



<!-- gen-readme end -->
