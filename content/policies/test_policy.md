---
title: "Test Policy"
description: "A policy for testing purposes"
summary: ""
date: 2024-11-13
weight: 10
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
  owner: SC2
  last_reviewed: 2025-02-24
  major_revisions:
    - date: 2025-06-24
      description: Demo revision.
      revised_by: Ben Craton
      approved_by: Ben Craton
      version: "1.1"
    - date: 2024-02-11
      description: Initial version.
      revised_by: Ben Craton
      approved_by: Ben Craton
      version: "1.0"
---

## Introduction

{{ org() }} is committed to testing its policy center.

## Mermaid

{% mermaid() %}
graph TD
A[Start] --> B{Is it a test?}
B -- Yes --> C[Run tests]
B -- No --> D[End]
C --> D
{% end %}

## Redaction

{% redact() %}
This is a test policy for demonstration purposes. It contains sensitive information that should not be disclosed.
{% end %}