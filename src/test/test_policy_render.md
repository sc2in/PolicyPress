---
title: "Render Test Policy"
description: "Minimal policy for PDF rendering tests (no mermaid - sandbox-safe)"
date: 2024-11-13
weight: 10
taxonomies:
  TSC2017:
    - CC2.1
  SCF:
    - HRS-05
extra:
  owner: SC2
  last_reviewed: 2025-02-24
  major_revisions:
    - date: 2025-06-24
      description: Initial version.
      revised_by: Ben Craton
      approved_by: Ben Craton
      version: "1.0"
---

## Purpose

{{ org() }} uses this policy to verify that PDF rendering works end-to-end.

## Scope

This policy applies to all automated test runs.

## Redaction

{% redact() %}
This content is redacted in auditor builds.
{% end %}
