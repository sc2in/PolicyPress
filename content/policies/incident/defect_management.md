---
title: "Defect Management Process"
description: ""
summary: ""
date: 2024-11-13
weight: 10
taxonomies:
  SCF:
    - GOV-01
    - GOV-01.1
    - GOV-01.2
    - GOV-02
    - GOV-02.1
    - GOV-03

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


## Process Objectives

A new process is rolling out in June 2023 to better align Support and Product teams in managing live defects(bugs).​

The process provides:​

- Formalized workflow ​
- Alignment of roles and responsibilities​
- Clear communication channels​
- Guidelines for triaging and prioritizing live defects​
- ​Wider visibility on timeframes for managing defects​

### Key Principles for Managing Live Defects​

- Support teams work to resolve issues without engaging Product Operations​
- ​Prioritization of a defect is based on shared, defined set of parameters​
​- Defects are addressed based on the shared understanding of the priority parameters and expectations.​
- ​Product Owners are the key Product & Engineering points of contact for defects raised by the Support team in P&E teams. (It is no longer the Tech Leads) ​
- ​No Defect is attended to without a support ticket created.

## Roles & Responsibilities

*Note: Technical Leads are not listed here because the Product Owners manage their work. They can be consulted as required, but the Product Owners will plan the work into a sprint. TPS will typically speak to POs before engaging with the Technical Leads.*

### Customer Support

- ​Owns Zendesk ticket until resolved​
- Owns client messaging until resolved​
- Runs initial investigations to resolve​
- Captures steps to reproduce, screenshots + other required information

### Technical Product Support

- Validates the issue​
- Runs deeper investigation to try and resolve​
- Creates the ADO ticket​
- Sets initial Severity level​
- Sets initial Risk of Exposure Level​
- Sets initial Priority level​
- Captures further information if required by engineering​
- Escalates to Teams channel if a P1​
- Runs the Weekly defect meeting

### Product Owner

- Owns the ADO ticket (after created)​
- Triages the defects to validate the Priority​
- Manages the planning of defects into the backlog​
- Manages comms back to the TPS​
- Manages the SLA for the bugs

### Governance Owners

- Oversee the process to ensure teams following process​
- Provides escalation point for missed SLAs​
- Helps manage the P1 escalation process to ensure the right people are assigned to resolving the issue​
- Provides direction as required during defect review meetings

#### Governance/ Escalation Owners



### When, Why , & Who to Contact​

|You are on the…​ | Scenario​ |Who to contact​|
|---|---|---|
| Customer Support team​ | You have a Defect you cannot resolve with the client​ | Technical Product Support team​|
| Technical Product Support team ​ | You have a defect actively troubleshooting or, questions come up from customers/internal that cannot be answered​ | The correct Product Owner based on product area​|
| Technical Product Support team ​| You’re not sure which PO (team) to contact ​| Joe Ranson or Justin Noelle or Liz Drews​|
| Customer Success or Implementation Consultant team​ | You have a customer with a defect that is requesting updates​ | Customer Support team (via Zendesk case) or Technical Product Support team​|
| Any team​ | You have a reported P1 critical issue​ | Technical Product Support team ​|
| Technical Product Support team / Product Owner team​ | You have a reported P1 critical issue​ | Governance Owners (Joe Ranson, Liz Drews, Justin N, Forest E)​|

#### Product Owners by Team

 
|Product Owner​|Team​|Main Areas in the app covered​|
|---|---|---|

## The Defect Workflow

```mermaid
flowchart TB
    ztc["Zendesk Ticket Creation"]
    ztc --> validate
    subgraph "Customer Support"
        validate["Validate + take steps to resolve issue with client"]
        is_resolved["Resolve issue?"]
        manage["Manage client + close Zendesk ticket"]
        
        validate --> is_resolved
        is_resolved --"Yes"--> manage
    end
    subgraph "Technical Product Support"
        validate2["Validate + Investigate"]
        is_resolved2["Resolve Issue?"]
        ado_ticket["ADO Ticket Created"]
        is_urgent["Urgent?"]

        validate2 --> is_resolved2
        is_resolved2 --"Yes"--> manage
        is_resolved2 --"No"--> ado_ticket
        ado_ticket --> is_urgent
    end

    is_urgent --"Yes - P1"--> support_channel
    is_urgent --"No"--> weekly_review
    support_channel["Engineering Support Channel"] --> POP1
    weekly_review["Weekly Defect Review"] --> POSI

    subgraph POSI["Product Operations - Standard Issues"]
        a["Validate + Confirm priority"]
        b["Plan in backlog based on SLA"]
        c["Development, QA Delivery Cycle"]
        d["Update ADO Ticket"]
    end

    subgraph POP1["Product Operations - P1 Urgent Issues"]
        %% A@{ icon: "fa:exclamation-triangle", form: "square", pos: "l", h: 60 }
        e["Follow Critical Incident Process"]
    end

    is_resolved3["Resolved?"] -. "No" .->weekly_review
    is_resolved3["Resolved?"] -. "No" ..->POP1
    is_resolved3["Resolved?"] --"Yes"--->manage2
    POP1 --> is_resolved3
    POSI --> is_resolved3

    manage2["Manage client + close Zendesk ticket"]

    %% classDef customerSupport fill:#ff667f,stroke:#333,stroke-width:1px;
    %% classDef technicalSupport fill:#7f7fff,stroke:#333,stroke-width:1px;
    %% classDef productOwner fill:#ff7f00,stroke:#333,stroke-width:1px;
    %% classDef technicalLead fill:#00007f,stroke:#333,stroke-width:1px;
    %% class validate customerSupport;
    %% class manage customerSupport;
    %% class validate2 technicalSupport;
    %% class ado_ticket technicalSupport;
    %% class ado_ticket technicalSupport;
    
```

