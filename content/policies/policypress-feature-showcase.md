---
title: "PolicyPress Feature Showcase"
description: "A reference document demonstrating PolicyPress shortcodes, callouts, diagrams, redaction, and compliance mapping."
summary: "This is not a governing policy. It demonstrates the full range of formatting options available when authoring policies in PolicyPress."
date: 2024-11-13
weight: 999
taxonomies:
  TSC2017:
    - CC2.1
    - P4.1
  SCF:
    - HRS-05
    - HRS-05.1
    - HRS-05.2
    - HRS-05.3
    - HRS-05.4
    - HRS-05.5
extra:
  math: true
  owner: Security Team
  last_reviewed: 2025-02-24
  major_revisions:
    - date: 2025-06-24
      description: Renamed and reframed as feature showcase.
      revised_by: Ben Craton
      approved_by: Ben Craton
      version: "1.1"
    - date: 2024-02-11
      description: Initial version.
      revised_by: Ben Craton
      approved_by: Ben Craton
      version: "1.0"
---

> **This is not a governing policy.** This document is a feature showcase for PolicyPress. It demonstrates custom shortcodes, callouts, diagrams, redaction blocks, and compliance mapping available when authoring policies in Markdown.

## Introduction

{{ org() }} uses PolicyPress to manage its security policies. The `{{/* org() */}}` shortcode injects the organization name configured in `config.toml`, keeping policies portable across deployments.

## Diagrams (mermaid shortcode)

The `mermaid()` shortcode renders flowcharts and sequence diagrams inline on the web page and in PDF output.

{% mermaid() %}
graph TD
A[Start] --> B{Is it a test?}
B -- Yes --> C[Run tests]
B -- No --> D[End]
C --> D
{% end %}

## Math (KaTeX)

Setting `math: true` under `extra` in a page's front matter enables LaTeX math rendering. PolicyPress self-hosts [KaTeX](https://katex.org/) — no third-party CDN is loaded — so math pages work offline and leak no visitor data.

Inline math is wrapped in single dollar signs: the residual risk after applying a control with effectiveness $e$ is $R_{residual} = R_{inherent} \times (1 - e)$.

Display math is wrapped in double dollar signs:

$$Risk = \sum_{i=1}^{n} (Likelihood_i \times Impact_i)$$

Where each $i$ denotes an identified threat scenario, $Likelihood_i \in [0, 1]$, and $Impact_i$ is scored on a scale of $1$ to $5$.

## Internal Links (Zola link replacement)

PolicyPress uses Zola's `@/` link syntax to create portable internal links that work both on the site and in PDF output.

[Example Security Policy](@/policies/example-security-policy.md)

[All Policies](@/policies/_index.md)

## Redaction (redact shortcode)

The `redact()` shortcode wraps content that should not appear in published web output. On the site, a redaction bar is rendered. In PDF output, the `--redact` flag controls whether the content is included.

{% redact() %}
This is a test policy for demonstration purposes. It contains sensitive information that should not be disclosed.
{% end %}
