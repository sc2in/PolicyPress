---
title: "Access Control Test Policy"
description: "Fixture exercising inline control-ID footnotes (SCF + praxis join)"
date: 2024-11-13
weight: 10
taxonomies:
  SCF:
    - IAC-01
    - DCH-01
  TSC2017:
    - CC1.1
    - CC6.1
extra:
  owner: SC2
  last_reviewed: 2025-02-24
  scope_exclusions:
    - id: NET-02
      reason: "All network defenses are operated by our colocation provider under a shared-responsibility model."
  major_revisions:
    - date: 2025-06-24
      description: Initial version.
      revised_by: Ada Byrne
      approved_by: Ada Byrne
      version: "1.0"
---

## Purpose

Access is least-privilege {{ control(id="IAC-01") }} enforced across all systems.

## Data protection

All data is classified and protected {{ control(id="DCH-01") }} according to its sensitivity.