## Prioritization

### Setting *Internal* Priority

Use the Priority table below to define an Internal Priority  - Based on Severity of the issue and risk of exposure (i.e. how many users could this potentially impact based on the usage level of the impacted feature)​

We have moved away from % risk exposure as this cannot be quantified. The value of the risk of exposure accepts this is not fully quantifiable either. The Priority is set by TPS and adjusted by Product Owners or TPS due to changes in circumstances.

| Exposure Risk / Severity | 1 (All) | 2 (High) | 3 (Medium) | 4 (Low) |
|--------------:|:-------:|:----------:|:--------:|:------------:|
| **Critical**:​<br/>System/Function is unusable | P1: Critical | P1: Critical | P1: Critical | P1: Critical / P2: High |
| **High**:​​<br/>Users can no longer perform primary work functions | P1: Critical | P1: Critical / P2: High | P2: High | P2: High / P3: Medium |
| **Medium**:​​<br/>Low level Work functions impaired / workaround available | P2: High | P3: Medium | P3: Medium | P4: Low |
| **Low**:​​<br/>Inconvenient | P3: Medium | P4: Low | P4: Low | P4: Low |

- P1: Critical - Hotfix in current sprint
- P2: High - Plan next sprint
- P3: Medium - 3 months
- P4: Low - 6 months review

**When prioritizing, use the table to guide decisions, but take other considerations into account:**

- Size of client/s (ARR)​
- Effort to resolve​
- Security Risk Level​
- Perception to Business​
- Extreme (Rate of calls)​
- Premium paid for features

## Service Level Understandings (SLUs)

SLUs will be agreed upon for defects based on the priority level. They are used to:​

- Provide visibility to teams on when they can expect initial responses, updates, and resolutions​
- Focus on what is important and reduce noise​

|Priority Level​|Initial Response Timeframe​|Response Mechanism​|Resolution Timeframe​|Update Frequency​|
|---|---|---|---|---|
|P1: Critical​ (Outage)​|< 1 Hour​|Update on Teams Channel​|Hotfix in current sprint​|Hourly​|
|P1: Critical​|24 Hours​|Update on Teams Channel​|Hotfix in current sprint​|Daily​|
|P2: High​|1 Week​|ADO Update + weekly call​|Plan into current or next Sprint*​|Weekly​|
|P3: Medium​|1 Month​|ADO update + weekly call​|3 Months​|-​|
|P4: Low​|1 Month​|ADO update + weekly call​|6 month review​|-​|

P3/P4 Tickets will be reviewed every 6 months ​

- IF the defect created date > 9 months AND no new support tickets have been raised, THEN…​
  - EITHER close the Bug and silently close the Zendesk Ticket,
  - OR upgrade it and fix it within 3 months​

If a defect has not been resolved after 9 months and users are not affected, it’s unlikely that the issue is significant enough to warrant prioritization. We will remove it to keep a clean backlog OR choose to fix it in the next 3 months. We won’t keep long-standing defects in the backlog.

## Critical Incident Process

```mermaid
flowchart TB

raise["Defect Raise by Customer / Stakeholder"]
is_outage["Is this an Outage?"]
notify_owners["Immediately Notify all <u>Engineering</u> Owners"]
cs_validate["CS Lead validates with Technical Product Support that Severity is a P1​"]
create_ticket["Gather all info on Defect + Create ADO Ticket​<br/><br/>Mark Ticket as P1"]
notify_owner["Immediately Notify a Governance Owner<br/>(direct call)​"]
post_teams["Post Message to Teams Channel:​<br/>*Engineering  - Support*"]
create_comms["Governance Owners<br/>Ensure clear comms channels in place"]
respond_comms["Governance Owners<br/>Respond on Channel"]
assign_po["Assigned to a PO"]
escalate_c_level["If no response, escalate to CTO and CPO​"]
team_call["Team call arranged"]
action_plan_comms["Action Plan is communicated in Teams Channel​"]
cs_manage["Customer Experience (Support or CSMs) manages client comms until issue is resolved​"]
daily_comms["Daily updates in Teams Channel until resolved or team agrees daily updates are no longer required​"]


raise --> is_outage
is_outage --"Yes"--> notify_owners
is_outage --"No"--> cs_validate

cs_validate --"Yes"--> create_ticket & notify_owner

notify_owners --"Within 1 hour per SLA​"--> post_teams
create_ticket --> post_teams
post_teams --> create_comms
notify_owner --> create_comms
create_comms --Within 24 Hours per SLA​ --> respond_comms
respond_comms --> assign_po
respond_comms -."If no response".-> escalate_c_level
notify_owner -."If no response".-> escalate_c_level
escalate_c_level -.-> assign_po
assign_po --> team_call
team_call --> action_plan_comms
action_plan_comms --> cs_manage
action_plan_comms --> daily_comms
daily_comms --> cs_manage
```

## Appendices

