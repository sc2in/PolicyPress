---
title: "Change Control"
description: "Changing or adding additional products to the product line"
date: 2022-11-23
weight: 5
taxonomies:
  TSC2017:
    - CC3.4
    - CC5.1
    - CC8.1
    - CC9.1
  SCF:
    - AST-02.10
    - AST-02.11
    - AST-03
    - AST-03.1
    - AST-03.2
    - AST-04
    - CFG-03.2
    - CFG-03.3

extra:
  owner: SC2
  last_reviewed: 2025-04-16
  major_revisions:
    - date: 2025-02-06
      description: Initial version.
      revised_by: Ben Craton
      approved_by: Ben Craton
      version: "1.0"
---

## Introduction

**General information**

Due to the sensitive nature of the information contained herein, this policy is available only to those persons who have been designated as members of the Change Control Board or who have signed non-disclosure agreements on file with {{ org() }}.

The following employees constitute {{ org() }}' Change Control Board (CCB):

-

The Change Control Policy for {{ org() }} recognizes and affirms the importance of customers, processes, and technology to {{ org() }}.

It is the responsibility of each {{ org() }} manager and employee to safeguard and keep confidential all corporate assets and any and all customer information.

## Scope

This policy covers resource changes (e.g., RAM, CPU, equipment) and internal IT operational changes for Production environments. For product-related and development-related changes, please refer to the [{{ org() }} Secure Agile SDLC Policy and Procedures](@/policies/security/secure-sdlc.md). For convenience, here's an overview of the {{ org() }} Agile Scrum Process:

- Strategic Planning
- Inception Deck Creation (Initiation)
- Leadership Approval of Product/Project
- Feature consideration and evaluation
- Feature Design

- User Story and Backlog Creation (Requirements Analysis)
- Backlog Grooming (Feature Prioritization and requirements refinement)
- Sprint Iteration:

  - Sprint Planning (Final Prioritization, Story Sizing, Story Selection)
  - Daily Scrums
  - Development with Manual Code Review
  - Automated and Manual System Testing
  - Sprint Review
  - Sprint Retrospective
  - Feature Launch/Application Deployment

## Definition

Any modification to our products/services stack or other request that can be reasonably expected to impact availability, stability, or integrity of the production and/or standby environments.

## Governance

Change Control (CC) systems and decisions are authorized through {{ org() }}' Change Control Board (CCB) which consists of various members throughout the organization.

Change Control Team (CCT) membership at a minimum consists of a director (or higher) for: _Security, Platform, and Engineering_. Other managers may be added by CCT as needed.

The {{ org() }} CCT will meet on a regular basis (no less than quarterly) to:

- Inspect current CC risks, procedures, and resources
- Evaluate any new items needed for CC
- Examine any issues that occurred outside of CC
- Determine why these issues were not under CC
- Evaluate process improvements or training opportunities

All decisions will be guided by the {{ org() }} ISMS/PIMS, esspecially the [Data and Business Intelligence Policy]({{ < ref "data-and-bi.md" >}}), [Secure Agile SDLC Policy and Procedures](@/policies/security/secure-sdlc.md) and [Incident Response Policy](@/policies/incident/incident-response-plan.md).

Major decisions of the CCT must be documented in the CCB minutes.

## Process

Changes that are not covered by the [SDLC process](@/policies/security/secure-sdlc.md) for product development or the [escalation process](@/policies/security/escalation/index.md) for customer issues must be submitted to the CCB for review and approval.

The CCB will review the change request and determine if it is a minor or major change.

- **Minor changes** are those that do not require a change to the system architecture or design or do not encure more than $5,000(USD) in annual expense. These changes can be approved by the CCB and implemented without further review.
- **Major changes** are those that require a change to the system architecture or design or encure more than $5,000(USD) in annual expense. These changes must be reviewed and approved by the CCB before they can be implemented.
- **Emergency changes** are those that must be implemented immediately to prevent a system failure or security breach. These changes can be approved by the CCB and implemented without further review, but must be documented and reviewed at the next CCB meeting.

Failure to follow the change control process may result in disciplinary action, up to and including termination of employment.
