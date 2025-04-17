---
title: "Regulatory Statements"
description: "Statements on in-scope regulations"
date: 2022-12-08
weight: 5
taxonomies:
  TSC2017:
    - CC5.1
    - P6.6
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

## HIPAA

Our products and other {{ config.extra.organization }} systems may hold PHI/ePHI; therefore, {{ config.extra.organization }} is HIPAA compliant as a Business Associate. Throughout our policies we include the requirements noted in the following section.

What are the requirements to attain and maintain HIPAA compliance (not certification) as a Business Associate?

In summary, HIPAA requires us to do the following (all of which we comply with or perform):

1. Put safeguards in place to protect patient health information.

2. Reasonably limit uses and sharing to the minimum necessary to accomplish the intended purpose.

3. Have agreements in place with any service providers that perform covered functions or activities for you. These agreements (BAAs) are to ensure that these services providers _(Business Associates)_ only use and disclose patient health information properly and safeguard it appropriately.

4. Have procedures in place to limit who can access patient health information and implement a training program for you and your employees about how to protect your patient health information.

According to the U.S. Department of Health & Human Services _(_[_https://www.hhs.gov/hipaa/for-professionals/privacy/guidance/business-associates/index.html_](https://www.hhs.gov/hipaa/for-professionals/privacy/guidance/business-associates/index.html)_):_

"The Privacy Rule allows covered providers and health plans to disclose protected health information to these "business associates" if the providers or plans obtain satisfactory assurances that the business associate will use the information only for the purposes for which it was engaged by the covered entity, will safeguard the information from misuse, and will help the covered entity comply with some of the covered entity's duties under the Privacy Rule. Covered entities may disclose protected health information to an entity in its role as a business associate only to help the covered entity carry out its health care functions – not for the business associate's independent use or purposes, except as needed for the proper management and administration of the business associate."

In the case of holding data for a Covered Entity, {{ config.extra.organization }} has a Business Associate Contract available.

We safeguard data in the following ways:

(The following is copied - edited in places for brevity - from [https://www.truevault.com/blog/how-do-i-become-hipaa-compliant.html](https://www.truevault.com/blog/how-do-i-become-hipaa-compliant.html))

1. **Security Rule**
1. **Privacy Rule**

### Security Rule

The **Security Rule** covers the following 3 areas:

1. **Technical Safeguards**
1. **Physical Safeguards**
1. **Administrative Safeguards**

#### Technical

There are 5 standards listed under the Technical Safeguards section.

1. **Access Control**
1. **Audit Controls**
1. **Integrity**
1. **Authentication**
1. **Transmission Security**

When you break down the 5 standards there are 9 things that need to be implemented, and that {{ config.extra.organization }} has implemented:

1. **Access Control** - **Unique User Identification** : Assign a unique name and/or number for identifying and tracking user identity.
1. **Access Control** - **Emergency Access Procedure:** Establish (and implement as needed) procedures for obtaining necessary ePHI during an emergency.
1. **Access Control - Automatic Logoff:** Implement electronic procedures that terminate an electronic session after a predetermined time of inactivity.{{ config.extra.organization }} NOTE re: compensating control: As allowed by the safeguard standards (see page 6 here: [https://www.hhs.gov/sites/default/files/ocr/privacy/hipaa/administrative/securityrule/techsafeguards.pdf](https://www.hhs.gov/sites/default/files/ocr/privacy/hipaa/administrative/securityrule/techsafeguards.pdf)) while we don't terminate all sessions, we do the following to protect ePHI:
   1. After 15 minutes of inactivity, computers automatically lock so that any ePHI that might be displayed is hidden from view.
   1. Educate and reinforce that employees are to lock their computer when leaving their desks.
   1. For multi-user workstations, all logged-in sessions are terminated after working hours.
1. **Access Control** - Encryption and Decryption: Implement a mechanism to encrypt and decrypt ePHI.
1. **Audit Controls** : Implement hardware, software, and/or procedural mechanisms that record and examine activity in information systems that contain or use ePHI.
1. **Integrity** - Mechanism to Authenticate ePHI: Implement electronic mechanisms to corroborate that ePHI has not been altered or destroyed in an unauthorized manner.
1. **Authentication** - Implement procedures to verify that a person or entity seeking access to ePHI is the one claimed.
1. **Transmission Security - Integrity Controls** : Implement security measures to ensure that electronically transmitted ePHI is not improperly modified without detection until disposed of.
1. **Transmission Security - Encryption**: Implement a mechanism to encrypt ePHI whenever deemed appropriate.

#### Physical

There are 4 standards in the Physical Safeguards section.

1. **Facility Access Controls**
1. **Workstation Use**
1. **Workstation Security**
1. **Device and Media Controls**

When you break down the 4 standards there are 10 things that need to be implemented, and that {{ config.extra.organization }} has implemented:

1. **Facility Access Controls** - Contingency Operations: Establish (and implement as needed) procedures that allow facility access in support of restoration of lost data under the disaster recovery plan and emergency mode operations plan in the event of an emergency.
1. **Facility Access Controls** - **Facility Security Plan** : Implement policies and procedures to safeguard the facility and the equipment therein from unauthorized physical access, tampering, and theft.
1. **Facility Access Controls - Access Control and Validation Procedures** : Implement procedures to control and validate a person's access to facilities based on their role or function, including visitor control, and control of access to software programs for testing and revision.
1. **Facility Access Controls - Maintenance Records** : Implement policies and procedures to document repairs and modifications to the physical components of a facility which are related to security (e.g. hardware, walls, doors, and locks).
1. **Workstation Use** : Implement policies and procedures that specify the proper functions to be performed, the way those functions are to be performed, and the physical attributes of the surroundings of a specific workstation or class of workstation that can access ePHI.
1. **Workstation Security** : Implement physical safeguards for all workstations that access ePHI, to restrict access to authorized users.
1. **Device and Media Controls - Disposal** : Implement policies and procedures to address the final disposition of ePHI, and/or the hardware or electronic media on which it is stored.
1. **Device and Media Controls - Media Re-Use** : Implement procedures for removal of ePHI from electronic media before the media are made available for re-use.
1. **Device and Media Controls - Accountability** : Maintain a record of the movements of hardware and electronic media and any person responsible therefore.
1. **Device and Media Controls - Data Backup and Storage** : Create a retrievable, exact copy of ePHI, when needed, before movement of equipment.

#### Administrative

There are 9 standards under the Administrative Safeguards section.

1. **Security Management Process**
1. **Assigned Security Responsibility**
1. **Workforce Security**
1. **Information Access Management**
1. **Security Awareness and Training**
1. **Security Incident Procedures**
1. **Contingency Plan**
1. **Evaluation**
1. **Business Associate Contracts and Other Arrangements**

When you break down the 9 standards there are 18 things that {{ config.extra.organization }} needs to implement, and have been implemented:

1. **Security Management Process - Risk Analysis** : Perform and document a risk analysis to see where PHI is being used and stored in order to determine all the ways that HIPAA could be violated.
1. **Security Management Process - Risk Management**: Implement sufficient measures to reduce these risks to an appropriate level.
1. **Security Management Process - Sanction Policy**: Implement sanction policies for employees who fail to comply.
1. **Security Management Process - Information Systems Activity Reviews**: Regularly review system activity, logs, audit trails, etc.
1. **Assigned Security Responsibility - Officers**: Designate HIPAA Security and Privacy Officers.
1. **Workforce Security - Employee Oversight**: Implement procedures to authorize and supervise employees who work with PHI, and for granting and removing PHI access to employees. Ensure that an employee's access to PHI ends with termination of employment.
1. **Information Access Management - Multiple Organizations** : Ensure that PHI is not accessed by parent or partner organizations or subcontractors that are not authorized for access.
1. **Information Access Management - ePHI Access** : Implement procedures for granting access to ePHI that document access to ePHI or to services and systems that grant access to ePHI.
1. **Security Awareness and Training - Security Reminders** : Periodically send updates and reminders about security and privacy policies to employees.
1. **Security Awareness and Training - Protection Against Malware** : Have procedures for guarding against, detecting, and reporting malicious software.
1. **Security Awareness and Training - Login Monitoring** : Institute monitoring of logins to systems and reporting of discrepancies.
1. **Security Awareness and Training - Password Management** : Ensure that there are procedures for creating, changing, and protecting passwords.
1. **Security Incident Procedures - Response and Reporting** : Identify, document, and respond to security incidents.
1. **Contingency Plan - Contingency Plans** : Ensure that there are accessible backups of ePHI and that there are procedures for restore any lost data.
1. **Contingency Plan - Contingency Plans Updates and Analysis** : Have procedures for periodic testing and revision of contingency plans. Assess the relative criticality of specific applications and data in support of other contingency plan components.
1. **Contingency Plan - Emergency Mode** : Establish (and implement as needed) procedures to enable continuation of critical business processes for protection of the security of ePHI while operating in emergency mode.
1. **Evaluations** : Perform periodic evaluations to see if any changes in your business or the law require changes to your HIPAA compliance procedures.
1. **Business Associate Agreements** : Have special contracts with business partners who will have access to your PHI in order to ensure that they will be compliant. Choose partners that have similar agreements with any of their partners to which they are also extending access.

### PRIVACY RULE

The Privacy Rule requires Business Associates to do the following, all of which we comply with or perform as needed:

1. **Do not allow any impermissible uses or disclosures of PHI.**
1. **Provide breach notification to the Covered Entity.**
1. **Provide either the individual or the Covered Entity access to PHI.**
1. **Disclose PHI to the Secretary of HHS, if compelled to do so.**
1. **Provide an accounting of disclosures.**
1. **Comply with the requirements of the HIPAA Security Rule.**

## **GLBA**

The need to abide by GLBA's Privacy Rule

[https://www.ftc.gov/tips-advice/business-center/guidance/how-comply-privacy-consumer-financial-information-rule-gramm](https://www.ftc.gov/tips-advice/business-center/guidance/how-comply-privacy-consumer-financial-information-rule-gramm)

[https://digitalguardian.com/blog/what-glba-compliance-understanding-data-protection-requirements-gramm-leach-bliley-act](https://digitalguardian.com/blog/what-glba-compliance-understanding-data-protection-requirements-gramm-leach-bliley-act)

Because {{ config.extra.organization }} is not a financial institution, we do not need to be, and cannot be, GLBA compliant.

However, because we receive and store NPI from financial institutions, we are limited by proxy in how we use that NPI. We demonstrate our commitment to safeguarding that NPI in the following manners:

1. We abide by the GLBA Financial Privacy Rule; however, as we are not a financial institution we do not have to offer opt-outs for financial institution consumers.

1. We abide by the GLBA Safeguards Rule

   In short, the Safeguards Rule requires an Information Security Program with appropriate and respective systems and oversight for privacy and protection of NPI.

   Details of the requirements are found here:

   1. [https://www.ecfr.gov/current/title-16/part-314](https://www.ecfr.gov/current/title-16/part-314)
   1. [https://www.ftc.gov/tips-advice/business-center/guidance/how-comply-privacy-consumer-financial-information-rule-gramm](https://www.ftc.gov/tips-advice/business-center/guidance/how-comply-privacy-consumer-financial-information-rule-gramm)

1. We guard against Pretexting (Social Engineering) by consistent and as-needed security awareness training.

1. We never distribute (give away or sell) customer data to third-parties, which includes how we treat customers' consumer data (which may contain NPI).

1. Our IT Security Protocol clearly details how we abide by all the above rules. Also, the OnBoard MSA shows that ALL posted content is solely owned by the customer and that {{ config.extra.organization }} has no inherent rights to it.

### What NPI is and is not

(from [https://www.ftc.gov/tips-advice/business-center/guidance/how-comply-privacy-consumer-financial-information-rule-gramm](https://www.ftc.gov/tips-advice/business-center/guidance/how-comply-privacy-consumer-financial-information-rule-gramm))

NPI, according to GLBA, is defined as:

- any information an individual gives you to get a financial product or service (for example, name, address, income, Social Security number, or other information on an application);
- any information you get about an individual from a transaction involving your financial product(s) or service(s) (for example, the fact that an individual is your consumer or customer, account numbers, payment history, loan or deposit balances, and credit or debit card purchases); or
- any information you get about an individual in connection with providing a financial product or service (for example, information from court records or from a consumer report).

NPI does not include information that one has a reasonable basis to believe is lawfully made "publicly available." In other words, information is not NPI when one has taken steps to determine:

1. that the information is generally made lawfully available to the public; and
2. that the individual can direct that it not be made public and has not done so.

## FERPA

According to **Ed.gov** a FERPA-Compliant Third-Party provider:

- Performs an institutional service or function for which the agency or institution would otherwise use employees
- Has been determined to meet the criteria set forth in the school's or district's annual notification of FERPA rights for being a school official with a legitimate educational interest in the education records
- Is under the direct control of the agency or institution with respect to the use and maintenance of education records, and
- Uses education records only for authorized purposes and may not re-disclose PII from education records to other parties, unless the provider has specific authorization from the school or district to do so and it is otherwise permitted by FERPA. (See [here](https://www.ecfr.gov/current/title-34/part-99) for more details).

Our _"{{ config.extra.organization }} IT Security Protocol"_ clearly details how we abide by all the requirements necessary to safeguard PII. This is available in our Trust Center (upon a signed MNDA).

We never distribute (give away or sell) customer data to third parties, which includes how we treat customers' consumer data (which may contain PII or FERPA-protected data)

The OnBoard Master Subscription Agreement shows that ALL posted content is solely owned by the customer and that {{ config.extra.organization }} has no inherent rights to it.

For Microsoft's overview of their FERPA compliance, please see here:

[https://www.microsoft.com/en-us/trustcenter/compliance/ferpa](https://www.microsoft.com/en-us/trustcenter/compliance/ferpa)

For Azure's compliance offerings, including FERPA, please see the PDF available here:

[https://docs.microsoft.com/en-us/compliance/regulatory/offering-home](https://docs.microsoft.com/en-us/compliance/regulatory/offering-home)

## Quebec Bill 64 (Law 25)

Per the [text of the law](https://www.publicationsduquebec.gouv.qc.ca/fileadmin/Fichiers_client/lois_et_reglements/LoisAnnuelles/en/2021/2021C25A.PDF) {{ config.extra.organization }} commits to sending data breach notifications to [Le Commission d’accès à l’information du Quebec](https://www.cai.gouv.qc.ca/english/), as well as to any affected individuals in the event of a breech involving PII or other confidential information stored in {{ config.extra.organization }}' systems. Notifications will be sent as soon as possible after the incident occurs. {{ config.extra.organization }} will also maintain a record of all security incidents.
