---
title: "Math Off Policy"
description: "Fixture with TeX math syntax but no extra.math opt-in; math must stay inert"
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
      revised_by: Ada Byrne
      approved_by: Ada Byrne
      version: "1.0"
---

## Purpose

This policy deliberately contains TeX math syntax but never sets extra.math, so
the opt-in gate must leave it inert.

## Formula

The residual risk threshold is $x^2$ and, with math off, the dollar signs must
survive as escaped literal text rather than opening a Typst equation.

Display math like $$E = mc^2$$ must likewise stay literal.
