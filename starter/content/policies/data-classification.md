---
title: "Data Classification Policy"
description: "Framework for classifying, handling, and protecting organizational data"
date: 2025-01-01
weight: 30
taxonomies:
  SCF:
    - DCH-01
    - DCH-02
    - DCH-03
    - DCH-05
    - DCH-06
    - DCH-19
  ISO27001:
    - A.5.9
    - A.5.10
    - A.5.11
    - A.5.12
    - A.5.13
    - A.8.10
    - A.8.12
extra:
  owner: Security / Legal
  last_reviewed: 2025-01-01
  major_revisions:
    - date: 2025-01-01
      description: Initial policy.
      revised_by: Security / Legal
      approved_by: CEO
      version: "1.0"
---

## Purpose and Scope

This policy establishes a consistent framework for classifying {{ org() }}'s data assets and defines the handling requirements for each classification level. Proper classification ensures that sensitive information receives appropriate protection without creating unnecessary friction for non-sensitive data.

This policy applies to all data created, collected, stored, processed, or transmitted by {{ org() }} or on its behalf, regardless of format or storage location.

## Classification Levels

{{ org() }} uses four data classification levels:

### Public

Information intended for or approved for public release.

**Examples:** Marketing materials, published blog posts, public documentation, job listings

**Handling:** No special controls required. May be shared freely.

---

### Internal

Information for use within {{ org() }} that is not intended for external parties, but would cause minimal harm if inadvertently disclosed.

**Examples:** Internal process documentation, meeting notes, non-sensitive project plans, general company communications

**Handling:**
- Do not share externally without business justification
- Store on {{ org() }}-managed systems
- No encryption required at rest (recommended for portability)

---

### Confidential

Sensitive business information that could cause meaningful harm to {{ org() }} or its customers, partners, or employees if disclosed without authorization.

**Examples:** Customer data, financial records, contracts, security configurations, HR records, source code

**Handling:**
- Access restricted to those with a business need
- Encryption required at rest and in transit
- Do not store on personal devices or unapproved cloud services
- Must be explicitly marked as Confidential when shared

---

### Restricted

The most sensitive information, where unauthorized disclosure could cause severe harm — legal, regulatory, financial, or reputational.

**Examples:**

{% redact() %}
- Authentication credentials and cryptographic key material
- Vulnerability details and penetration test reports
- Acquisition or merger information prior to public disclosure
- Regulated personal data (health records, payment card data, government IDs)
{% end %}

**Handling:**
- Strict need-to-know access; access requests require CISO approval
- Encryption required at rest (AES-256) and in transit (TLS 1.3+)
- Must not be transmitted via email without additional encryption
- Access logged and reviewed monthly
- Disposal requires verified secure deletion or physical destruction

## Classification Responsibilities

| Role | Responsibility |
|---|---|
| Data owner | Assign initial classification at creation; review annually |
| All staff | Handle data according to its classification; report mishandling |
| Security team | Maintain classification guidance; review and audit compliance |
| Legal / Compliance | Advise on regulatory obligations affecting classification |

When in doubt, classify at the higher level and consult the Security team.

## Handling Requirements Summary

| Requirement | Public | Internal | Confidential | Restricted |
|---|:---:|:---:|:---:|:---:|
| Encryption at rest | | | ✓ | ✓ |
| Encryption in transit | | | ✓ | ✓ |
| Access controls | | ✓ | ✓ | ✓ |
| Access logging | | | ✓ | ✓ |
| Secure disposal | | | ✓ | ✓ |
| CISO approval to share | | | | ✓ |

## Data Retention and Disposal

Data must be retained for the minimum period required by law or business need, then securely disposed of. Retention schedules are maintained by Legal.

Secure disposal methods:

- **Electronic data:** Cryptographic erasure or NIST 800-88-compliant wiping
- **Physical media:** Cross-cut shredding (paper) or certified destruction (drives)
- **Cloud data:** Verified deletion per provider's data destruction process

{% admonition(type="note") %}
Personal data subject to privacy regulations (GDPR, CCPA, etc.) has additional retention and disposal requirements. Consult Legal before deleting or retaining personal data beyond its primary use.
{% end %}

## Labelling

Confidential and Restricted documents must be labelled:

- Header or footer on printed documents
- File name prefix or document properties for electronic files (e.g. `[CONFIDENTIAL]`)
- Email subject line prefix when transmitting electronically

## Compliance and Enforcement

Mishandling of classified data — including storing Restricted data in unapproved locations, sharing Confidential data without authorization, or failure to apply required controls — may result in disciplinary action.

Report suspected data mishandling to the Security team immediately.
