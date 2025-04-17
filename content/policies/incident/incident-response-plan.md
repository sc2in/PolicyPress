---
title: "Incident Response Plan"
description: "Procures for responsing to security incidents"
date: 2022-11-24
weight: 1
taxonomies:
  TSC2017:
    - A1.1
    - CC7.3
    - CC7.4
    - CC7.5
    - P6.6
extra:
  owner: SC2
  last_reviewed: 2025-04-16
  major_revisions:
    - date: 2024-07-24
      description: Initial version.
      revised_by: Ben Craton
      approved_by: Ben Craton
      version: "1.0"
---

## Introductions

### General information

This manual was developed by and for {{ config.extra.organization }}, Inc. herein referred to as {{ config.extra.organization }}, principally located at 333 N Alabama St, Suite 300, Indianapolis, IN 46202, herein referred to as LOCATION, and it is classified as the confidential property of that entity. Due to the sensitive nature of the information contained herein, this manual is available only to those persons who have been designated as members of one or more incident management teams, or who otherwise play a direct role in the incident response and recovery processes.

Unless otherwise instructed, each plan recipient will receive and maintain two copies of the plan, stored as follows:

- One copy at the plan recipient's office
- One copy at the plan recipient's home


The following employees constitute {{ config.extra.organization }}'s Information Security Team:

- 

The incident management planning effort for {{ config.extra.organization }} recognizes and affirms the importance of people, processes, and technology to the corporation.

It is the responsibility of each {{ config.extra.organization }} manager and employee to safeguard and keep confidential all corporate assets and all customer information.

## Definitions

1. A service disruption is an event that causes a significant reduction in the quality of service or the availability of a service. Examples of service disruptions include:

   - A network outage
   - A server crash
   - A software bug that causes a service to fail
   - A hardware failure that causes a service to fail

While a service disruption may be an incident, not all service disruptions are information security incidents. For example, a power outage that causes a network outage is a service disruption but not an information security incident.

1. A critical business process is a business process that is essential to the operation of the business. A critical business process is one that, if disrupted, would have a significant impact on the business. Examples of critical business processes include:

   - A process that is essential to the delivery of a service to a customer
   - A process that is essential to the operation of a business unit
   - A process that is essential to the operation of a business function

1. An information security incident is a suspected, attempted, successful, or imminent threat of unauthorized access, use, disclosure, breach, modification, or destruction of information; or interference with information technology operations. Examples of information security incidents:

   - Computer system intrusion
   - Unauthorized or inappropriate disclosure of confidential {{ config.extra.organization }}'s data
   - Unauthorized or inappropriate disclosure of confidential {{ config.extra.organization }}'s customer data
   - Suspected or actual breaches, compromises, or other unauthorized access to {{ config.extra.organization }} systems, data, applications, or accounts
   - Unauthorized changes to computers or software
   - Loss or theft of computer equipment or other data storage devices and media (e.g., laptop, USB drive, personally owned device used for university work) used to store private or potentially confidential information
   - Denial of service attack or an attack that prevents or impairs the authorized use of networks, systems, or applications
   - Interference with the intended use or inappropriate or improper usage of information technology resources.

While the above definition includes numerous types of incidents, the requirement for central security incident reporting, regardless of malicious or accidental origin, is limited to serious incidents as defined below.

Occurrences such as incidental access by employees or other trusted persons where no harm is likely to result will usually not be considered information security incidents.

1. A serious incident is an incident that may pose a substantial threat to {{ config.extra.organization }} resources, stakeholders, and/or services. An incident is designated as serious if it meets one or more of the following criteria:

   - Involves potential, accidental, or other unauthorized access or disclosure of confidential {{ config.extra.organization }} information (as defined below)
   - Involves legal issues including criminal activity, or may result in litigation or regulatory investigation
   - May cause severe disruption to mission critical services
   - Involves active threats
   - Is widespread
   - Is likely to be of public interest
   - Is likely to cause reputational harm to {{ config.extra.organization }} or customers of {{ config.extra.organization }}

