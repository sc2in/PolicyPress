---
title: "Access Control Policy"
description: "Requirements for granting, managing, and revoking access to systems and data"
date: 2025-01-01
weight: 10
taxonomies:
  SCF:
    - IAC-01
    - IAC-02
    - IAC-06
    - IAC-07
    - IAC-10
    - IAC-15
    - IAC-16
  ISO27001:
    - A.5.15
    - A.5.16
    - A.5.17
    - A.5.18
    - A.8.2
    - A.8.3
    - A.8.5
extra:
  owner: IT / Security
  last_reviewed: 2025-01-01
  major_revisions:
    - date: 2025-01-01
      description: Initial policy.
      revised_by: IT / Security
      approved_by: CEO
      version: "1.0"
---

## Purpose and Scope

This policy establishes requirements for controlling access to {{ org() }}'s information systems, applications, and data. Access shall be granted based on the principle of least privilege - users receive only the access required to perform their job duties.

This policy applies to all employees, contractors, and third parties with access to {{ org() }} systems.

## Access Provisioning

Access requests must be submitted through the approved ticketing system and include:

- Business justification
- System or data being requested
- Access level required
- Duration (permanent or time-limited)
- Approving manager

Access is provisioned only after written approval from the resource owner and the requester's manager.

## Authentication Requirements

| Account Type | Minimum Requirement |
|---|---|
| Standard user accounts | Password + MFA |
| Privileged / admin accounts | Password + MFA + PAM tool |
| Service accounts | Managed credentials (no shared passwords) |
| Third-party / vendor accounts | MFA + time-limited access |

Passwords must meet the following minimum requirements:

- 14 characters or longer
- No reuse of the last 12 passwords
- Changed immediately upon any suspected compromise

## Privileged Access

Privileged accounts (administrator, root, service accounts with elevated rights) are subject to additional controls:

- Separate privileged account from day-to-day user account
- All privileged activity logged and reviewed monthly
- Just-in-time access preferred over standing privilege where technically feasible
- Annual review of all privileged account holders

## Access Reviews

| Scope | Frequency |
|---|---|
| All user access | Quarterly |
| Privileged access | Monthly |
| Third-party / vendor access | Monthly |
| Terminated or transferred users | Within 1 business day |

Access reviews are documented and retained for a minimum of one year.

## Access Revocation

Access must be revoked:

- **Immediately** upon termination (same business day)
- **Within 48 hours** of a role change that removes the need for access
- **Immediately** upon any suspected account compromise

HR is responsible for notifying IT of terminations and role changes on the day they occur.

## Remote Access

Remote access to {{ org() }} systems requires:

- Company-managed device or approved BYOD configuration
- VPN connection for access to internal resources
- MFA for all remote sessions

## Compliance and Enforcement

Violations of this policy may result in disciplinary action up to and including termination. Access violations are logged and reviewed by the Security team.

{% admonition(type="note") %}
Access requests, approvals, and reviews must be retained as evidence for audit purposes. Store records in the approved GRC or ticketing system - email approvals alone are not sufficient.
{% end %}
