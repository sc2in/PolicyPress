---
title: "Engineering Audit Policy and Procedure"
description: "Procedures for investigating potential internal threats"
date: 2021-10-14
weight: 10
taxonomies:
  TSC2017:
    - CC3.3
extra:
  owner: SC2
  last_reviewed: 2025-04-16
  major_revisions:
    - date: 2021-10-01
      description: Initial version.
      revised_by: Ben Craton
      approved_by: Ben Craton
      version: "1.0"
---

## Purpose

From time to time, an engineering member with deep ties to the system as a whole may be separated from {{ config.extra.organization }}. At that time, depending on the nature of the separation, it may be prudent to perform an audit of the work of that employee prior to, or after, their departure to determine if any suspicious or malicious activity was performed. The purpose of this document is to codify the policy and procedure for performing such an audit.

## Policy

Upon initiating separation of an engineering employee from {{ config.extra.organization }}, engineering leadership will determine if the scope of system access the employee was granted warrants a review of work of the employee.

### Amicable Separation

Should the separation be amicable, an informal review of all recent work should be performed with the employee prior to departure to ensure not only that no suspicious or malicious code was introduced into the code base, but also to hand off the work to be continued and the work needing maintenance is fully understood by the team.

### Hostile separation or termination with cause

Should the separation be hostile, or if the separation was triggered by a "with cause" termination, to reduce risk of retaliation, an audit should be performed according to the process specified in this document. The audit team will be imbued with the authority to pull in necessary resources required to complete the audit and to place a hold on any planned release. Following the audit, a report detailing what was reviewed and what, if any findings, are noted during the review. Action plans will be handed to the engineering group to be completed as soon as possible. At the conclusion of the audit the authority vested in the audit team is dissolved and returned to engineering leadership.

### Scope

Depending on numerous factors surrounding the nature of the separation, a variety of items should be audited. The audit team will determine the scope of the audit upon its creation.

#### Recommended Scope

In general, the following scope should be used by default in the case of an audit.

- A time window of 6 months prior to the separation date
- All pull requests for code made by the employee destined for production (e.g. to develop or release branches)
- All services that the employee had credentials for
- All actions performed in the production infrastructure environment
- All outbound messages made by the employee using company communication methods (e.g. email, chat, etc) with emphasis on attachments
- Targeted review searching for:
  - Suspicious code
  - Non-business functionality (e.g. "Easter eggs")
  - Remote calls to external entities
  - Backdoors

### Default actions

Regardless of any audit or review of the employee, all credentials held by the employee for company provided services will be revoked, disabled, or deleted from their respective systems. Any keys (API, encryption, or otherwise) that may have been viewable by the employee will be regenerated.

## Procedure

### Initial formation

Upon receiving a notice of separation for the employee, engineering leadership will:

- Review the scope of system access and contributions to the code base to determine if a review is necessary
- Review the nature of the separation and determine if an audit is necessary

In the case of a review, engineering leadership will schedule time with the engineering team and the employee prior to departure to walk through all recent work for turnover and security review purposes. This process terminates in such a case.

In the case of an audit, engineering leadership will:

- Immediately revoke all system access of the employee
- Revoke, disable, or delete any credentials for the employee in any company provided service
- Request an audit from the security group
- Recommend team consistency
- Recommend any holds on releases

Upon receiving a request, the security group will appoint an auditor to form, lead, and report on an audit team. This audit team will consist of at least: the auditor, a member of the security group, an engineering leader, general counsel, and a member of human resources. The team will :

- Meet and discuss the scope of the audit, the plan for execution, and any other details required for audit completion
- Decide if additional resources are necessary, and if so, add them to the team.
- Decide if releases which are pending should be put on hold due to a perceived risk.

### Audit

Upon the scope of the audit being decided, the audit should begin immediately with any release hold placed into effect at the same time. The auditor will direct the team in completing the audit in no more than 5 business days without exception from engineering leadership. During the audit, the auditor will maintain a record of:

- Items reviewed along with reviewer and if the item passes inspection or not
- Evidences of the reviewed items
- Any findings on items failing inspection
- Actions performed by the audit team
- Actions recommended by the audit team for the business to take

During the course of the audit, the auditor and audit team may procure additional resources or access to information deemed relevant to the audit without hindrance.

If, during the audit, an exception is requested for releases to not be withheld, the auditor and audit team will convene to determine if the requested release may proceed safely.

### Post-Audit

After all items are reviewed to the satisfaction of the audit team, the auditor will compile a report detailing:

- The purpose of the audit
- Team constituency
- Audit scope
- Audit results
- Recommended actions (if any)

This report will then be reviewed by the audit team and upon approval, be sent to engineering leadership. The report, audit tracking, and evidences will be archived by the security group. At this point, the auditor will declare the audit complete, the team will disband, and any authority granted to the team during the audit will be dissolved.

At the auditor's discretion, a post-mortem on the audit may be held with the audit team to further refine the process.
