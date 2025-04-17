---
title: "Business Continuity Plan"
description: "Procedures for continuing business operations in event of disruption"
date: 2022-03-30
draft: false
weight: 10
taxonomies:
  TSC2017:
    - A1.2
    - A1.3
    - CC9.1
extra:
  owner: SC2
  last_reviewed: 2025-04-16
  major_revisions:
    - date: 2024-10-07
      description: Initial version.
      revised_by: Ben Craton
      approved_by: Ben Craton
      version: "1.0"
---

## Introduction

### Purpose

In the event of a disaster which interferes with {{ config.extra.organization }}'s ability to conduct business, this plan is to be used by the responsible individuals to coordinate the business recovery. The plan is designed to contain, or provide reference to, all the information that might be needed at the time of a business recovery.

[Introduction](#introduction) contains general statements about the organization of the plan. It also establishes responsibilities for the testing (exercising), training, and maintenance activities that are necessary to guarantee the ongoing viability of the plan.

[Business Continuity Strategy](#business-continuity-strategy),describes the strategy that {{ config.extra.organization }} will implement to maintain business continuity in the event of a facility disruption. These decisions determine the content of the action plans, and if they change at any time, the plans should be changed accordingly.

[IT Disaster Recovery Plan](#it-disaster-recovery-plan), describes the plan that {{ config.extra.organization }} will implement to help the company recover as quickly and effectively as possible from an unforeseen disaster or emergency which interrupts information systems and business operations (including critical applications, databases, servers, or other required technology infrastructure). It shows what activities and tasks are to be taken, in what order, and by whom to affect the recovery. It also contains all the other information needed to carry out the plan.

### Objectives

The objective of the Business Continuity and IT Disaster Recovery Plan is to coordinate recovery of critical business functions in the event of a facilities (office building) disruption/disaster or an unforeseen disaster or emergency which interrupts information systems and business operations. This can include short or long-term disasters or other disruptions, such as fires, floods, pandemics, earthquakes, explosions, terrorism, tornadoes, extended power interruptions, hazardous chemical spills, and other natural or man-made disasters, as well as interruptions of critical applications, databases, servers, or other required technology infrastructure due to proximate (e.g., {{ config.extra.organization }} systems) or remote (e.g., compromise of a third-party) security attacks such as malware, cyber-attacks, APTs (Advanced Persistent Threats), or data destruction/corruption.

**A disaster is defined as any event that interferes with the organization's ability to deliver essential business services.**

**The priorities in a disaster situation are to:**

1. _**Ensure**_ the safety of employees and visitors in the office buildings.

1. _**Mitigate**_ threats or limit the damage that can be caused by threats.

1. _**Utilize**_ documented plans and procedures to ensure the quick and effective execution of recovery strategies for critical business functions.

### Scope

The Business Continuity and IT Disaster Recovery Plan is limited in scope to recovery and business continuance from a serious disruption in activities due to non-availability of {{ config.extra.organization }}'s facilities and IT systems. The plan includes procedures for all phases of recovery as defined in the Business Continuity Strategy and Disaster Recovery sections of this document.

This plan is not intended to cover major national disasters such as hurricanes, war, or nuclear holocaust. However, it can provide guidance in the event of a large-scale disaster.

### Risk Management Policy

There are many potential disruptive threats which can occur at any time and affect the normal business process and services {{ config.extra.organization }} provides to its customers. We have developed a risk management policy to better understand and analyze where specific risks to {{ config.extra.organization }}'s business lie. This policy also helps to determine appropriate controls, risk mitigation strategies, potential consequences, and remedial actions for each risk. The risk assessment process is conducted annually to ensure the business stays up to date and has a plan for all potential threats.

The risk assessment process is as follows (use the {{ config.extra.organization }} Risk Assessment Template as a tool to aid in this process):

1. Use a brainstorming process to identify the issues, uncertainties, and risks that may be of concern to the business. At this stage, do not worry about the likelihood of it occurring. When done, place these "issues/risks" in the column called Issue/Risk. Optionally, group into common categories. If grouped, place the category label in the column called "Category."

1. Next, review each risk and issue identified and describe it in one to three sentences. In the description, consider threats, vulnerabilities, and impact if the risk is not managed. Place this information in the column called "Risk Description."

1. Consider the impact if the risk is not managed. Consider the scope of the impact (e.g., department, employees, customers, vendors, etc.) and the business, operational, and reputational impact. Rank the level of impact from 1 (Low) to 5 (High).

1. Consider the likelihood of adverse consequences occurring with the current policies, procedures, practices, and technology in place to manage the risks. Rank the likelihood of impact from 1 (Low) to 5 (High).

1. As steps 3 and 4 are completed, the risk assessment will automatically calculate the "Risk Ranking" of the issue/risk by multiplying the impact of the risk by its likelihood of occurrence. The higher the number, the greater the risk to {{ config.extra.organization }}.

1. Identify who or what organization is managing the risk currently. Place the name in the column called "Primary Point of Contact to Mitigate This Risk."

1. Identify how the risk is being managed currently. Consider policies, procedures, technologies, and manual practices. Place the controls in the column called "Current Strategies for Mitigating the Risk."

1. Next, identify who and how the organization is monitoring the controls to ensure the risk is being managed. Place this information in the column called "Description of Monitoring in Place."

1. Finally, review the list for accuracy. Note the risks which scored the highest. Use this as a guide to determine which risks to manage. Consider taking action to manage the risks that have the highest Risk Ranking. Because the priority of risks does not remain constant, the assessment should be regularly updated.

When we identify a risk, we work to understand the potential business impact. If the risk is deemed significantly impactful, we implement controls to mitigate the risk. For example, significant business impact would include things like loss of revenue, loss of productivity, bodily harm, or service degradation.

This process is conducted annually. Results from the 2019 Risk Assessment will be completed and available for review by March 2019. As future risk assessments take place, they will be stored in and accessed through the same place.

After the risk assessment is complete, analysis will be conducted to select controls, systems, and procedures that help {{ config.extra.organization }} to avoid, mitigate, or transfer risk.

## Roles and Responsibilities

The {{ config.extra.organization }} Security and Continuity Team, PSCT, provides direction, decision-making and communication for recovery and/or restoration, which may include the data centers, other facilities and associated equipment and supplies. This is the primary team who is empowered to provide both strategic and tactical direction for managing communication of the emergency when an incident is declared by the appropriate authority. At the time of the incident, the Incident Team leader assumes the lead role. The Incident Command Group maintains a constant presence and authority over the incident until the organization returns to normal operating posture. The table below defines each role, individual assigned, and key responsibilities:

| Command Role| Name| Key Responsibilities|
| -- | -- | -- |
| Incident Command Team Leader| TBD(At Time of Incident)| <ul><li>Serve as the primary point of contact for the Incident Command Team Leader on all disaster related matters related to the incident </li><li>Maintain overall authority and decision-making power throughout the lifespan of the incident </li><li>Be accountable for all decisions, actions, and communications related to the BCP, and DRP</li></ul>|
| BCP and DRP Coordinator| {{<redact>}}Primary: <br/>Alternate: {{</redact>}} | <ul><li>Upon receiving approval to activate the BCP or DRP, review the business process priorities and resources required to sustain operations</li><li>Direct the restoration and recover activities related to affected facilities</li><li>Provide updates to the Incident Command Team relevant to the safe tenancy of facilities affected by an incident</li><li>Provide status of recovery operations and/or impediments</li><li>Document recovery activities utilizing appropriate Appendixes, located in Appendix section of thisdocument</li><li>Perform recovery of system utilizing Appendix D</li><li>Coordinate with the Incident Command Team to continue to evaluate business impact caused by the technology or communications outage</li></ul> |
| Building Management | {{<redact>}}Primary: <br/>Alternates: {{</redact>}} | <ul><li>Coordinate with the Incident Command Team to perform a facility damage assessment and determine the affected asset recovery activities</li><li>Communicate with buildingmanagement vendors to invoke SLAs or other emergency procedures, in support of recovery and/or restoration efforts</li><li>Ensure compliance with HIPAA and any other compliant reporting </li></ul>|
| Finance| {{ config.extra.organization }} Finance Team – {{<redact>}}Primary: <br/>Alternate: {{</redact>}} | <ul><li>Allocates emergency funding as required, at the direction of the Incident Command Team</li><li>Advise the Incident Command Team Leader regarding the potential significant financial lossesresulting from loss businessfunctions and /or IT failure </li></ul>|
| Human Resources/People Operations | {{<redact>}}Primary: <br/>Alternates:{{</redact>}}|<ul><li>Accumulate and report personnel accountability results following theincident </li><li>Coordinate assistance with hospital staff, family members, and theIncident Command Team Leader or the BCP and DRP Coordinator for employees taken to hospitals </li><li>As needed, assist with the sourcing of personnel (temporary orpermanent) from other sites,businesses or third parties </li><li>Source and provide crisiscounseling or other approvedgrievance benefits to personnel and families affected by the disruptiveevent, as identified by the BCP and DRP Coordinator </li></ul> |
| Legal | {{<redact>}} Primary: <br/>Alternate: {{</redact>}} | <ul><li>Advise the Incident Command Team Leader regarding legal implications of crisis decision making,as well as the crisis's effecton contractual/regulatory matters and current litigation </li><li>Serve as liaison for outside legal counsel as required</li><li>Serve as liaison for the insurance company as required </li></ul>|
| Public Relations| {{<redact>}}Primary: <br/>Alternate: {{</redact>}} | <ul><li>Facilitate the means for single and/or mass communicationsamong all members of the Incident Command Team </li><li>Receive, correlate, and archive all communications relevant to the incident </li><li>Convey or deliver messages via the appropriate mean and as directed by the Incident Command Team Leader, to the BCP and DRPCoordinators, executives, and other Stakeholders </li></ul>|

### Changes to the Plan/Maintenance Responsibilities

Maintenance of this plan is the responsibility of the {{ config.extra.organization }} Security and Continuity Team (PSCT)

PSCT is responsible for:

1. Annually reviewing the adequacy and appropriateness of {{ config.extra.organization }}'s Business Continuity and IT Disaster Recovery strategies in a structured and controlled manner, updating the master plan accordingly. (When changes occur, it will involve the use of formalized change control procedures.)

1. Assessing the impact of additions or changes to existing business functions, procedures, equipment, systems, and facilities requirements. Any changes must be fully tested, with adjustments made to any relevant training material.

1. Keeping personnel assignments current, taking into account promotions, transfers, and terminations.

1. Overseeing plan stress testing and updates at least annually.

1. Providing training and education regarding the roles and responsibilities of the Business Continuity and IT Disaster Recovery Plan.

#### Plan Testing Procedures and Responsibilities

PSCT is responsible for ensuring the workability of the {{ config.extra.organization }} Business Continuity and IT Disaster Recovery Plan. The plan shall be tested at least annually in a simulated environment to ensure that it can be appropriately implemented in emergency situations and that the management and staff understand how it is to be executed.

For each planned test, there will be four phases: pre-test planning, test execution, post-test review, and final report presentation. Pre-test planning is essential in identifying the type of test desired, time and budget to dedicate to the test, and any activities or scripts necessary (because each type of test will require something different). Post-test review and final report presentation may be the most valuable part of testing. If a test "fails," it is actually a good thing because it means the team has identified holes in the systems and procedures that can then be rectified before a real incident occurs. Documentation should be updated accordingly, using lessons learned to improve the plan and modify future test accordingly.

Types of tests may include:

- Plan reviews. The PSCT discusses the plan, examining the document in detail to look for missing plan elements and inconsistencies.

- Tabletop tests. Participants are selected to gather in a room and walk-through plan activities step-by-step to discern whether team members know their duties in an emergency. Tabletop tests also help to identify documentation errors, missing information, and inconsistencies.

- Simulation test. This will help determine if the plan and resources are effective in a more realistic situation. The test uses established business continuity resources (recovery sites, backup systems, other specialized services) and may potentially send employees to alternate sites to restart technology and business functions to uncover staff issues, task issues, and efficacy. Scripts may be helpful.

#### Plan Training Procedures and Responsibilities

PSCT is responsible for ensuring that the personnel who would carry out the Business Continuity and IT Disaster Recovery Plan are sufficiently aware of the plan's details. This may be accomplished in several ways including practice exercises, participation in tests, and awareness programs (see above).

#### Plan Documentation Storage

Copies of this plan will be stored in secure locations to be defined by the company. Each member of the Incident command team, leadership team and PSCT will be given shared access permissions to the document on Office 365 SharePoint. Additionally, backup copies will be stored in a designated binder in a secure location in the office.

### Media

All requests made by members of the media for any information, comments, details, etc., concerning {{ config.extra.organization }} are to be referred to the Public Relations (PR)/Marketing Department. No employee of {{ config.extra.organization }} may speak to the media on behalf of, about, or concerning {{ config.extra.organization }} without the prior consent of the PR Department.

### Financial and Legal Issues

Upon invocation of either section of the plan, financial and legal assessments should be conducted as follows:

#### Financial Assessment

The Financial department shall prepare an initial assessment of the impact of the incident on the financial affairs of the company. The assessment should include:

- Loss of financial documents

- Loss of revenue

- Theft of checkbooks, credit cards, etc.

- Loss of cash

- Cash flow position

- Temporary borrowing capability

- Upcoming payments for taxes, payroll taxes, Social Security, etc.

- Availability of company credit cards to pay for supplies and services required post-disaster

#### Legal Actions

{{ config.extra.organization }}'s legal team and company management will jointly review the aftermath of the incident and decide whether there may be legal actions resulting from the event; in particular, the possibility of claims by or against the company for regulatory violations, etc.

### Insurance

As part of the company's disaster recovery and business continuity strategies, an insurance policy has been put in place. The insurance is a commercial general liability and an umbrella liability insurance policy and can be provided upon request.

## Business Continuity Strategy

### Introduction

This section of the {{ config.extra.organization }} Business Continuity and IT Disaster Recovery Plan describes the strategy devised to maintain business continuity in the event of a facilities disruption. This strategy would be invoked should the {{ config.extra.organization }} primary facility somehow be damaged or inaccessible.

### Relocation Strategy and Alternate Business Site

In the event of a disaster or disruption to the office facilities, the strategy is to recover operations by relocating to an alternate business site. The short-term strategy (for disruptions lasting two weeks or less) is for employees to work remotely (e.g., from home, alternate office, a co-working space, a coffee shop, library, etc.). If a long-term disruption occurs (e.g., major building destruction projected to impact business for greater than two weeks, etc.), the long-term strategy will be to acquire/lease and equip new office space in another building in the same metropolitan area.

### Recovery Plan Phases

Recovery of business activities will include the following:

Assessment of Disaster

1. After a disaster occurs, quickly assess the situation to determine whether to immediately evacuate the building or not, depending upon the nature of the disaster, the extent of damage, and the potential for additional danger.

1. Quickly assess whether any employees in your surrounding area are injured and need medical attention. If you can assist them without causing further injury to them or without putting yourself in further danger, then provide what assistance you can and call for help. If further danger is imminent, then immediately evacuate the building.

1. Evacuate the building in accordance with the building's emergency evacuation procedures, taking appropriate measures to bring personal laptops / machines with you while not subjecting yourself to danger. Use the nearest stairwells. Do not use elevators.

1. Meeting Locations:




1. Depending upon the time and extent of the disaster, employees will be instructed what to do next (e.g., stay at home and wait to be notified again).

1. Inform all team members that no alteration of facilities or equipment can take place until the Building Risk Management or authorities have made a thorough assessment of the damage and given their consent that the building may be entered.

1. Facilitate retrieval of items if necessary. Enter only those areas the authorities give permission to enter.

Activation of Plan

1. When instructed by {{ config.extra.organization }} Management Team, employees should arrange to work remotely (if disaster / damage is short term) or to commute / travel to the alternate site (if disaster / damage is long term).

1. The PSCT team will meet at designated command center location (identify an alternate secure site) or conference call number.

1. The PSCT team will documents all communication and decisions utilizing the following forms and procedures:

   - **[Appendix A: Communications Form](#appendix-a-communications-form)**

   - **[Appendix B: Monitoring Business Recovery Task Progress Form](#appendix-b-monitoring-business-recovery-task)**

   - **[Appendix C: Disaster Recovery Event Recording Form](#appendix-c-disaster-recovery-event-recording-form)**

1. {{ config.extra.organization }} employees should stay available and connected to network communication systems (MS Teams, Zoom, Email, Mobile Phone) to receive further instruction. Delays in waiting for direct communications can have a negative impact on {{ config.extra.organization }}'s ability to recover vital services.

1. Determine flexible working schedules for staff to ensure that client and business needs are met, but also to enable effective use of space and resources.

1. Determine which vital records, forms, and supplies, if any, are missing.

1. Develop prioritized work activities, especially if all staff members or necessary systems are not available.

1. VP Sales (and any PR/Marketing partner) will work together to coordinate communications with customers to notify them of the disaster situation and how {{ config.extra.organization }} is responding. Employees should not contact customers until the VP Marketing / PR team has given directions and scripts / guidance on how to discuss the disaster with customers, to provide assurance that their confidence in {{ config.extra.organization }} should be maintained.

1. Determine equipment and/or supplies restoration and recovery requirements.

### Continuation of Business and Transition to Normal Activities

1. Determine when company will be able to relocate back to the primary site and communicate this schedule to all employees.

1. Inventory vital records, equipment, supplies, and other materials, which need to be transported from the alternate site to the primary site.

1. Pack, box, and identify all materials to be transported back to the primary site.

#### Reconstitution Phase

The Reconstitution Phase identifies the actions taken to test and validate system capability and functionality. During Reconstitution, recovery activities are completed and normal system operations are resumed. If the original facility is unrecoverable, the activities in this phase can also be applied to preparing a new permanent location to support system processing requirements. This phase consists of two major activities: validating successful recovery and deactivation of the plan. Validation of recovery typically includes these steps:

- Concurrent Processing - Concurrent processing is the process of running a system at two/separate locations concurrently until there is a level of assurance that the recovered system is operating correctly and securely.

- Validation Data Testing - Data testing is the process of testing and validating recovered data to ensure that data files or databases have been recovered completely and are current to the last available backup.

- Validation Functionality Testing - Functionality testing is a process for verifying that all system functionality has been tested, and the system is ready to return to normal operations.

At the successful completion of the validation testing, the Incident Command Team Leader will be prepared to declare that reconstitution efforts are complete and the system is operating normally.

### Vital Records Backup

All vital records for {{ config.extra.organization }} that would be affected by a facilities disruption are maintained and controlled by PSCT, as described individually below in the Crucial Systems Backup Strategy.

### Online Access to {{ config.extra.organization }} Systems

See [IT Disaster Recovery Plan](#it-disaster-recovery-plan)

## IT Disaster Recovery Plan

### Information Technology Statement of Intent / Introduction

This section of the document delineates {{ config.extra.organization }}'s policies and procedures for IT disaster recovery, as well as our process-level plans for recovering all critical and essential technology platforms and infrastructure. This document summarizes our recommended procedures. In the event of an actual emergency, modifications to this document may be made to ensure physical safety of people, systems, and data. Additionally, and as noted in Section I, the IT Disaster Recovery Plan will be tested at least annually in a simulated environment to ensure that it can be appropriately implemented in emergency situations and that the management and staff understand how it is to be executed. The mission in implementing the IT Disaster Recovery Plan is to ensure information system uptime, data integrity and availability, and business continuity.

### Objectives

The principal objective of the IT Disaster Recovery Plan is to document a well-structured and easily understood plan that will help the company recover as quickly and effectively as possible from an unforeseen disaster or emergency which interrupts information systems and business operations. Additional objectives include the following:

- The need to ensure that all employees fully understand their duties in implementing such a plan

- The need to ensure that operational policies are adhered to within all planned activities

- The need to ensure that proposed contingency arrangements are cost-effective

- The need to ensure disaster recovery capabilities are applicable to key customers, vendors, and others

### Crucial Systems and Backup Strategy

Key business processes and the agreed backup strategy for each are listed below.

| **Crucial Systems**            | **System Purpose**                                     | **Backup Strategy**                                                             |
| ------------------------------ | ------------------------------------------------------ | ------------------------------------------------------------------------------- |
| Azure                          | Hosts the  application and database             | Fully mirrored recoverysite with data stored inseparate regions. Works remotely |
| Office 365                     | Email, Calendars, Contacts, OneNote, Teams, SharePoint | Fully mirrored recoverysite with data stored inseparate regions. Works remotely |
| Sophos Firewall - Indianapolis | Firewall and VPN                                       | Contact Accelerate                                                              |
| Level365                       | Cloud-based telephony system                           | Works remotely                                                                  |
| Salesforce                     | Cloud-based CRM system                                 | Works remotely                                                                  |
| Zendesk                        | Cloud-based ticketing system                           | Works remotely                                                                  |
| Dashlane                       | Could-based Password Manager                           | Works remotely                                                                  |
| Local file shares              | Internal business documents                            | Recover from iDrive                                                             |

## Recovery Plan Phases

Recovery of IT systems will include the following:

### Assessment of disaster

1. After an IT disaster occurs, the PSCT will quickly assess the situation to identify the extent of the disaster and determine the extent to which the plan must be invoked.

1. PSCT will contact emergency services if necessary.

1. In fully assessing the extent of the disaster, PSCT will assess its impact on the business, data center, etc.

1. Ensure employees are notified of the disaster situation. (Members of the management team will have SharePoint access to a document with the names and contact information of each employee in their departments that is maintained regularly.)

1. PSCT and management team members will have access to the company's disaster recovery and business continuity plans via Office 365 SharePoint if the headquarters building is inaccessible, unusable, or destroyed, and will use the document to activate plans.

### Activation of plan

1. Upon declaration of plan activation from the Incident Command Team Leader allocate responsibilities and activities as required to maintain vital services (if possible) and recover key systems (see [Appendices](#appendices)). Goal should be to restore key services within 4.0 business hours after the incident.

1. Goal is to recover the business as usual within 8.0 to 24.0 hours after the incident via the following forms and procedures:

   1. [Appendix A: Communications Form](#appendix-a-communications-form)
   1. [Appendix B: Monitoring Business Recovery Task Progress Form](#appendix-b-monitoring-business-recovery-task)
   1. [Appendix C: Disaster Recovery Event Recording Form](#appendix-c-disaster-recovery-event-recording-form)
   1. [Appendix D: Contact Information](#appendix-d-contact-information)

**Note:** In the event of a facilities disruption, the IT Disaster Recovery Plan strategy should be activated to assist in establishing remote communications to any alternate business site location.

Continuation of business and transition to normal activities: As systems are recovered, network connectivity is established, and business services are performed in line with normal activities (including security), the PSCT will prepare a report as shown in [Appendix E](#appendix-e-disaster-recovery-activity-report)(below) to give a proper retrospective of the disaster, how it impacted the business, how the business was stewarded and managed throughout the event, and where any areas of opportunity or weakness lie.

---

## Appendices

### Appendix A: Communications Form

During disaster recovery efforts, it is essential that all affected employees, partners, clients, and other relevant organizations are kept properly informed. The information given to each party must be both accurate and timely. Specifically, any estimate of the timing to return to normal operations should be announced with care. It is also essential that only authorized personnel deal with media queries, or that employees wait for guidance from Public Relations PSCT team member before speaking with anyone outside of the company.

The below form outlines the relevant parties to contact, as well as who should oversee said outreach.

| **Groups of Persons or Organizations Affected by Disruption** | **Communications Coordinator for Affected Persons/Organizations** |**Contact Details**|
| -- | -- |  -- |
| Customers| CustomerSuccess Team| Within Salesforce      |
| Management and Staff| IT| MS Teams, email, phone |
| Suppliers| IT| Sharepoint|
| Media| Sales| VP of Sales|
| Stakeholders- Partners- Investors- Board of Directors| CEO| With CEO|

<br/>

| **Organization**| **Name**| **Number**| **Notes** |
| -- | -- | -- | -- |

### Appendix B: Monitoring Business Recovery Task

The progress of recovery must be monitored closely during this period to stay on track with recovery efforts and timelines. Since difficulties experienced by one group could significantly affect other dependent tasks, it is important to ensure that each task is adequately resourced and that the efforts required to restore normal business operations have not been underestimated. As such, although activities will be carried out simultaneously where possible, a priority sequence must be identified.

| Recovery Tasks (Order of priority) | Person(s) Responsible | Estimated Completion Date | Actual Completion Date | Milestones Identified | Other Relevant Information |
| ---------------------------------- | --------------------- | ------------------------- | ---------------------- | --------------------- | -------------------------- |
| 1.                                 |                       |                           |                        |                       |                            |
| 2.                                 |                       |                           |                        |                       |                            |
| 3.                                 |                       |                           |                        |                       |                            |
| 4.                                 |                       |                           |                        |                       |                            |
| 5.                                 |                       |                           |                        |                       |                            |
| 6.                                 |                       |                           |                        |                       |                            |
| 7.                                 |                       |                           |                        |                       |                            |

---

### Appendix C: Disaster Recovery Event Recording Form

The Disaster Recovery Event Record log will be maintained by the PSCT to create a record of all key events that occur during the disaster recovery phase. The event log should be started at the declaration of the disaster and corresponding invocation of the plan.

<table>
  <tr><th>Description of Disaster:</th><td></td></tr>
  <tr><th>Commencement Date: </th><td></td></tr>
  <tr><th>Date/Time DCST Mobilized:</th><td></td></tr>
</table>
<br/>

| Activities Undertaken by DCST | Date and Time | Outcome | Follow-On Action Required |
| ----------------------------- | ------------- | ------- | ------------------------- |
|                               |               |         |                           |
|                               |               |         |                           |
|                               |               |         |                           |
|                               |               |         |                           |
|                               |               |         |                           |
|                               |               |         |                           |

<br/>
<table>
  <tr><th>Disaster Recovery Work Completed:</th><td>&lt;Date&gt;</td></tr>
</table>

---

### Appendix D: Contact Information

{{<redact>}}

| **Name/Position**                         | **Number**   |
| ----------------------------------------- | ------------ |


{{</redact>}}

---

### Appendix E: Disaster Recovery Activity Report

Once the disaster is declared over, all systems / facilities have been recovered, and normal business activity has resumed, the PSCT should prepare a report on all the activities undertaken. The report should contain information on the disaster / emergency, who was notified and when, what actions were taken, and the outcomes that arose from those actions. The report should also contain an assessment of the impact to normal business operations, as well as of the effectiveness of the Business Continuity and Disaster Recovery Plan and the lessons learned from carrying it out. If there were any issues with the plan or processes encountered, the report should identify them and provide suggestions for enhancing the plan. The report will be shared with {{ config.extra.organization }} management and stored with the Business Continuity and Disaster Recovery Plan for future reference. It will also be used to update the plan accordingly.

**Report Checklist:**

- Description of disaster

- Parties notified of the emergency (including by whom and on what date)

- Notification to insurance company and/or legal services

- Actions taken during recovery efforts

- Outcomes arising from actions taken

- Assessment of the impact to normal business operations

- Assessment of the effectiveness of the Business Continuity and Disaster Recovery Plan

- Problems identified

- Suggestions for enhancing the Business Continuity and Disaster Recovery Plan

- Lessons learned

---

### Appendix F: Pandemic Plan

To mitigate disruption due to a pandemic, we follow a 4-stage approach:

- **Stage 1 – Increased Caution but Business as Usual**

  - Increased hand washing

  - Clean desks

  - Work from home if any signs of illness

- **Stage 2 – Social Distancing**

  - Avoid non-essential work travel

  - Avoid corporate social gatherings

  - Remote meetings

- **Stage 3 – Increase Work from Home**

  - Avoid non-essential air travel

  - Departmental schedules for office work

- **Stage 4 – Strictly Work from Home**

  - All employees exclusively work from home

  - All meetings are conducted remotely
