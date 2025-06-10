---
title: "Escalation Policy and Procedures"
description: "Procedures for escalating issues from customer-facing staff to engineering"
last_review_date: 2024-02-14
date: 2023-08-25
weight: 10
taxonomies:
  TSC2017:
    - CC3.1
    - CC4.2
    - CC5.1
    - CC5.2
    - CC5.3
    - CC7.3
    - CC9.1
    - A1.2
    - P6.6
extra:
  owner: SC2
  last_reviewed: 2025-04-16
  major_revisions:
    - date: 2023-08-25
      description: Initial version.
      revised_by: Ben Craton
      approved_by: Ben Craton
      version: "1.0"
---

## Introduction

This Customer Support Escalation Policy and Procedures document outlines the practices and procedures that govern the handling of customer technical support and customer success interactions, ensuring the best service and experience for our customers. This policy is complementary to existing terms and conditions governing our Services.

Our objective at {{ org() }} is to deliver timely and high-quality service to our customers, addressing each case in a professional manner that meets customer needs.

{{ org() }} has established the following steps for each issue brought in by a customer:

- Have someone in our customer's corner
- Be proactive when communicating
- Take action
- Follow-up
- Communicate internally

It is the responsibility of each {{ org() }} manager and employee to abide by this escalation policy and contact the appropriate escalation team member in a timely manner in order to keep customer expectations high and deliver the best experience to them that we possibly can.

It is futher the responsiblity of each {{ org() }} business unit to define, maintain, and improve internal escalation procedures relevant to their business objectives and resources in compliance with this policy.

## Definitions

- **Outage:** A service provided by the product has stopped, rendering the product inoperable for a significant customer segment.
- **Defect:** An issue causing the product, partially or wholly, to malfunction.
- **Enhancement / Feature Request:** A customer request for new functionality or modification to existing features.

This escalation policy applies solely to defects and outages.

## Escalation Tier Definitions

The following tiers shall be used in reference to the severity and scope of an issue as it becomes apparent to the {{ org() }} team member handling a customer issue.

### Tier III - Red - Total Outage

A tier III or Red level issue is one that either involves:

1. A widespread product outage in which the product ceases to function and/or
2. A product has been rendered inoperable for a large segment of the customer base.

A situation of this level is the highest severity and will require a prompt response by most or all departments and management staff within {{ org() }}


_Examples: No customers are able to authenticate and login to the product. All eScribe customers are getting a sever error on the main landing page._

### Tier II - Orange - Partial Outage

A tier II or Orange level issue is one in which:

1. A major portion of the product's core functionality has been rendered inoperable, and
2. A large segment of the customer base has encountered the same issue or can be expected to encounter the issue, and
3. Customers are still able to access and use other functionality of the product
4. Or high value customer churn or situations as defined in [Special Cases](#special-cases)  of this document.

A situation of this level is of moderate severity and will required a prompt response by the product team and its support staff.

_Examples: Calendars render incorrect information or are inaccessable._

### Tier I - Yellow

A tier I or Yellow level issue in one in which:

1. A defect has been encountered within the product that affects the product's expected functionality, and/or
2. A single customer or small population of the customer base is encountering the same issue.

A situation of this level is of lowest severity and should not follow the escalation procedures outlined in this document. They should instead follow the standard Bug Process Workflow.

_Examples: Application has a formatting error on the agenda layout. Application button on a seldom used feature stops working._

## Escalation Process

### Overview

The escalation process applies to Tier II and Tier III issues. All other defects follow the Bug Process Workflow.

In brief, an escalation should be triaged by the technical support manager who will alert the customer success leadership as well as the product manager. The product manager will then call an ad hoc meeting with customer success leadership and a lead development representative to assess the situation, validate the issue, and decide on a course of action. Once a decision has been made, this decision will be communicated by the product manager back to customer success leadership and the technical support manager. Should development be required, the product manager will work with the development team to either work a correction into the next release or create a new hotfix release to correct the issue.

### Escalation Procedure

1. **A Customer Issue is Reported:** A customer reports an issue or internal staff identifies a customer-impacting issue. If not reported within the ticketing system, a ticket is opened to document the problem.

2. **Initial Triage:** The reporting team member assesses severity and assigns an escalation tier. Tier II and Tier III issues are escalated to technical support management.

3. **Technical Support Manager:** The technical support manager confirms the issue's severity and decides whether to escalate. If escalated, customer success leadership and the affected product's manager are alerted.

4. **Product Management:** The product manager, along with customer success leadership and lead development representative, assesses severity, cause, and corrective actions.

5. **Issue Validation:** Product management collaborates with development to validate the issue and its impact. A course of action is determined.

6. **No Immediate Action Needed:** If no immediate action is required, the decision is communicated to stakeholders and affected customers.

7. **Immediate Action Required:** If immediate action is necessary, the product manager collaborates with development to address the issue.

8. **Release Scheduling:** For corrective measures requiring product changes, the correction is integrated into the next scheduled release or a hotfix release is considered.

### Internal Communications

- **Immediate Notification:** Frontline support informs the Technical Support Team upon issue detection. Technical Support Team updates the Engineering Team if required.
- **Ongoing Updates:** Regular updates are shared within teams and levels to maintain transparency while the escalation is ongoing.
- **Post-Incident Review:** Within 2 business days of resolution, a retrospective meeting is held to analyze timeline, actions, and improvements for all escalation participants.

### External Communications

- **Customer Notification:** A customer-facing message is drafted acknowledging the issue and providing updates.
- **Regular Updates:** Customers receive regular updates on resolution progress and revised ETR if needed.
- **Resolution Announcement:** Once resolved, a final update is sent to affected customers, highlighting the fix and preventive measures.
- **Press Release:** If the issue is of significant impact, a press release is drafted with assistance from marketing leadership.

Any request for comment about an issue from an inteity that {{ org() }} does not have a prior relationship with, (e.g the media), should be directed to the Chief Marketing Officer.

## Special Cases

For exceptional circumstances, the Technical Support manager may escalate a Tier I issue to a higher tier based on factors like prior relationships, repeated issues, or executive intervention.

## Addenda

### Hotfix Authorization

For any escalated issue for which a hotfix is considered, the Product Manager will consult with an receive authorization for a hotfix from the VP of Product Management and the VP of Engineering.
