---
title: "Access Control Policy"
description: "Procedures for granting access to business and product assets"
date: 2022-03-18
weight: 5
taxonomies:
  TSC2017:
    - CC6.1
    - CC6.2
    - CC6.3
    - CC6.6
  SCF:
    - HRS-05.7
    - HRS-06
    - HRS-06.1
    - HRS-13
    - HRS-13.1
    - HRS-13.2
    - HRS-13.3
    - IAM-01
    - IAM-02
    - IAM-16
    - IAM-17

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

{{ config.extra.organization }} is committed to conducting business in compliance with the HIPAA Security Rule and all applicable laws, regulations and organization policies and procedures. The organization has adopted this policy to ensure that access to electronic protected health information (ePHI), Non-Public Personal Information (NPI), or Personally Identifiable Information (PII) **[Collectively referred to as PII]** is only available to those persons or programs that have been appropriately granted such access.

The scope of this policy covers the unique user identification and password, emergency access, automatic logoff, encryption and decryption, firewall, and remote and wireless access procedures that will apply to electronic information systems that maintain PII to assure that such systems are accessed only by those persons or software programs that have been granted access rights.

## Policies and Procedures

### Unique User Identification and Password

Each user's or workforce member's password must meet the criteria set forth in the [ITSP]({{< ref "/docs/isms/itsp.md#password-management-poilcy" >}}).

### Automatic Lock

Servers, workstations, or other computer systems containing PII repositories must employ inactivity timers or automatic logoff mechanisms as described in the [ITSP]({{< ref "/docs/isms/itsp.md#automatic-lockout-policy" >}}).

### Encryption and Decryption of PII maintained on internal databases

PII at rest and in transit will be escrypted as described in the [ITSP]({{< ref "/docs/isms/itsp.md#encryption-and-decryption-policy" >}}).

### Firewall Use and Remote Access

Firewall and remote access must be configured and managed according to the guidelines specified in the [ITSP]({{< ref "/docs/isms/itsp.md#firewall-and-remote-access-policy" >}}). This includes ensuring that all remote access connections are authenticated and encrypted, and that firewalls are properly configured to protect PII from unauthorized access.

## Access Revocation

When a User leaves {{ config.extra.organization }}, all system privileges immediately cease, and access to {{ config.extra.organization }} information must likewise immediately cease. All {{ config.extra.organization }} information disclosed to Users must be returned or destroyed. All work done by Users for {{ config.extra.organization }} is {{ config.extra.organization }}' property, and it too must remain with {{ config.extra.organization }} when a User departs. For instance, a computer program written for {{ config.extra.organization }} is {{ config.extra.organization }} property and must remain with {{ config.extra.organization }}.

## Default System Access

By default, all Users will be provided with basic information systems services necessary to their job functions. These may, or may not, include electronic mail and word processing capabilities. These basic privileges will vary by job title. The Information Technology Department and management will determine the necessary access privileges. The existence of certain access privileges does not mean that an individual is authorized to have such privileges. Any questions concerning access control privileges should be directed to the Information Technology Department.

## User ID Assignment

Users will be assigned their own unique user-ID to be used to access systems throughout the organization. When a user leaves the organization, the ID will be permanently decommissioned. Re-use of user-IDs is not allowed. User-IDs and related passwords must not be shared with any other individuals (The {{ config.extra.organization }} corporate portal, or other mechanisms for sharing information such as electronic mail or shared folders should be employed). User-IDs are associated with specific people, and are not linked to computer terminals, departments, or job titles. Anonymous user-IDs (such as "guest") are not allowed unless approved in advance by the Information Technology Department.

## Access Approval

The access control approval process is initiated by a worker's manager. The privileges granted will remain in effect until the worker's job changes or the worker's employment ends with {{ config.extra.organization }}. The Information Technology Department must be notified upon either event. All non-workers (contractors, consultants, temporaries, outsourcing firms, etc.) must be approved by a similar process. Control requests and authorization of non-workers is to be initiated by the project supervisor. Non-worker privileges must be revoked through the Information Technology Department immediately when the project is complete, or when the non-workers stop working with {{ config.extra.organization }}. The relevant project supervisor must review the need for the continuing privileges of non-workers every six months.

## Remote Office Security

The Information Technology Department must approve the security conditions of any proposed working environment.Locking cabinets and shredders must be employed if Internal or Confidential information is handled within the facility.

## Approval Required for Access to Internal Systems by Third Parties

Prior to connecting to {{ config.extra.organization }} internal systems via VPN, LAN connections, etc. any third party must be approved and authorized to do so. Written approval must be obtained by the Information Technology Department. These third parties include providers such as software companies, marketing or advertising firms, beta development partners, customers, as well as contractors and consultants working on {{ config.extra.organization }} projects.
Contract Required - Before any third party is given access to {{ config.extra.organization }}' systems, a contract defining the terms and conditions of such access must have been signed by an authorized person at the third party organization and the responsible {{ config.extra.organization }} management. Information Technology Department must approve the terms and conditions of the connection methods.
