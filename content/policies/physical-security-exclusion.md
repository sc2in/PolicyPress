---
title: "Physical Security Policy"
description: "Physical and environmental security posture for a fully-colocated organization, including the controls formally out of scope."
summary: "This policy documents the organization's physical security posture. Because all infrastructure is colocated with certified providers, several physical controls are formally declared out of scope."
date: 2026-02-01
weight: 20
taxonomies:
  SCF:
    - AST-01
    - AST-02
  TSC2017:
    - CC6.4
extra:
  owner: Ada Byrne
  last_reviewed: 2026-02-01
  scope_exclusions:
    - id: PES-01
      reason: "We operate no physical facilities of our own; all production infrastructure is colocated with SOC 2-certified providers whose physical and environmental protections are inherited under a shared-responsibility model."
    - id: PES-04
      reason: "The organization maintains no offices, server rooms, or facilities requiring physical access control; staff work remotely and all systems are provider-hosted."
  major_revisions:
    - date: 2026-02-01
      description: Initial physical security policy establishing the colocation posture and formally scoping out on-premises physical controls.
      revised_by: Chidi Diallo
      approved_by: Ada Byrne
      version: "1.0"
---

## Purpose and Scope

{{ org() }} does not own or operate any physical data-center or office facilities. All production systems are hosted by colocation and cloud providers that maintain their own certified physical and environmental protections. This policy documents the physical security responsibilities that remain with {{ org() }} and formally records the physical controls that are out of scope as a result.

## Asset Governance

{{ org() }} maintains an authoritative inventory of all information assets {{ control(id="AST-01") }}, including provider-hosted systems, endpoints, and the personnel accountable for each. Asset inventories {{ control(id="AST-02") }} are reviewed quarterly and reconciled against provider billing and access records.

## Provider Responsibility

Physical access to the systems that process {{ org() }} data is governed entirely by our providers' controls, which are evidenced through their SOC 2 Type II reports and reviewed annually as part of vendor due diligence.

## Out-of-Scope Controls

The controls listed in the "Declared Out of Scope" section of this policy do not apply to {{ org() }} because the organization operates no physical premises. Each exclusion is inherited from a certified provider under a shared-responsibility model and is auditable against that provider's attestations.
