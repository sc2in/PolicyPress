---
title: Incident Response Plan
description: The SC2 Incident Response Plan
summary: This document is an IRP intended to serve as an operational guide for handling cybersecurity incidents at SC2.
date: 2025-04-16
weight: 2
taxonomies:
  SCF:
    - "IRO-01"
    - "IRO-02"
    - "IRO-02.1"
    - "IRO-02.2"
    - "IRO-02.4"
    - "IRO-02.5"
    - "IRO-03"
    - "IRO-04"
    - "IRO-04.1"
    - "IRO-04.2"
    - "IRO-05"
    - "IRO-05.1"
    - "IRO-05.2"
    - "IRO-06"
    - "IRO-06.1"
    - "IRO-09"
    - "IRO-10"
    - "IRO-10.2"
    - "IRO-10.3"
    - "IRO-10.4"
    - "IRO-11"
    - "IRO-11.2"
    - "IRO-12"
    - "IRO-12.1"
    - "IRO-12.2"
    - "IRO-12.3"
    - "IRO-12.4"
    - "IRO-13"
    - "IRO-16"
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

This document is an IRP intended to serve as an operational guide for handling cybersecurity incidents at {{ config.extra.organization }}.

The IRP follows the structure of the Incident Handling Guide published by NIST ([SP 800-61 Rev. 3](https://csrc.nist.gov/pubs/sp/800/61/r3/final)). General procedural guidance is provided in the body of the document, while incident scenario-specific guidance is listed on a case-by-case basis at the end.

Further, the IRP is intended to be a “living” document that gets updated over time as security threats come and go. The structure makes it easy to add new scenario guidance, while maintaining an overall process architecture that remains relatively static.

The general process guidance spans the full spectrum of incident handling activities from planning and preparation through response and even post-incident process reviews. It is recommended that NIST’s original SP 800-61 Rev. 3 guide be kept as a complement to this guide because it covers each of the process phases in additional detail that is not repeated here.

## Preparation

Effective IR begins with advance planning prior to incidents.

Preparation should include building and operating a comprehensive, modern security infrastructure with appropriate security sensors and event monitoring capabilities. At {{ config.extra.organization }}, these tasks are largely outsourced to an MSSP. {{ config.extra.organization }} provides a clear set of operational standards that external vendors must meet.

Additionally, the preparation stage should include infrastructure, equipment and processes for handling security incidents as they occur. In the current system, MSSP X’s monitoring team runs a SIEM, where it monitors for security events. When detected, MSSP X notifies {{ config.extra.organization }}, which then enters the information into a trouble ticket management system. (More details on this process can be found in the Detection and Analysis section below.)

Thus, the detection preparations are largely taken care of by the above vendors. Additional advance planning preparations should be handled on a case-by-case basis and driven by existing threat intelligence inputs. The incident handling preparations are handled at {{ config.extra.organization }} directly.

With the current low number of incidents being handled, tracking them is mostly ad hoc and easy to accomplish via {{ config.extra.organization }}’s trouble ticket handling system.

In addition to detection prep, legislation and regulations are increasingly affecting incident reporting requirements. What needs to be reported, when and how are specific to each requirement and type of incident. (The new SEC cybersecurity rule is dealt with specifically in Appendix A.)

Companies also need a defined process to assess incidents. This will most likely begin with the IR team collecting information and providing that information to the parties responsible for disclosures and reporting, usually legal and finance. They, not IR, make a determination on disclosures and reporting.

A complete discussion of this process is out of scope of this document, but three basic steps are encouraged:

- **Establish a corporate incident assessment process with the correct engagement**: Most regulations and legislation require this process to exist. It is not the responsibility of the IR team to drive this; IR does not have the corporate authority. However, it is in the IR team’s best interest to ensure this is on senior management’s radar. The establishment and management of the process will most likely be driven by legal and finance, with participation from the CISO, CIO, chief technology officer and corporate communications.
- **Confirm what information to collect and who should receive it internally**: The IR team is likely in the best position to determine what is affected by a given incident, but it is usually not the best group to determine the qualitative or quantitative impact. Impact is largely a business decision. Prior to any incident, the organization must determine what needs to be collected to determine the business impact, who should receive it and how that is decided. In our increasingly interconnected world, the impact decisions could easily require information from third parties, including vendors, suppliers, business partners, cloud service providers, forensic firms and more.
- **Develop templates and automate where practical**: Most regulations and legislation require an incident assessment process be established, documented and practiced. For each incident, any decisions about disclosures and materiality must be documented. What needs to be documented and how is a business decision outside of the IR team’s authority, but who was involved in the decision-making, the basis for the decisions, factors considered and the like are most likely relevant. It is in the IR team’s best interest to develop templates for each type of incident. Doing so will save precious time during an incident and reduce confusion during an uncertain time. Using automation where practical is highly encouraged.


## Incident Severity

Modeled after {{ config.extra.organization }}’s operational environment, {{ config.extra.organization }} has four quantified tiers of security incident severity. These severity tiers serve to guide the staff to ensure appropriate steps are taken that are commensurate with each incident’s severity level or risk level to the company. The severity levels are as follows, in descending
order:

- Critical (P-1): Priority level 1 is the highest tier of incident. These incidents represent the highest level of risk to the company. They impact or have the potential to impact multiple (and possibly all) {{ config.extra.organization }} customers. Critical decisions on Sev-1 incidents are generally escalated to executive management and are typically managed in real time via direct communications (e.g., over the incident phone bridge).
- High (P-2): Priority level 2 also has the potential of directly impacting {{ config.extra.organization }} customers. Generally, outages or security incidents that directly impact a single customer are ranked at Sev-2. If or when they impact multiple customers, the severity is increased to Sev-1. Similar to Sev-1, critical decisions on Sev-2 incidents are generally escalated to executive management.
- Medium (P-3) and Low (P-4): These are considered low-grade incidents, likely without any direct impact on {{ config.extra.organization }} customers. Lower-grade incidents are still managed, but the SLA-prescribed time margins are longer.

## Incident Handler Communications and Facilities

{{ config.extra.organization }} has in place or is building each of the following tools and information repositories for handling incidents,
per NIST SP 800-61 Rev. 3:

- Contact information is maintained for all key stakeholders likely to be involved in handling security incidents. These include 24/7 contacts for key decision-makers, vendor support, the operations team, corporate communications, corporate counsel and others. The contact list is readily available to all members of this core team.
- On-call information is maintained to indicate who is “on point” for handling security incidents at any given time. Although the incident handling staff is currently small, building this tracking will be essential if and when the current staffing level increases.
- Incident reporting mechanisms are available to all {{ config.extra.organization }} staff and vendors, should any of them need to report a security incident.
- Issue tracking systems are maintained across the different data centers and corporate staff for tracking of operations and security incidents. Currently, the MSSP data center uses a Jira-based tracking system. The MSSP security operations center (SOC) team uses a proprietary incident management system, but when it notifies {{ config.extra.organization }} of security incidents, {{ config.extra.organization }} help desk staff enter the trouble ticket information into its own tracking tool. While seemingly complex and disparate, the systems are not currently over-burdened by {{ config.extra.organization }}’s relatively low number of security incidents.
- Team communications are available to keep the incident handling team abreast of actions, progress and other incident operations information. Multiple tools are used for this, starting with the individuals’ smart phones. An email alias for security staff is available to rapidly disseminate emailed information. A phone bridge is employed during incidents so all the key staff can immediately communicate verbally to the team members. Multiple redundant systems are available should any of the above fail during an incident.
- Encryption is not currently used by the {{ config.extra.organization }} (and vendor) team for secure IR-related communications. However, most communications take place over an internal email service.
- War room facilities are available in the form of ample conference rooms, as needed.
- Secure storage for sensitive incident data (e.g., evidence) can be made available on demand via {{ config.extra.organization }}’s general counsel’s office or at an authorized third party at {{ config.extra.organization }}’s discretion.

## Incident Prevention Program

As part of an ongoing information security program, {{ config.extra.organization }} has or is implementing each of the following
prevention steps:

- Risk assessments should be performed at least annually to ensure the identified business risks are being appropriately addressed on all IT systems. These should be business-oriented but should be supported by a thorough understanding of topical technical threats. Input sources for risk assessments should come from reputable threat intelligence sources such as Verizon’s Data Breach Investigations Reports, available freely from Verizon.
- Host security should be assessed annually and after all major software upgrades. As with the business risk assessments, they should ensure current and reasonably foreseeable threats are addressed and key business assets are adequately protected.
- Network security should similarly be assessed annually.
- Malware prevention methods should be in place. As malware delivered via email in the form of phishing attacks remains among the most common means of delivering malware to its victims, {{ config.extra.organization }} should take substantial steps to screen incoming and outgoing email for potential malware.
- User awareness and training should be provided to all new employees, as well as on a recurring basis to all existing employees. The training should emphasize current threats, how to identify and avoid them, and what to do when an employee believes they have witnessed a threat.

## Detection and Analysis

This section covers the first operational phases of incident response.

### Detection

Incident detection at {{ config.extra.organization }} generally comes from events detected by the SOC staff at one of {{ config.extra.organization }}’s vendors (i.e., MSSP), using automated event monitoring tools or employees and end users who notice and report incidents.

MSSP’s SOC monitoring capabilities include event monitoring that has log information inputs from the corporate data center. When security incidents are detected on MSSP’s SIEM (or other systems), the MSSP team follows their internal escalation process to comply with their SLA with {{ config.extra.organization }}. That process includes notifying {{ config.extra.organization }}’s help desk staff. The {{ config.extra.organization }} staff then enters pertinent information about the incident into the trouble ticket handling system.

Once the initial data has been collected and verified, {{ config.extra.organization }} follows a triage process that determines the likely severity of the incident and assigns it to the appropriate action handler within {{ config.extra.organization }}. Once notified, the action handler is the principal point of contact or “owner” of the incident response process.

Similarly, if an incident is reported directly by an employee or contractor, the incident should be reported to the security authority or to human resources, which then enters it into the trouble ticket handling system. At that point, the remainder of the process is unchanged.

All {{ config.extra.organization }} staff and contractors should be actively encouraged to report potential security breaches. As described briefly in the Preparation section of this document, users should receive recurrent training on how to spot security breaches—preferably before they cause any damage. Every {{ config.extra.organization }} employee and contractor should know who to contact in the event of a security breach.

### Analysis

After a security event has been validated to be a security incident, {{ config.extra.organization }} incident response staff should gather and verify as much available data as possible. That data should be validated and analyzed to develop a prudent course of action. This process should be heavily influenced by the severity level of each incident, naturally, and will likely vary among the different severity levels.

Additional guidance is provided below in the Scenario Examples section, as well as in the NIST 800-61 Rev. 3 document. However, at a general level, incident response staff should seek to collect:

- **Date and time data**: The information should document when the incident is believed to have occurred. It should also document any additional dates and times of pertinent events that may comprise the incident. It can be highly advantageous to build an incident timeline that shows what happened and when it happened on any and all affected computer systems, particularly for complex and ongoing incidents.
- **Detection method**: How was the incident detected? Was the detection automated or did a human notice something abnormal?
- **Systems affected**: Which computer systems were affected, and to what degree, by the incident? This list will often grow over time, but it should be as comprehensive as can feasibly be determined.
- **Applications affected**: It is not adequate to merely list the computer systems, but also the businessapplications that are believed to have been affected by an incident.
- **Customers affected**: Which, if any, {{ config.extra.organization }} customers were affected?
- **Symptoms**: What led the tool or human to believe there may be a security incident? If a system, from a desktop to a server, was “behaving strangely,” those symptoms should be thoroughly recorded, even if the security team believes them to be in error. User statements should be recorded verbatim.
- **Targeted or untargeted incidents**: In most security incidents, the victims are not directly targeted. Theywere simply unlucky. In those cases, it is quite sufficient to remove any offending vulnerabilities, attack tools,etc., and get on with business. By contrast, when actually targeted, it becomes far more important toperform a deep and thorough analysis of any tools that were used. It is not always easy or even feasible toknow the answer for certain, but it is worth analyzing the available information and attempting to ascertainthe answer.
- **Security device alert data**: If a security appliance (e.g., an intrusion detection system) detected an incident, all alert data should be stored along with other incident data. The device itself no doubt stored the information either by itself or via a SIEM or console system, but all incident-specific data should be separately collected and stored.
- **The status of the incident**: Whether ongoing or over, this should be understood and tracked.

### Triage

As early on as possible in the detection and preliminary analysis process, a basic triage should be done. The purpose of triage is to assign a preliminary severity level to each incident and to assign staff to handle the incident. In a small organization such as {{ config.extra.organization }}, the triage step may be short and almost trivial but should nonetheless be done as a separate step for each and every incident. The reason for this is to be prepared for major incidents, many simultaneous incidents or a combination of these things.

It is likely each severity level will trigger different reporting and disclosure requirements (see Appendix A).

### Assigning Severity Levels

The following list provides guidance on how incident severity levels should be determined in the triage process:

- P-1 is indicated whenever an incident affects or has the potential to affect multiple {{ config.extra.organization }} customers.
- P-2 is indicated whenever an incident affects or has the potential to affect a single {{ config.extra.organization }} customer or a major internal business function.
- P-3 and P-4 incidents are generally internal issues that do not affect {{ config.extra.organization }} customers and have limited impact on internal business functions.

### Escalation and Notification

For each incident severity level, there should be an escalation and notification process that is either part of or coupled with the triage process.

#### Notification Process

For P-1 and P-2, notifications should generally be made on a 24/7 basis. Any staff on these lists who plan to be out of communications for extended periods should have a designated secondary point of contact.

Further, the notifications should begin with the detecting team and organization, whether that be the monitoring team at MSSP, the help desk or another organization.

#### P-1 and P-2

- Security team/security authority
- Operations team
- Chief operating officer
- Additional executives as the situation requires

For P-3 and P-4 incidents, notifications will generally be on a business-hour basis, unless the situation warrants after-hour notification.

#### P-3 and P-4

- Security team
- Operations team
- Additional business contacts as the situation requires

## Supporting Processes

Along with the notification process defined above, several steps should be taken in order to handle incidents properly for each severity level. These include the following:

### P-1 and P-2 Processes

- Evidence handling processes, including secure storage, should be initiated. All staff handling the incident should be issued guidelines for collecting and handling evidence in order to ensure the chain of custody is not broken. Once it is authoritatively determined that an incident will not result in a criminal or civil investigation, these procedures can be revoked and any information stored can be removed from storage. If necessary, incident handling staff should be prepared to hand over any evidence to legal or to a legal- appointed third party.
- Time tracking should be initiated to track all staff labor spent on handling the incident. The tracking should be able to uniquely quantify the labor on a per-incident basis, as well as calculate a cost based on fully loaded labor hours spent directly on handling the incident.
- Note-keeping procedures should be initiated so that staff record their actions, including what information is being gathered and which tools are being used to gather the information. {{ config.extra.organization }} counsel should advise operations staff on how to separate and mark their notes so incident notes are isolated from other general notes and so they are protected from discovery when applicable. Similarly, all incident notes should be protected to ensure chain of custody and confidentiality is maintained.
- Incident communications should be initiated among assigned staff so they can easily remain informed on current actions and status. Backup communications should be available in the event of a primary system failure. The incident handling staff should take care to communicate only with team members and stakeholders whose involvement is required.
- Action tracking should be performed that clearly assigns task leadership to individual staff and tracks the task status from beginning through task completion. All task tracking should also be maintained for historic tracking purposes.

### P-3 and P-4 Processes

- Incident communications should be initiated among all assigned staff so they can easily remain informed on current actions and status.
- Action tracking should be performed that clearly assigns task leadership to individual staff and tracks the task status from beginning through task completion. All task tracking should also be maintained for historic tracking purposes.

## Containment, Eradication and Recovery

The actual course of action taken for any given incident should be determined on a case-by-case basis. Guidance for specific incident types is provided in the Scenario Examples section.

With that in mind, some common strategies for dealing with incidents involve containment, eradication and recovery. We’ll discuss each of those in this section and elaborate on each by incident type below.

### Containment

As a general rule, one of the first actions to take after the initial information pertinent to an incident has been analyzed is to ensure the incident is contained. This, of course, is to protect the business from further adverse impact, first and foremost.

The questions and issues to carefully consider during this phase include the following:

- **Is the incident ongoing or has it run its course?** Again, verify whether the incident is ongoing or over. Understand what information that assessment is based on and how much confidence should be placed in it. When in doubt, assume it is ongoing. The reason for this is to ensure with a high degree of confidence that an incident can no longer cause further damage.
- **Is the incident due to an automated or manual attack?** In analyzing the incident data, it is helpful to know whether the incident was carried out manually by one or more adversaries or whether it is the result of an automated tool or collection of tools. If the incident is due to a manual attack, containing it should be relatively easy to achieve by merely blocking the attacker’s access—and, thereby, closing the attack surface—to the affected system(s). Of course, blocking an attacker’s network access to an application may also involve blocking customer access to that same system, so this decision must be made with a full understanding of the application and how it is used by customers.
- **Have the underlying root causes been addressed?** Of vital concern in the analysis and early response process is how the attacker was able to gain access to the affected system(s) in the first place. If a system or application vulnerability was exploited, then that or those vulnerabilities need to be remediated with corrective controls, or else the attacker may return at some point in the future. If the attacker gained access to a legitimate user’s account by entering correct authentication credentials, then it’s likely the user’s password (or other authentication credentials) can be changed. Even in such a case, however, it is important to know, again with a high degree of confidence, how the attacker got the user’s credentials in the first place. It’s possible that changing the user’s password will only delay the attacker somewhat. These things should be well understood in order to effectively contain the attack and prevent further damage.
- **Can the attacker and/or the attackers’ tools be isolated to prevent further spread?** It may seem like a simple question, but knowing whether containment or isolation is even possible is vital. One must start with a deep understanding of the incident’s tools, techniques and additional capabilities. That may not be easy to ascertain early on in the analysis process, so it may be necessary to block network or system access in a way that impacts all the system’s users.
- **What is the business impact?** Many of the courses of action described here will likely cause some amount of adverse business impact, quite possibly beyond the attack itself. In assessing what course of action to take, it is essential to understand what the business impact is likely to be. That should include direct impact to revenue, as well as more abstract aspects, such as potential harm to {{ config.extra.organization }}’s reputation. Note that sometimes an adverse business impact due to shutting a system down may, in fact, be preferable to the impact the incident may otherwise cause.
- **What is the potential for further business impact?** If the full nature of the attack or its tools is notunderstood, it is quite likely further damage will take place. Thus, the responders should critically analyzewhether further business damage is likely or not.
- **Should we engage the legal department?** The answer to this question will be determined by assessingthe situation for real or potential liability to the company. Liabilities can occur from a number of factors, suchas mandatory incident reporting laws, exposure of customer or other personally identifiable information and so on.
- **Should we call law enforcement?** The answer to this question is far from simple or one-dimensional. The mere presence of a crime does not mean it will get any significant attention from a law enforcement agency, for example. A key issue for the law enforcement agency will be how much damage has occurred and how much of it can be proven in court. Proving something in court carries with it a high burden on the investigators. Not only does all evidence need to be collected and safeguarded properly to maintain the chain of custody, but the actual damages need to be quantified in a clear and objective manner. A revenue- producing system facing downtime is the easiest to quantify, but many losses are far more difficult to quantify than that. Losses should include staff labor costs. (For more on the role of law enforcement during an incident, see Appendix A.)

### Eradication

The eradication process is when the residue of an attack gets removed from all affected systems. Any files, malware, tools, known software vulnerabilities, etc., are removed. This may be relatively easy, like removing a couple of files used by the attacker and getting back to business. On the other hand, it may be exceedingly difficult. If the adversary has installed tools such as rootkits that use evasive techniques to mask their existence, removal may well be elusive.

Of course, at this point, all files and data needed for analysis or evidence purposes should already be removed and safely stored away for analysis or other purposes. The specific steps here will depend on the tools and techniques used in the attack but must be determined with a high degree of confidence from the analysis process.

It may be necessary to install software patches, updates or even major software upgrades to achieve eradication, particularly if the affected system(s) was running older software versions. This should span the entire software “stack,” from the boot loader through the kernel and on to the applications and their components.

### Recovery

The final operational phase of responding to an incident should be recovery. During this phase, business data is restored and the affected systems are brought into a production-ready state. It may be necessary to restore business data from backups, even if it means losing some legitimate changes to the data sets.

Again, the steps taken here depend on the tools and techniques used by the adversary. However, the goal remains the same: prepare the affected system to go back to a production state.

## Post-Incident Activity

The purpose of the post-incident activity is to critically address the company’s security processes and procedures, from how it secures its systems to how it responds to security incidents. As such, it should carefully review the root cause of the incident and how the team responded once an incident was detected.

As a general rule, it is a good idea to hold a post-mortem meeting after high severity (Sev-1 and Sev-2) incidents. The meeting should include the key personnel who helped respond to the incident and all the departments and organizations necessary for determining the incident’s root cause and improving future response.

Key to the success of a post-mortem meeting is an attitude of constructive criticism and process improvement. The meeting facilitator should make absolutely certain no personal attacks are permitted.

Examples of questions that should be discussed and recorded include the following:

- Exactly what happened and when?
- How well did staff and management perform in dealing with the incident?
- Were documented processes and procedures followed? Were they adequate?
- What information was needed sooner?
- Were steps taken that inhibited the response?
- What should be done differently next time a similar incident occurs?
- What aspects of information sharing could have been improved, internally or externally?
- What corrective actions should be taken to prevent similar incidents?
- What precursors should be monitored to better detect future incidents?
- What tools or resources should be added to better detect, analyze or respond to future incidents?

## Example Incident Scenarios

### Intrusion to Steal Data

#### Preparation

Protecting against data theft is a broad topic, but most solutions come down to access control. Access controls can be applied at the operating system, application or network levels, at a bare minimum. At a fundamental level, controls should be in place to ensure unauthorized users do not gain access to information they’re not permitted to.

Strong access control begins with strong identification and authentication of all entities on a system. Once an entity is authenticated, the system should question every action and allow or disallow it based on policy.

Systems containing sensitive business data should be assessed by competent security staff to ensure those controls are in place across the system.

Access control is only the first step. If a user attempts to gain access to data for which they are not authorized, the access controller should notify the system owner. At {{ config.extra.organization }}, any system that experiences an access control violation, whether successful or not, should send an alert to the MSSP monitoring staff. That notification should include the pertinent data (who, what, when, where and how) so the security staff can determine what has taken place.

Further, systems with highly sensitive data should be given the ability to take evasive action when such a violation occurs. The specific evasive actions should be determined on a case-by-case basis for each major application. Some actions to consider, however, include the following list:

- Lock account after some predetermined number of failed login attempts, possibly for a duration of time or until the legitimate account holder contacts {{ config.extra.organization }} security authority.
- Lock sensitive account data from being deleted or altered. This may include preventing a user from changing the owner of a registered toll-free phone number, for example.
- Invoke additional and rigorous logging of the offending user’s activity, along with an explicit notice to the user that their actions are being recorded above and beyond normal levels of logging.
- Force the user to reauthenticate with existing credentials, MFA (if applicable), security questions, etc.

In addition to strong authentication and authorization controls, a fundamental property that is needed to properly handle these sorts of incidents is accountability. All actions on the system should be logged, to the extent feasible.

#### Detection and Analysis

Intrusions in which data is stolen are usually not easy to detect. Some intrusion detection systems (IDS) and DLP tools can look for statistically anomalous behavior, but all such systems can be duped by a knowledgeable adversary. Traditional signature-based IDS and intrusion prevention system products, as a general rule, are not how data theft incidents get detected. Deep analysis of NetFlow data can help.

Once such an incident is detected, the preliminary analysis should focus on gathering all pertinent event log data. The analysis should further seek to determine what kind of data the intruder appears to have taken or tried to take. From that analysis, {{ config.extra.organization }} should be able to triage and assign a preliminary severity level to the incident. That severity level should be determined by the relative sensitivity and volume of the target data, as it is likely the incident would not have any direct impact on any {{ config.extra.organization }} customers, at least initially.

Often, external intrusions do not result in media inquiries, but if the breach involves customer or private information, the customer engagement team should be immediately involved, allowing them to prepare eventual responses or press releases.

#### Containment, Eradication and Recovery

In the case of a data theft incident, the containment process generally focuses on ensuring the attacker no longer has access to the data and the intruder cannot get to other systems within the operating environment.

Eradication should focus on ensuring no data was altered, first and foremost. This should include steps such as the following, depending on the available tools and features of each business application:
- Review of available application logging to see what information was accessed and/or altered.
- Review of available network and application server logging data to corroborate the application records.
- Review of host-level log data to look for file system-level alterations.

Second, it should ensure the attacker’s path is thoroughly blocked against future attacks. That may mean applying network-level access controls, locking or removing accounts, changing passwords, bolstering access controls and so on, depending on the specific technical details of each incident, on a case-by-case basis.

As long as no other malicious activity has taken place, the recovery step should be relatively simple. If no data was tampered with, once the attack has been contained and further access has been eradicated, the system should largely be ready for production. Nonetheless, if the affected system is business-critical, a thorough vulnerability assessment by an independent security team would be warranted.

#### Post-Incident Activity

Apart from addressing standard incident response operations, the principal post-incident activity in such an incident is to address the root cause.

- Was it a point failure, a systemic failure or something else entirely?
- How can {{ config.extra.organization }} ensure the same sort of incident won’t happen again?
- If it cannot be prevented, how about building better detection?

### Intentional Disclosure by an Insider

#### Preparation

Protecting against data theft is a broad topic, but most solutions come down to access control. Access controls can be applied at the operating system, application or network levels, at a bare minimum. At a fundamental level, controls should be in place to ensure unauthorized users may not gain access to information they’re not permitted to. Careful thought and planning should go into minimizing the data each employee is authorized to access.

In the case of an employee (or contractor) leaking sensitive data, the employee is likely to be an authorized user. Thus, a high degree of accountability is needed on all systems.

Strong access control begins with strong identification and authentication of all entities on a system. Once an entity is authenticated, the system should question every action and allow or disallow it based on policy.

Systems containing sensitive business data should be assessed by competent security staff to ensure the appropriate accountability and nonrepudiation controls are in place across each system. These should include rigorous application-level logging of user actions, along with session-specific details of who is logged in, from where, how they are authenticated and so on. Additional network-level logging of attributes such as SSL/TLS cipher in use, length of session key, ID of client-side certificate (if applicable) may also be recommended, depending on the nature of each application, again, on a case-by-case basis.

Access control is only the first step. If a user attempts to gain access to data for which they are not authorized, the access controller should notify the system owner. At {{ config.extra.organization }}, any system that experiences an access control violation, whether successful or not, should send an alert to the MSSP monitoring staff. That notification should include the pertinent data (who, what, where, when and how) so the security staff can determine what has taken place. For accountability and nonrepudiation, all data accesses—not just the policy violations—should be logged, and the logs should be stored where users cannot access them.

Further, systems with highly sensitive data should be given the ability to take evasive action when such a violation occurs. The specific evasive actions should be determined on a case-by-case basis for each major application. Some actions to consider, however, include the following list:

- Lock account after some predetermined number of failed login attempts, possibly for a duration of time or until the legitimate account holder contacts {{ config.extra.organization }} security authority.
- Lock sensitive account data from being deleted or altered. This may include preventing a user from changing the owner of a registered toll-free phone number, for example.
- Invoke additional and rigorous logging of the offending user’s activity, along with an explicit notice to the user that their actions are being recorded above and beyond normal levels of logging.

Force the user to reauthenticate with existing credentials, MFA (if applicable), security questions and such.

#### Detection and Analysis

In this scenario, the breach is by an otherwise authorized user. As such, it is not likely the incident will be detected
using traditional monitoring systems. An exception to this general rule could be if all system activity is logged and
carefully scrutinized for policy violations, statistical anomalies, etc.

Nonetheless, when such a breach is detected, a key focus should be comprehensively determining the scope of the breach. How much data did the employee exfiltrate and/or actually release? How much did they have access to? Is it possible the employee hasn’t (yet) released all the information they exfiltrated? 

Further, the method of data exfiltration should be determined. How did the employee get the data out of the company? Was it removable media, such as a USB storage device, or was the data sent via computer network? In the latter case, NetFlow and other data monitoring tools/techniques may be useful for estimating the overall volume of data in the breach. Specifically, NetFlow provides the necessary metadata to determine who is talking to who, when are they talking, and how long and large the session was. It does not, however, log the full packet information of what was being said during a network session. NetFlow is generally implemented on network routing and firewalling components, with the log data being sent to SIEM concentrators for further analysis.

The incident severity level should generally be determined by a combination of the type of data leaked and the scope of the disclosure. Questions to consider include the following:

- Was the data published via a highly public channel, such as Wikileaks or even the mainstream media?
- How did {{ config.extra.organization }} first learn of the leak itself? Was it merely posted to a user’s social network page?
- What is the readership scope of the channel through which the data was publicized?

In the latter case, it’s possible the social network will assist in restricting access to the disclosed information. Did the data include company proprietary or customer private information?

Depending on the nature of the data disclosure, it is quite likely this sort of incident will attract the attention of the media. The customer engagement/communications team should most certainly be alerted so they can have a plan in place. Depending on the nature of the disclosed information, {{ config.extra.organization }} may be required to disclose the breach. Legal counsel should be consulted to ensure all relevant data disclosure laws are being complied with (see Appendix B). Legal will also make the determination of whether a third-party forensics company should be engaged.

Similarly, the question of whether to involve law enforcement should be critically and thoughtfully considered here. Beyond statutory reporting requirements (see Appendix B), {{ config.extra.organization }} will need to determine if the damage was sufficient to call in law enforcement. To make that decision, it is best to consult senior management and competent legal counsel.

#### Containment, Eradication and Recovery

Given the nature of this type of incident, containment may no longer be possible. Nonetheless, the employee who disclosed the data should have their access revoked as quickly as possible. All local and remote connectivity should be blocked. All passwords should be changed and accounts locked. If the employee in question is still employed by the company, care should be taken to remotely lock the employee’s laptop, remove corporate data from any mobile device and disable any relevant cloud storage accounts, such as Box.

Intentional employee breaches may result in either criminal or civil legal proceedings, so it is usually a good idea to invoke evidence handling processes, even in the case of a low-severity incident (Sev-3 or Sev-4).

Similarly, in this type of incident, the eradication phase may be a fairly simple one. Ensure the employees who need access to the data have access. If the data was on shared storage, such as a file share server, it could be valuable to ensure the data has not been tampered with. It is also a good idea to verify files were not removed.

If the incident involved a {{ config.extra.organization }} contractor with access to proprietary or other sensitive data, the process would likely include not only the above steps, but also contractual remedies that are available. If the contractor was using an endpoint computer provided by the contractor, for example, then {{ config.extra.organization }} will need to ensure it has the necessary authority to collect evidence from that system. While these details should be predetermined in the contract language, they should be verified during any such incident. The contractor’s management will also need to be actively engaged in the process.

#### Post-Incident Activity

Apart from addressing standard incident response operations, the principal post-incident activity in such an incident is to address the root cause of the incident:

- Was it a point failure, a systemic failure or something else entirely?
- How can {{ config.extra.organization }} ensure the same sort of incident won’t happen again?
- If it cannot be prevented, how about building better detection?
- Was the employee given an overly broad set of data access permissions or was the authorized access appropriate?
- Were there indications of potential insider threat that went unnoticed?


## Appendix A: The Role of Law Enforcement

The role of law enforcement in managing a cyber incident cannot be overstated. According to IBM’s [Cost of a Data Breach Report 2023](https://www.ibm.com/reports/data-breach), organizations that involved law enforcement reduced the total cost of an incident and recovered faster.

Some regulations and legislation require or indirectly require the engagement of law enforcement. For example, the SEC cyber rules passed in 2023 (see Appendix B) provide for a delay in official reporting if there are national security concerns. It is hard to imagine a scenario where a company could claim national security concerns without engaging law enforcement. Similarly, the recently passed amendment to the NYSDFS [23 NYCRR Part 500](https://www.iansresearch.com/portal/tools-and-templates/23-nycrr-part-500-changes-a-cheat-sheet) requires ransomware payments to be reported within 24 hours. It is in an organization’s best interest to engage law enforcement to avoid sanctions, fines, personal liability and possible criminal action.

Incidents with a physical aspect, such as those impacting power grids, gas pipelines and water supplies, will almost certainly require the involvement of law enforcement. Organizations should discuss these situations prior to any incident, document the decision and procedure for bringing in law enforcement and include the process in any IR tabletops. Five basic types of incidents should be addressed:

- Ransomware
- Scenarios involving nation states or the loss of intellectual property
- Scenarios involving insiders, including former employers, contractors, vendors and suppliers
- Scenarios involving national security or safety
- Scenarios involving hacktivists, especially scenarios involving doxing

We know when it comes to cases involving extortion, like ransomware, payments are typically made to organizations on the Office of Foreign Assets Control (OFAC) [Sanctions Lists](https://ofac.treasury.gov/ofac-sanctions-lists). Making payments to parties on the OFAC lists can result in fines, sanctions, personal liability and even criminal action. The Department of Justice (DOJ) strongly discourages anyone from making ransomware payments and does not support paying a ransom in response to a ransomware attack. While the FBI [clarifies](https://duo.com/decipher/fbi-guidance-evolves-on-ransomware-payments) that it “will continue to treat you as a victim even if you pay,” organizations are highly encouraged to engage law enforcement.

Engaging law enforcement can also help you make better decisions faster. Law enforcement deals with these situations all the time. It can help you understand who you are dealing with and what others are dealing with, and it can provide lessons learned from the experiences of others. In the case of ransomware, the FBI sometimes already has the key to unlock your data because of a different case they worked previously. In certain situations, as [we saw with Colonial Pipeline](https://www.justice.gov/opa/pr/department-justice-seizes-23-million-cryptocurrency-paid-ransomware-extortionists-darkside), they may even help you recover any ransoms already paid.

Federal law enforcement has resources at its disposal that most organizations do not. Almost all cyberattacks come from overseas or organized crime. Federal law enforcement can bring the total weight of the U.S. government on the bad actors. We have seen a number of situations where law enforcement has successfully recovered ransom payments, dismantling nefarious organizations and containing damage.

This area is where digging your well before you are thirsty is essential. Scrambling for a phone number and introducing yourself during an incident is not the most effective use of your time. Your local FBI field office can be found [here](https://www.fbi.gov/contact-us/field-offices/@@castle.cms.querylisting/6bd7cedb14f545e3a984775195ea3d30). Reach out and ask for someone in the cyber division. Introduce yourself and ask about the resources available. You may be reluctant to call during an incident. By making the connection now, you preserve the option.

## Appendix B: SEC Cyber Disclosure Rules

Below outlines special consideration for SEC Rule [Cybersecurity Risk Management, Strategy, Governance and Incident Disclosure](https://www.sec.gov/files/rules/final/2023/33-11216.pdf).

### Audience

Appendix B is designed to help anyone involved in or adjacent to IR planning or execution understand the potential impact of the SEC rule adopted in July 2023. It is important to recognize this rule enhances existing rules. It is imperative to work closely with other parts of your organizations already engaged in SEC reporting, especially legal, finance, compliance and risk management.

The final rule requires public companies and foreign private issuers (FPIs) to:

- Disclose (report) material cybersecurity incidents they experience.
- Disclose (report) on an annual basis material information regarding their cybersecurity risk management, strategy and governance.

The final rule effectively formalizes the [Commission Statement and Guidance on Public Company Cybersecurity Disclosure](https://www.sec.gov/files/rules/interp/2018/33-10459.pdf) issued in 2018.

### Applicability

The rule applies to any firm subject to the reporting requirements of the Securities Exchange Act of 1934. Effectively, that means publicly traded companies and FPIs (details for both are provided below).

#### Final Rule for Domestic Filers[^1]

|Final Rule| Content| When| How|
|---|---|---|---| 
| Incident Disclosure Item 1.05 (new)| DIsclose cybersecurity incidents determined to be material. Describe the nature, scope and timing of the incident, its impact or reasonably likely impact on the registrant and its operations, and any information it has about the cause of the incident.| Within four business days after determining that an incident is material. Materiality of a cyber incident must be determined "without unreasonable delay."| Form 8-K|
| Incident Disclosue Item 1.05 (ammended)| Statement(s) to be included in subsequent submission that were either not determined in the initial filing or not available when the initial filing was made.| Within four business days after determining that an incident is material.| Form 8-K. Updates and subsequent submissions.|
| Process Disclosure Regualtion S-K, Item 106(b)| A description of processes used to identify, assess, and managed cybersecurity risks; and whether any thereats have materially affected or are reasonably likely to materially affect business strategy, operations, or financial condition.| Annual report | Form 10-K |
| Process Disclosure Regulation S-K, Item 106(c)| A description of the board of directors' oversight of cybersecurity risks and management's role in assessing and managing those risks. The frequency of board discussions of cybersecurity or information about any director’s expertise in the field does not need to be disclosed.| Annual report | Form 10-K |
| Process Disclosure Regulation S-K, Item 106(c)(2)|Describe management’s role in assessing and managing material risks from cybersecurity threats.| Annual report | Form 10-K |

#### Final Rule Summary for FPIs[^1]

|Final Rule| Content| When| How|
|---|---|---|---|
| Amendment to General Instruction B of Form 6-K | Information on material cybersecurity incidents they disclose or publicize in a foreign jurisdiction to any stock exchange or to shareholders. | In a timely manner. | Form 6-K |
| Item 16J on Form 20-F | Submissions must describe the board’s oversight of cybersecurity risks and management’s role in assessing and managing material cybersecurity risks. | Annual report | Form 20-F |

### Special Consideration for Smaller Reporting Companies

The SEC rule does not make any exceptions based on the size of the reporting company. The SEC does recognize smaller companies face significant cybersecurity risks and often suffer outsized impacts.

The SEC delayed the effective date for smaller companies by an additional 180 days (June 15, 2024).

### Updates to IRP

Companies should review their IRP(s) and related activities and update them accordingly. The IR team should partner with the legal, finance, compliance and risk management parts of the organization.
The IR team’s responsibility to comply with the rule is to provide relevant, accurate information to decision-makers in a timely manner.

The following should be considered when reviewing plans and activities to be updated:

- Compliance is highly reliant on the necessary information being provided to the appropriate stakeholders so a materiality determination can be made “without unreasonable delay” and the disclosure prepared. The corporate policy of materiality must be reviewed and updated. The key stakeholders and decision-makers must be identified. The information they require to make the decision must be identified.
- Assess in advance the factors the company will consider to determine if a cyber incident is material. The SEC mentions both the quantitative impact on the financial condition of the company and the financial impact from operations. The SEC also speaks to qualitative factors like reputational damage, damage to the company’s competitive position and impact to relationships (e.g., customers, vendors, suppliers).
- If the company wants to preserve the option to delay a disclosure because of a substantial risk to national security or public safety, an internal process is needed to engage the appropriate stakeholders to determine whether to seek such a delay. An internal process is also required to seek relief from the DOJ if that is what the company decides.
- The role and priority of law enforcement must be revisited. It is hard to imagine a situation where a company can claim a substantial risk to national security or public safety without the involvement of law enforcement.
- Disclosure may be required before an incident is contained. The situation will evolve, threat actors may change tactics, additional attacks may occur and new facts may come to light. How and when disclosures will be updated must be mapped out and documented.
- The SEC rule could alter other aspects of the existing IRP. Priorities, sequencing of tasks, escalation paths, engagement of third parties and external notifications may change. A 360-degree review of the existing plan in light of the SEC rule is well advised.
- Organizations should exercise the updated IRP through tabletop exercises, perform a post-mortem and update the plan accordingly.

### Timing

- Incidents must be reported within four business days of determining an incident is material and “without unreasonable delay.”
- Subsequent updates to reported incidents must be made, but the timing of updates is not prescriptive. The organization should have an established corporate policy and procedure in place.
- Annual reports must include descriptions of processes, material risks, board oversight and the role of management.

### Materiality

The reporting of incidents under this rule hinges on determining “materiality.” This question is receiving greater attention, but the simple fact is most organizations have been dealing with this question for years, just not in a cyber context (see the SEC [Commission Statement and Guidance on Public Company Cybersecurity Disclosures](https://www.sec.gov/files/rules/interp/2018/33-10459.pdf) from 2018).

We expect a lot of discussion on the topic of materiality. Guidance is expected, but it’s unclear when. The discussion about materiality will likely evolve into a discussion about value at risk. While the cyber community is primarily treating materiality as something only publicly traded companies must deal with, the practical reality is every organization must deal with the question of materiality. The reporting of material events is starting to appear in third-party agreements and global legislation.

The SEC cybersecurity rules describe a material incident as a matter “to which there is a substantial likelihood that a reasonable investor would attach importance” in an investment decision. This is not a new definition. It is based on the precedent set by the U.S. Supreme Court over 40 years ago in [TSC Industries, Inc. v. Northway Inc., 426 U.S. 438 (1976)](https://supreme.justia.com/cases/federal/us/426/438/).

SEC guidance says, “There must be a substantial likelihood that the disclosure of the omitted fact would have been viewed by the reasonable investor as having significantly altered the ‘total mix’ of information made available.” The SEC says both quantitative and qualitative factors must be included, like reputational damage, impact on competitiveness, operational impairment, loss of business-critical information (such as intellectual property) and impact on business relationships (e.g., customers, vendors, suppliers).

To determine what is material, each organization must ask itself:

- What is our corporate policy about what is material and how do we amend for cyber?
- What information is required to decide if an incident is material?
- Who ultimately decides?
- What is the process to make the decision? Do we need a RACI chart?

[^1]: IANS, 2024

## Appendix C: NIS2 Reporting Guidance

The following outlines reporting guidance for the [European Union’s (EU) Network and Information Security (NIS2)](https://digital-strategy.ec.europa.eu/en/policies/nis2-directive) Directive, including the implementation regulation released on Oct. 17, 2024. Appendix C is designed to help individuals involved in or adjacent to Incident Response (IR) planning or execution understand reporting obligations under NIS2, especially those in security, legal, finance, compliance and risk management.

NIS2 sets cybersecurity rules for organizations providing services deemed essential or important for maintaining critical societal and economic activities. The directive aims to elevate cybersecurity standards across the EU while promoting resilience. NIS2 updates and expands the scope of the previous directive introduced in 2016. It officially came into force on Jan. 16, 2023, mandating that member states incorporate NIS2 measures into national law by Oct. 17, 2024.

The most pertinent articles within in NIS2 include:

- [NIS2 Article 10: Computer security incident response teams](https://www.nis-2-directive.com/NIS_2_Directive_Article_10.html) mandates that member states establish CSIRTs, defining their roles and responsibilities and outlining how CSIRTs should interact with each other.
- [NIS2 Article 11, Requirements, technical capabilities and tasks of CSIRTs](https://www.nis-2-directive.com/NIS_2_Directive_Article_11.html) outlines the responsibilities, capabilities and characteristics expected of CSIRTs.
- [NIS2 Article 23: Reporting obligations](https://www.nis-2-directive.com/NIS_2_Directive_Article_23.html) establishes the minimum reporting requirements that member states must integrate into national law.

On Oct. 17, 2024, the European Commission adopted the first implementing regulation, which outlines reporting obligations for digital infrastructure and service providers. This regulation includes an annex specifying technical and procedural requirements for the key cybersecurity requirements listed in Article 21(2). The annex’s content, however, is out of scope of this Appendix.

### Caveat

NIS2 does not impose requirements directly on companies that operate within or sell to the EU. Rather, it sets minimum requirements for member states to incorporate into their national laws and enforce locally. As such, specific details, such as where reports should be sent, will be outlined in each member state’s enacted legislation. NIS2 provides a framework for what needs to be reported, when and establishes CSIRTs as the enforcing authority.

As of Oct. 17, 2024, only a limited number of EU member states had finalized the transposition process.

The EU does not provide a centralized resource to track member states’ progress in implementing NIS2. However, organizations can refer to unofficial sources like [The NIS2 Directive in EU: A country-by-country breakdown from Truid and the NIS2 Article 28 Tracker from the DNS Research Federation](https://www.truid.app/blog/the-nis2-directive-in-eu-a-country-by-country-breakdown), which provide a breakdown by country and stage.

For organizations operating within the EU or offering products or services in the EU, staying informed of each relevant country’s progress is strongly recommended.

### Digital Operational Resilience Act

Due to its growing reliance on technology and external service providers, the financial services sector is governed by the Digital Operational Resilience Act (DORA). While actions taken to meet NIS2 reporting requirements will contribute to DORA compliance, they may not be sufficient. Organizations subject to DORA will need to address any deltas.

DORA took effect on Jan. 16, 2023, and will apply beginning on Jan. 17, 2025. The act is designed to reinforce IT security within financial entities, ensuring Europe’s financial sector remains resilient even during significant disruptions.

DORA standardizes operational resilience rules across the financial sector, applying to 20 types of financial entities, including banks, insurance companies, investment firms and information and communication technologies (ICT) third-party service providers.

DORA is beyond the scope of this Appendix.

### Reporting Obligations

NIS2 outlines specific reporting obligations in Article 23, mandating that essential and important entities notify those potentially affected and submit five formal reports to the designated CSIRT or authority in cases of significant incidents. Incidents that do not meet the “significant” threshold under NIS2 are exempt from mandatory reporting. Additionally, scheduled interruptions and their foreseeable impacts are not considered significant incidents.

NIS2 mandates that organizations report significant incidents within 24 hours. The specific recipients of these reports will be clarified in the national implementing legislation of each member state. Member states designate both the CSIRT and competent authority to oversee cybersecurity and carry out supervisory tasks. Member states may impose additional reporting requirements as deemed necessary.

NIS2 defines an incident as “an event compromising the availability, authenticity, integrity or confidentiality of stored, transmitted or processed data or of the services offered by, or accessible via, network and information systems.” Only significant incidents must be reported. NIS2 defines a significant incident as “any incident that has a significant impact on the provision [of the services provided by essential and important entities].”

Article 23, item 3 states, “An incident shall be considered significant if:

- a) it has caused or is capable of causing severe operational disruption of the services or financial loss for the entity concerned;
- b) it has affected or is capable of affecting other natural or legal persons by causing considerable material or non-material damage.”

[Recital (101) in the preamble](https://www.nis-2-directive.com/NIS_2_Directive_Preamble_101_to_110.html) provides guidance on factors to be considered “indicators such as the extent to which the functioning of the service is affected, the duration of an incident or the number of affected recipients of services could play an important role in identifying whether the operational disruption of the service is severe.”

NIS2 does not define “severe financial loss” or “considerable material or non-material damage.” The implementation regulation adopted on Oct. 17, 2024, clarified the reporting requirements for providers of digital infrastructures and services as follows:

- **Impacted users**: Article 3 of the implementation regulation establishes how to calculate the number of impacted users for Articles 7, 9 and 14. The following are to be considered:
  - The number of customers holding contracts that grant access to the relevant entity’s network, information systems or services
  - The number of natural and legal persons associated with business customers who use the entity’s network, information systems or services
- **Significant incidents**: Article 3 defines a significant incident for providers of digital infrastructure, ICT service management and digital providers within the scope of NIS2 as meeting at least one of the following criteria:
  - Direct financial loss of the lesser of €500,000 (about $528,000) or 5% of the entity’s total annual turnover in the preceding fiscal year
  - Exfiltration or potential exfiltration of trade secrets
  - Incident resulting in, or with the potential to cause, the death of a natural person
  - Incident causing, or potentially causing, considerable damage to an individual’s health
  - Successful occurrence of suspectedly malicious and unauthorized access to network and information systems, with the potential for severe operational disruption
  - Occurrence of incidents at least twice within the past six months, sharing the same apparent root cause and collectively causing, or potentially causing, direct financial loss of at least the lesser of €500,000 or 5% of the annual turnover for the preceding fiscal year
- **Recurring incidents**: Article 4 of the implementation regulation stipulates that recurring incidents must be reported as a single significant incident if multiple related events, while individually non-reportable, collectively meet significant incident criteria. These incidents are to be considered collectively as one significant incident when the following criteria are met:
  - They have occurred at least twice within a six-month period
  - They have the same apparent root cause
  - They collectively meet the criteria specified in Article 3(1)(a)
- **Domain name service (DNS) providers**: Article 5 of the implementation regulation considers an incident significant if any of the following conditions are met:
  - A recursive or authoritative DNS resolution service is completely unavailable for over 30 minutes
  - The average response time for DNS requests by a recursive or authoritative DNS resolution service exceeds 10 seconds for more than one hour
  - The confidentiality, integrity or authenticity of data related to service provision is compromised, except if fewer than 1,000 domain names—or no more than 1%—are incorrect because of misconfiguration
- **Top-level domain (TLD) name registries**: Article 6 of the implementation regulation considers an incident significant for TLD name registries if any of the following conditions are met:
  - A service is completely unavailable
  - The average response time to DNS requests exceeds 10 seconds for more than one hour
  - The confidentiality, integrity or authenticity of data (stored, transmitted or processed) is compromised
- **Cloud computing service providers**: Article 7 of the implementation regulation considers an incident involving cloud computing services significant if any of the following conditions are met:
  - A service is unavailable for more than 30 minutes
  - A service is limited for more than one hour, affecting either 5% of users or more than 1 million users in the EU, whichever is less
  - The confidentiality, integrity or authenticity of data (processed, stored or transmitted) is compromised due to a suspected malicious act
  - The confidentiality, integrity or authenticity of data (processed, stored or transmitted) is compromised, impacting either 5% of users or more than 1 million users in the EU, whichever is less
- **Data center providers**: Article 8 of the implementation regulation considers an incident involving a data center significant if any of the following conditions are met:
  - A data center service is unavailable
  - A data center service is limited for an hour or more
  - The confidentiality, integrity or authenticity of data (processed, stored or transmitted) is compromised due to a suspected malicious act
- **Content delivery network providers**: Article 9 of the of the implementation regulation considers an incident significant if any of the following conditions are met:
  - The content delivery network is completely unavailable for more than 30 minutes
  - The availability of the content delivery network is limited for 5% or more than 1 million users in the Union, whichever is less
  - The confidentiality, integrity or authenticity of data (stored, transmitted or processed) is compromised due to suspected malicious act(s)
  - The confidentiality, integrity or authenticity of data (stored, transmitted or processed) impacts up to 5% or 1 million users in the Union, whichever is less
- **Managed service providers and managed security service providers**: Article 10 of the implementation regulation considers an incident significant if any of the following conditions are met:
  - One or more managed service(s) is completely unavailable for more than 30 minutes
  - The availability of one or more managed service(s) is limited for 5% or more than 1 million users in the Union, whichever is less, for a duration not exceeding one hour
  - The integrity, confidentiality or authenticity of data (stored, transmitted or processed) related to the provision of service(s) is compromised as a result of suspected malicious acts
  - The integrity, confidentiality or authenticity of data (stored, transmitted or processed) is compromised, impacting up to 5% or more than 1 million users in the Union, whichever is less
- **Providers of online marketplaces**: Article 11 of the implementation regulation considers an incident significant if any of the following conditions are met:
  - An online service is completely unavailable, affecting the lesser of 5% of users or up to 1 million users in the Union
  - Limited availability impacts more than 5% of users or more than 1 million users in the Union, whichever is less
  - The confidentiality, integrity or authenticity of data (stored, transmitted or processed) is compromised due to suspected malicious acts
  - The confidentiality, integrity or authenticity of data (stored, transmitted or processed) is compromised, impacting up to 5% or more than 1 million users in the Union, whichever is less
- **Providers of online search engines**: Article 12 of the implementation regulation considers an incident significant if any of the following conditions are met:
  - An online search engine is completely unavailable, impacting 5% of users or more than 1 million users in the Union, whichever is less
  - Limited availability impacts the lesser of 5% or more than 1 million users in the Union
  - The confidentiality, integrity or authenticity of data (stored, transmitted or processed) is compromised due to suspected malicious action(s)
  - The confidentiality, integrity or authenticity of data (stored, transmitted or processed) is compromised, impacting the lesser of 5% or more than 1 million users in the Union
- **Social networking services platforms**: Article 13 of the implementation regulation considers an incident involving social networking services platforms significant if any of the following conditions are met:
  - A social networking service platform is unavailable to more than 5% of the users in the EU or more than 1 million users, whichever is less
  - Limited availability impacts 5% or at least 1 million users in the EU, whichever is less
  - The confidentiality, integrity or authenticity of data (processed, stored or transmitted) is compromised due to a suspected malicious act
  - The confidentiality, integrity or authenticity of data (processed, stored or transmitted) is compromised, impacting more than 5% of users or more than 1 million users in the EU, whichever is less
- **Trust service providers**: Article 14 of the implementation regulation considers an incident significant if any of the following conditions are met:
  - A service is completely unavailable for more than 20 minutes
  - A service is unavailable to users or relying parties for more than one hour within a week.
  - Limited availability impacts the lesser of 1% of users or relying parties in the Union or more than 200,000 users or relying parties in the Union
  - Physical access to a restricted area housing network and information systems is compromised, affecting areas where access is limited to trusted personnel
  - The confidentiality, integrity or authenticity of data (stored, transmitted or processed) is compromised, impacting the lesser of 0.1% or more than 100 users or relying parties in the Union

### Notice and Reporting Requirements

NIS2 requires entities to produce a notice and five reports, detailed below. Member states may impose additional reporting requirements or further specify the content details. The destination for report submissions (e.g., addresses) will be defined by individual member states.

Note that the reporting obligations under NIS2 align with similar individuals in other jurisdictions (e.g., the U.S.).

| Requirement | Reference |When |Content |Who to notify |
|---|---|---|---|---|
|Notification to those potentially impacted| Article 23, paragraph 2| Without undue delay| <ul><li>An incident occured</li><li>Recipient may be affected</li><li>Measures, remedies, or actions recipients can take for this incident and in general.</li><li>Inform the recipients of the cyber threat itself</li></ul>| Those potentially impacted|
|An early warning| Article 23, paragraph 4, item a| Without undue delay/within 24 hours of becoming aware|<ul><li>A significant incident is suspected</li><li>Suspected cause (unlawful or malicious)</li><li>If there is the potential for cross-border impact</li></ul>| CSIRT or competent authority|
|Incident notification to CSIRT or comptent authority| Article 23, paragraph 4, item b| Without undue delay/within 72 hours of becoming aware|<ul><li>Initial assessment of the signicant incident</li><li>Severity and impact</li><li>Indicators of comporomise if available</li><li>Measures taken to mitigate the incident</li></ul>| CSIRT or competent authority|
|Intermediate report| Article 23, paragraph 4, item c| As requested by CSIRT or competent authority| Status at a point in time| CSIRT or competent authority|
|Final report| Article 23, paragraph 4, item d| No later than one month after submitting the incident reporting|<ul><li>Detailed description, including security and impact</li><li>Nature of the threat</li><li>Root cause</li><li>Measures taken to mitigate the incident</li><li>Lessons learned</li></ul>| CSIRT or competent authority|
| Progress report| Article 23, paragraph 4, item e| As required | NIS2 is silent on the content| CSIRT or competent authority|

### Harmonization and Reciprocity

Harmonization and reciprocity are important for globally operating or cross-sector organizations, especially those active across multiple EU member states, as they help reduce both the complexity and cost of compliance.

Harmonization aims to align and minimize conflicting or redundant regulatory obligations. Reciprocity allows acceptance by one authority to meet the requirements of another. NIS2 establishes a cyber hygiene standard across the EU, recognizing the likelihood of incidents spanning member states and sectors. The White House is similarly leading efforts for the U.S. and its allies.

Reciprocity can be challenging to grasp. NIST defines reciprocity as a “mutual agreement among participating organizations to accept each other’s security assessments in order to reuse information system resources and/or to accept each other’s assessed security posture in order to share information.”

Reciprocity aims to reduce the compliance burden on organizations without compromising the intended goals of NIS2. It does not eliminate the need for due diligence. Instead, reciprocity allows reporting to one authority to satisfy the requirements of others, either fully or partially. The specific differences, or deltas, will only become clear once the member states integrate NIS2 into their legislative frameworks.

Article 10 refers to these principles directly in four paragraphs:

> “4. The CSIRTs shall cooperate and, where appropriate, exchange relevant information in accordance with Article 29 with sectoral or cross-sectoral communities of essential and important entities.”
>
> “7. …may establish cooperation relationships with third countries’ national computer security incident response teams…Member States shall facilitate effective, efficient and secure information exchange with those third countries…The CSIRTs may exchange relevant information with third countries…including personal data in accordance with Union data protection law.”
>
> “8. The CSIRTs may cooperate with third countries…for the purpose of providing them with cybersecurity assistance.”
>
> “10. Member States may request the assistance of ENISA in developing their CSIRTs.”

And most directly, in paragraph 6 of Article 23:

> “Where appropriate, and in particular where the significant incident concerns two or more Member States, the CSIRT, the competent authority or the single point of contact shall inform, without undue delay, the other affected Member States and ENISA of the significant incident…”

[NIS2 Chapter 3 (Articles 14 through 19)](https://www.nis-2-directive.com/NIS_2_Directive_Articles.html) addresses cooperation at Union and international levels, including the establishment of “European cyber crisis liaison organization network (EU-CyCLONe)” in Article 16.

[NIS2 Chapter 6 (Articles 29 through 30)](https://www.nis-2-directive.com/NIS_2_Directive_Articles.html) focuses on information sharing.

### Update the IRP

Companies should review and update their incident response plans (IRPs) and related activities accordingly,
recognizing that any gaps may need to be filled as member states implement NIS2. The IR team should partner with
the legal, finance, compliance, security, IT and risk management departments within the organization.

Implementing all cybersecurity measures required by NIS2 will reduce the likelihood of incidents, especially
significant ones; however, incidents may still occur.

The IR team’s responsibility in complying with NIS2 is to provide relevant, accurate information to decision-makers in
a timely manner.

When reviewing plans and activities for updates:

- Identify where the organization operates or where it delivers products or services and stay informed as member states progress in their implementation of NIS2 and its related regulations.
- Global organizations should examine connections between incidents in the EU and reporting obligations outside the EU. For example, a publicly traded company may need to report to both EU member states and the SEC.
- Incorporate the production and delivery of Notices and Reports (as described above) in the IRP to inform those potentially impacted (e.g., customer, vendors, partners and stakeholders). Produce templates and establish mechanisms with the understanding that updates may be necessary as member states implement NIS2. Also, recognize that the same template may be required in multiple languages. 
- Remember, compliance is highly reliant on the necessary information being provided to the appropriate decision-makers, allowing determinations to be made “without unreasonable delay” as notices and reports are produced.
- Review and update the corporate policy for determining what constitutes a “significant” incident. Identify key stakeholders and decision-makers, along with the information they need for decision-making.
- Review applicable articles of the implementation regulation and incorporate relevant criteria into the decision-making process.
- Incorporate the process and criteria of determining “significant” incidents into the IRP, with the understanding that this will evolve as member states implement NIS2. Be sure to include the relevant sections of the implementation regulation.
- Review the role and priority of law enforcement.
- Test the updated IRP through tabletop exercises, perform a post-mortem and update the plan accordingly.