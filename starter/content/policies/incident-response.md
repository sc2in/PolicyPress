---
title: "Incident Response Policy"
description: "Procedures for detecting, responding to, and recovering from security incidents"
date: 2024-06-01
weight: 20
taxonomies:
  SCF:
    - IRO-01
    - IRO-02
    - IRO-04
    - IRO-06
    - IRO-07
    - IRO-08
    - IRO-10
  ISO27001:
    - A.5.24
    - A.5.25
    - A.5.26
    - A.5.27
    - A.5.28
    - A.6.8
extra:
  owner: Security Team
  last_reviewed: 2025-03-01
  major_revisions:
    - date: 2025-03-01
      description: Added ransomware-specific playbook references and updated escalation contacts.
      revised_by: Security Team
      approved_by: CISO
      version: "1.2"
    - date: 2024-10-15
      description: Revised severity matrix and SLA targets based on lessons learned from Q3 tabletop exercise.
      revised_by: Security Team
      approved_by: CISO
      version: "1.1"
    - date: 2024-06-01
      description: Initial policy.
      revised_by: Security Team
      approved_by: CEO
      version: "1.0"
---

## Purpose and Scope

This policy defines {{ org() }}'s approach to managing security incidents - from initial detection through containment, eradication, recovery, and post-incident review. The goal is to minimize harm, preserve evidence, and prevent recurrence.

This policy applies to all {{ org() }} employees, contractors, and systems.

## Definitions

- **Security Incident**: Any event that threatens the confidentiality, integrity, or availability of {{ org() }} information or systems, or violates security policy
- **Security Event**: An observable occurrence that may indicate a potential incident (not all events are incidents)
- **Critical Incident**: An incident that affects production systems, sensitive data, or regulatory obligations

## Incident Severity

| Severity | Description | Examples | Initial Response SLA |
|---|---|---|---|
| **P1 – Critical** | Significant business or data impact | Active ransomware, confirmed data breach, production system compromise | 15 minutes |
| **P2 – High** | Potential significant impact if not contained | Suspected credential compromise, unauthorized access attempt on sensitive systems | 1 hour |
| **P3 – Medium** | Limited impact, contained | Malware on isolated endpoint, policy violation | 4 hours |
| **P4 – Low** | Minimal impact, informational | Failed phishing attempt with no compromise, suspicious email | 1 business day |

## Incident Response Phases

### 1. Detection and Reporting

Anyone who suspects a security incident must report it immediately to the Security team via the designated incident channel. Do not attempt to investigate or remediate independently.

Sources of detection include:

- SIEM / monitoring alerts
- Employee reports
- Third-party notification (vendor, partner, law enforcement)
- Vulnerability scanner findings
- Threat intelligence feeds

### 2. Triage and Severity Assignment

The on-call Security team member triages the reported event within the SLA above, determines severity, and opens a formal incident ticket.

### 3. Containment

Containment strategy depends on severity:

- **Short-term**: Isolate affected systems, revoke compromised credentials, block malicious IPs/domains
- **Long-term**: Determine root cause before full restoration; preserve forensic evidence

**Do not wipe or rebuild systems** until the Security team has approved evidence collection is complete.

### 4. Eradication

Remove the threat from the environment:

- Identify and eliminate all attacker footholds
- Patch or mitigate the exploited vulnerability
- Reset all potentially compromised credentials

### 5. Recovery

Restore affected systems to normal operation:

- Restore from known-good backups where possible
- Validate system integrity before returning to production
- Monitor restored systems closely for recurrence

### 6. Post-Incident Review

All P1 and P2 incidents require a post-incident review (PIR) within 5 business days of resolution. The PIR documents:

- Timeline of events
- What worked well
- What needs improvement
- Action items with owners and due dates

PIR records are retained for a minimum of 3 years.

## Escalation and Notification

| Condition | Notify | Timeline |
|---|---|---|
| P1 incident | CISO, executive team | Immediately |
| Suspected personal data breach | Legal, DPO | Within 24 hours of discovery |
| Confirmed personal data breach | Regulator (if required) | Per applicable regulation |
| Third-party systems involved | Affected vendor / partner | Within 48 hours |

{% admonition(type="warning") %}
If a breach may involve personal data subject to GDPR, CCPA, or other privacy regulation, notify Legal immediately. Regulatory notification deadlines (e.g. 72 hours under GDPR) begin from the point of discovery, not confirmation.
{% end %}

## Evidence Handling

Evidence collected during an incident must be:

- Documented (what, when, how collected, chain of custody)
- Stored in a secure, access-controlled location
- Retained for a minimum of 1 year (or longer if litigation is anticipated)

Do not share evidence externally without Legal approval.

## Roles and Responsibilities

| Role | Responsibility |
|---|---|
| Security Team | Lead response, coordinate containment and eradication, own PIR |
| IT / Engineering | Provide system access, execute technical remediation |
| Legal / Compliance | Advise on notification obligations, external communications |
| Communications | Manage internal and external messaging for significant incidents |
| All staff | Report suspected incidents immediately; preserve evidence |

## Related Documents

- Incident Response Playbooks (internal wiki)
- Business Continuity Plan
- Data Breach Notification Procedure
