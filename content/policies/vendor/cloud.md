---
title: Cloud Policy
description: The SC2 Cloud Policy
summary: This document outlines guidance for evaluation, selection and management of cloud and SaaS vendors
date: 2025-04-16
weight: 2
taxonomies:
  SCF:
    - "CLD-01"
    - "CLD-07"
    - "PRI-01.6"
    - "PRM-02"
    - "RSK-03"
    - "RSK-09"
    - "RSK-09.1"
    - "TDA-01"
    - "TDA-02"
    - "TPM-01"
    - "TPM-01.1"
    - "TPM-02"
    - "TPM-03"
    - "TPM-04"
    - "TPM-05"
    - "TPM-06"
    - "TPM-08"
    - "TPM-09"
    - "TPM-10"
extra:
  owner: SC2
  last_reviewed: 2025-04-16
  major_revisions:
    - date: 2025-04-16
      description: Initial version.
      revised_by: Ben Craton
      approved_by: Ben Craton
      version: "1.0"
---

## Purpose

This cloud management policy applies to {{ config.extra.organization }} and is intended to
provide guidance for evaluation, selection and management of cloud and SaaS vendors by {{ config.extra.organization }}.

## Evaluating and Selecting Cloud Vendors and Services

Prior to implementation, cloud vendors must be approved by management. Vendors must first be classified, identifying what concerns likely apply based on how that vendor will be used. The importance of the vendor should also be assessed. If circumstances warrant deeper investigation, documentation on the vendor should be gathered and reviewed. Once approved, a contract review is required.

Assessment teams for each cloud vendor/service can vary but should generally include at least one stakeholder who understands how the vendor would integrate with business processes and systems. The team should also include at least one member from our security and/or legal departments.

### Classification

{{ config.extra.organization }} classifies cloud companies into three categories:

- **SaaS vendors** provide an application to the organization that is fully managed by the vendor. Microsoft Office 365 and Dropbox are examples of SaaS vendors.
  - Reviews of SaaS vendors should focus on whether they have the capabilities and capacities needed to support {{ config.extra.organization }} and whether their configuration meets {{ config.extra.organization }}’s minimum security requirements.
  - {{ config.extra.organization }} reassesses SaaS vendors annually.

- **PaaS vendors** provide the ability to implement applications with minimal light coding. Microsoft Azure Pipelines and Heroku are examples of PaaS vendors.
  - Reviews of PaaS vendors should focus on whether they have the capabilities and capacities needed to support {{ config.extra.organization }} and whether their configuration meets {{ config.extra.organization }}’s minimum security requirements. Reviews should include verification that any new capabilities released since the last review are understood and adequately configured.
  - {{ config.extra.organization }} reassesses PaaS vendors annually.
- **IaaS vendors** offer complete environments that allow {{ config.extra.organization }} to build complex environments using modern practices like infrastructure as code. Microsoft Azure and Amazon Web Services are examples of IaaS vendors.
  - Reviews of IaaS vendors should focus on the shared responsibility model offered by each vendor to confirm {{ config.extra.organization }} has appropriate practices in place to meet our requirements within that model.
  - The use of IaaS vendors additionally requires {{ config.extra.organization }} to identify internal roles and responsibilities for working with the vendor, as aligned to the vendor’s responsibility matrix.
  - The environments built within the IaaS-provided infrastructure should be considered part of {{ config.extra.organization }}’s control environment and should be assessed accordingly.
  - {{ config.extra.organization }} reassesses IaaS vendors annually.

## Special Data Rules

Before completing the evaluation process, the nature of the data being used by the vendor should be reviewed. Any vendor working with data classified as [moderate classification level, such as “sensitive” or “confidential”] should be reviewed for both data transmission and storage, as compared to {{ config.extra.organization }}'s data security plan. If the vendor is to work with specific types of data, the following documents should be reviewed prior to providing such data and annually thereafter:

- **PCI data**: PCI DSS Report on Compliance or Attestation of Compliance.
- **Personally identifying information (PII)**: Service Organization Controls (SOC) 2 Type 2 report or, if not available, an ISO 27000 or a Cloud Security Alliance (CSA) Security Trust Assurance and Risk (STAR) certificate.
- **PII on European residents**: SOC 2 Type 2 report or, if not available, an ISO 27000 or CSA STAR certificate, as well as a contractual review to ensure compliance with GDPR.

Reviews of such documentation should verify the vendor is able to meet {{ config.extra.organization }}’s security requirements and raise concerns to the appropriate business unit(s) wishing to work with the vendor. Whatever their role, individuals should face no reprisals for raising such concerns.

To approve the use of a cloud vendor, the leader of a business unit should complete the risk acceptance form at [link to form], documenting accepted risks so they may be entered into the risk register at [link to risk register] before proceeding.

## Documentation

If they exist, the team working with a cloud vendor should obtain any best practices documentation from the vendor—be it an implementation guide, industry benchmarks or hardening templates.

## Terminating Cloud Services

### Termination for Cause

When a vendor relationship must be immediately terminated, the security team should conduct a review to understand how the vendor works with Company’s systems and data so all access can be removed with minimal risk of vendor retaliation. Additionally, the legal team should review the vendor contract(s) to identify any legal or financial risks that may result from cancelling the contract so appropriate actions may be planned.

### Planned Termination

If a termination is scheduled, the security and legal teams should work together with all appropriate technical resources to create a project plan for the termination.

If the relationship is friendly, the vendor should be queried as to whether the plan is lacking any critical elements. If the vendor relationship is unfriendly, it may be necessary to conduct a tabletop exercise so the organization may be better prepared.

### Sunsetting

When vendors are being terminated at the end of their existing contract, replacement vendors should be identified prior to the end of the contract.

Legal should additionally review the contract to identify requirements and verify there will be no surprises past the planned sunsetting.

### Post-Termination

After a vendor is terminated, the security team should work with the legal team to ensure all post-termination elements in any contract are fully executed and any {{ config.extra.organization }} data is properly removed. 

The security team should collect evidence of any data and resource deletion efforts and provide it to the legal team in case it should be needed later.