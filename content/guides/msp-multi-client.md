---
title: "Running PolicyPress for Multiple Clients"
weight: 12
description: "A consultant/MSP playbook: one repository per client, a shared theme pin, and audit bundles for handoffs"
summary: "A consultant/MSP playbook: one repository per client, a shared theme pin, and audit bundles for handoffs"
---

PolicyPress is deliberately repo-shaped: the theme and toolchain live in this
project, your client's policies live in *their* repository. That split is what
makes the consultant/MSP model work — each client gets an isolated, owned,
auditable policy library, and you get one upgrade lever across all of them.

## The shape

```text
sc2in/policypress            ← theme + toolchain (this project, versioned)
client-a/policies            ← client A's repo, from the template
client-b/policies            ← client B's repo, from the template
…
```

One repository per client, each created from the
[policypress-template](https://github.com/sc2in/policypress-template). Never
mix clients in one repository: separation is what lets you hand the whole
thing over cleanly (it is their compliance record), scope access per client,
and keep one client's redaction/branding rules from leaking into another's.

## Pinning and upgrading the theme

Each client repo pins PolicyPress in its workflow:

```yaml
- uses: sc2in/policypress@v1        # major pin: bugfixes flow automatically
# or
- uses: sc2in/policypress@v1.5.0    # exact pin: upgrades only when you say so
```

For managed clients we recommend the **exact pin**. Your upgrade cadence then
becomes a small, billable, verifiable ritual per client: bump the pin in a
pull request, let CI rebuild, eyeball the preview, merge. The
[CHANGELOG](https://github.com/sc2in/PolicyPress/blob/main/CHANGELOG.md)
tells you what each version changes; the action verifies the release binary
against its published checksums before running it.

## Per-client branding and policy content

Everything client-specific lives in their `config.toml` — organization name,
brand colour, logo, classification default, review cadence:

```toml
[extra.policypress]
organization = "Client A GmbH"
pdf_color = "#0e90f3"
classification = "Client A - Internal"
review_overdue_days = 365
```

Author the policy *library* once as your own starter set, then tailor per
client. The SCF/SOC 2 taxonomy tags carry over unchanged, so every client
gets coverage reports from day one.

## Audit bundles in client handoffs

Enable the [audit bundle](@/guides/configuration.md) in each client's
workflow:

```yaml
- uses: sc2in/policypress@v1.5.0
  with:
    audit_bundle: "true"
```

Every build then emits `audit/manifest.json` (per-policy owner, approver,
review date, and PDF hashes), `revisions.json`, and the coverage export.
That directory is your handoff artifact: attach it to the engagement report,
give it to the client's auditor, or feed it to an evidence-collection
platform — no scraping, no screenshots.

## Access model

- Your MSP team: write access to each client repo (or better: PRs from a
  fork, so the client's branch protection is the approval gate).
- The client: owns the repo and the GitHub organization. Policy approval
  stays with *their* approvers in `major_revisions` — you edit, they approve.
- Offboarding a client is `git` at its simplest: they already own everything.

## Keeping review dates honest across clients

The build flags policies whose `last_reviewed` exceeds the configured window,
and the starter workflow runs a weekly scheduled rebuild so the site's
"Review overdue" badges stay current even when nobody pushes. Watch one
dashboard per client (each site's homepage shows overdue counts), or collect
every client's `audit/manifest.json` on a schedule and drive your own
tracking from the `last_reviewed` fields.
