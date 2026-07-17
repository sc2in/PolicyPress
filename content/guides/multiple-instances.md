---
title: "Running Multiple PolicyPress Instances"
weight: 12
description: "One central toolchain, one owned repository per program or entity, and audit bundles that roll up to a single oversight dashboard"
summary: "One central toolchain, one owned repository per program or entity, and audit bundles that roll up to a single oversight dashboard"
---

PolicyPress is deliberately repo-shaped: the theme and toolchain live in this
project, each entity's policies live in *their own* repository. That split is
what makes running many instances work — every program, chapter, brand, or
site gets an isolated, owned, auditable policy library, and your central team
(IT, operations, or compliance) gets one upgrade lever across all of them.

## The shape

```text
acme/policypress             ← theme + toolchain (this project, versioned)
program-a/policies           ← program A's repo, from the template
chapter-b/policies           ← chapter B's repo, from the template
brand-c/policies             ← brand C's repo, from the template
…
```

One repository per entity, each created from the
[policypress-template](https://github.com/sc2in/policypress-template). Never
mix entities in one repository: separation is what lets you devolve ownership
to each one, scope access per entity, keep one entity's redaction/branding
rules from leaking into another's, and hand an entity its whole record cleanly
if it ever spins out on its own.

## Pinning and upgrading the theme

Each entity's repo pins PolicyPress in its workflow:

```yaml
- uses: sc2in/policypress@v1        # major pin: bugfixes flow automatically
# or
- uses: sc2in/policypress@v1.5.0    # exact pin: upgrades only when you say so
```

For centrally-managed instances we recommend the **exact pin**. Your upgrade
cadence then becomes a small, verifiable rollout ritual: bump the pin in a
pull request, let CI rebuild, eyeball the preview, merge. Pilot the bump on one
instance first, then roll it out to the rest. The
[CHANGELOG](https://github.com/sc2in/PolicyPress/blob/main/CHANGELOG.md)
tells you what each version changes; the action verifies the release binary
against its published checksums before running it.

## Per-entity branding and policy content

Everything entity-specific lives in their `config.toml` — organization name,
brand colour, logo, classification default, review cadence:

```toml
[extra.policypress]
organization = "Program A"
pdf_color = "#0e90f3"
classification = "Program A - Internal"
review_overdue_days = 365
```

Author a shared baseline policy *library* once, centrally, then tailor it per
entity. The SCF/SOC 2 taxonomy tags carry over unchanged, so every instance
gets coverage reports from day one.

## Audit bundles and central roll-up

Enable the [audit bundle](@/guides/configuration.md) in each entity's
workflow:

```yaml
- uses: sc2in/policypress@v1.5.0
  with:
    audit_bundle: "true"
```

Every build then emits `audit/manifest.json` (per-policy owner, approver,
review date, and PDF hashes), `revisions.json`, and the coverage export. That
directory is your evidence artifact: have central compliance or oversight
collect every instance's bundle on a schedule to aggregate evidence across the
whole organization — no scraping, no screenshots.

## Ownership and access model

- Your central team: maintains the theme and holds write access to each
  entity's repo (or better: PRs from a fork, so the entity's branch protection
  is the approval gate).
- Each entity: owns its repo and its GitHub organization. Policy approval
  stays with *their* approvers in `major_revisions` — you edit, they approve.
- If an entity ever leaves, it's `git` at its simplest: they already own
  everything.

## Keeping review dates honest across instances

The build flags policies whose `last_reviewed` exceeds the configured window,
and the starter workflow runs a weekly scheduled rebuild so the site's
"Review overdue" badges stay current even when nobody pushes. Watch one
dashboard per instance (each site's homepage shows overdue counts), or collect
every instance's `audit/manifest.json` on a schedule and drive a single central
oversight dashboard from the `last_reviewed` fields.