1. Confidential information is defined as information whose unauthorized disclosure may have serious adverse effect on the {{ config.extra.organization }}'s or {{ config.extra.organization }}'s customer reputation, resources, services, or individuals. [Information protected under federal or state regulations](http://safecomputing.umich.edu/protect-um-data/laws.php) or due to proprietary, ethical, or privacy considerations will typically be classified as confidential. confidential information includes personally identifiable information such as protected health information (PHI), Social Security numbers, credit card numbers, and any other information designated as confidential by {{ config.extra.organization }}.

## Incident Response Plan Overview

**Overview and objectives**

This incident management plan establishes the recommended organization, actions, and procedures needed to:

- Recognize and respond to an incident
- Assess the situation quickly and effectively
- Notify the appropriate individuals and organizations about the incident
- Organize the company's response activities, including activating an incident response team
- Escalate the company's response efforts based on the severity of the incident; and
- Support the business recovery efforts being made in the aftermath of the incident.

This plan is designed to minimize operational and financial impacts of such a disaster, and will be activated when the IT Security Officer, the CSO (or, in his/her absence, any member of the IT Security Team in part or whole) determines that a disaster has occurred.

## Scope

This incident management plan includes initial actions and procedures to respond to events that could impact critical business activities at {{ config.extra.organization }}. This plan is designed to minimize the operational and financial impacts of disasters.

## Policy

1. All users of {{ config.extra.organization }} IT resources must report all information security incidents to the IT Security Officer.
1. Any event that appears to satisfy the definition of a serious information security incident must be reported to the Information Security Team. A record of the course of events will be kept in our ticket system.
1. It is expected that incident reporting, from identification to reporting to the Information Security Team (if necessary), will occur within 24 hours.

   **Note** : In order to comply with **New York State Information Security Breach Laws (NYS Breach)**, for incidents which occur with New York State customers, please fill out the following form and submit to New York State Authorities: [https://its.ny.gov/sites/default/files/documents/business-data-breach-form.pdf](https://its.ny.gov/sites/default/files/documents/business-data-breach-form.pdf)

   For more information about NYS Breach, see: [https://its.ny.gov/breach-notification](https://its.ny.gov/breach-notification)

1. Some information security incidents may also be criminal in nature (e.g., threats to personal safety or physical property) and should immediately be reported to the appropriate local police department (e.g., Indianapolis – IMPD).

1. To avoid inadvertent violations of state or federal law, individuals and departments may not release information, electronic devices, or electronic media to any outside entity, including law enforcement organizations, before making the notifications required by this policy.

1. Privacy and Confidentiality of confidential Information:

   1. When {{ config.extra.organization }} staff report, track, and respond to information security incidents, they must protect and keep confidential any confidential information.
   1. Incident data retained for investigation will exclude any confidential information that is not required for incident response, analysis, or by law, regulation, or {{ config.extra.organization }} policy.

1. To ensure that the company responds appropriately to service distructions effectively, each business unit shall:

   1. Identify and document the critical business processes for their unit
   1. Identify the maximum tolerable downtime for each critical business process
   1. Identify the recovery time objective for each critical business process
   1. Designate a business unit representative as an incident response coordinator
   1. Declare an incident when a service disruption occurs that affects a critical business process
      1. All other service disruptions should be handled according to the business unit's standard operating procedures for escalation and resolution

## Preparation

{{ config.extra.organization }} educates employees about the importance of updated security measures and trains them to respond to computer and network security incidents quickly and correctly. {{ config.extra.organization }} requires that all employees comply with the company IT Security Policy.

## Identification

The response team is activated to decide whether a particular event is, in fact, a security incident. In the event of a data breach, {{ config.extra.organization }}'s Information Security Team will immediately perform and record a damage assessment, notify the affected customers within 24 hours of the completed damage assessment, and if necessary the appropriate authorities to the affected individuals. {{ config.extra.organization }} will involve a Microsoft support team if necessary.

If a notification is required, incorporate as much of the following information as possible: ~~.~~

- The name of the organization
- The name and contact details of the data protection officer or other contact point where more information can be obtained
- Describe the nature of the personal data breach including where possible, the categories and approximate number of data subjects concerned and the categories and approximate number of personal data records concerned
- Describe the likely consequences of the personal data breach
- Describe the measures taken or proposed to be taken by the controller to address the personal data breach, including, where appropriate, measures to mitigate its possible adverse effects.
- If known, include the identity of the unauthorized person who may have accessed or acquired the personal information.

### Gathering the Incident Team

Upon a suspected security incident being identified by any member of staff, the security team should be notified immediately. The security team will validate the incident and identify an incident manager for the duration of the incident. The incident manager will then gather a team from parts of the business to remediate the incident. A recommended team would consist of at least the following roles (multiple roles may be taken by a single individual if needed):

- Incident Manager
  - Leads the response to the incident and sees the team through the remediatation process. For the duration the incident, the incident manager has the authority to pull any needed resource to mitigate the issue. They are also responsible for the formation of the incident report at the end of the process.
- Technical Manager
  - Leads the development team in research and mitigation of the incident using the secure SDLC.
- Legal Manager
  - Guides the team through the legal questions that may arise during the incident. Ensures that external communications are transparent, but not opening liabilities.
- Communications Manager
  - Responsible for being the single point of contact for communicating with customers.
- Leadership Liaison
  - Responsible for keeping leadership up to date on the progress and findings from the incident response process.
- Scribe
  - Responsible for keeping a timeline of major events and milestones during the incident response. This timeline is to be included in the incident report.

### Internal Communications

Having formed an incident response team, communication channels should be established internally for swift information transfer during the incident. Whenever possible, communication to whole teams (e.g. by utilizing distribution lists) is peferable. All legal communcation should be in the form of email.

Recommended communications channels to establish:

- Technical resolution
- Customer communication
- Legal (via email)

Members of the incident response team may be in multiple channels.

## Containment

The Information Security Team will determine how far the problem has spread and will contain the problem by disconnecting all affected systems and devices to prevent further damage. The procedure is as follows:

- The IT Security Officer, in conjunction with the Software Engineering team, will validate the data breach
- The CSO or IT Security Officer will immediately assign an incident manager to be responsible for the investigation
- The CSO or IT Security Officer will assemble an incident response team, IRT
- The IRT will determine the scope and composition of the breach
- The Client Success and Customer Support departments will notify the data owners within 24 hours
- The CSO, or the Information Security Team, will determine whether to notify the authorities/law enforcement (situation dependent)
- The CSO, or the Information Security Team will decide how to investigate the data breach to ensure that the investigative evidence is appropriately handled and preserved

## Eradication

The Information Security Team will investigate the incident to discover its origin. The root cause of the problem and all traces of malicious code will be removed.

- The Information Security Team will collect and review any breach response documentation and analyses reports
- The Software Engineering team will determine the root of the breach and make environment changes necessary to prevent future attacks

## Recovery

All data and software will be restored from clean backup files, ensuring that no vulnerabilities remain. Systems will be monitored for any sign of weakness or recurrence.

- If necessary, the Software Engineering team will restore the backup files of the affected customer data to the database and ensure it is in a clean, fully recovered state for the affected organization(s).
- The Customer Support and Client Success teams will contact the affected customers to notify them of the recovery and the continued security of their data.
- If necessary, the appropriate authorities will be notified of the restoration and recovery of {{ config.extra.organization }} customer data.

## Lessons Learned

The IT Security Team will analyze the incident and how it was handled, making recommendations for better future response and for preventing a recurrence.

- A retrospective or lessons learned meeting will be scheduled within 1 week of the finalization of the incident recovery to begin the process of uncovering what situations, configurations, training, policies, procedures, or practices were missed to allow the incident to occur.
- The IT Security Team will ensure the necessary changes are performed in a timely manner to avoid future incidents.
