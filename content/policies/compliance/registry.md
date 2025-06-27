---
title: "Registry of Regulatory Statutory and Contractual Requirements"
description: "Statements on in-scope regulations"
weight: 10
taxonomies:
  SCF:
    - GOV-01
    - PRI-01
    - PRI-01.2
    - PRI-01.3
    - PRI-01.4
    - PRI-02
    - PRI-02.1
    - PRI-02.2
    - PRI-03
    - PRI-03.1
    - PRI-03.2
    - PRI-03.3
    - PRI-03.4
    - PRI-03.6
    - PRI-03.8
    - PRI-04
    - PRI-04.1
    - PRI-05
    - PRI-05.1
    - PRI-05.4
    - PRI-05.5
    - PRI-05.6
    - PRI-05.7
    - PRI-07
    - PRI-09
    - PRI-11
    - PRI-14.2
    - PRI-15
    - PRI-17
    - PRI-17.1
    - DCH-01
    - DCH-02
    - DCH-18.1
    - DCH-18.2
    - SAT-01
    - SAT-02
    - SAT-02.1
    - SAT-03
    - SAT-03.1
    - SAT-03.2
    - SAT-03.3
    - SAT-04
    - PRM-01
    - AST-04
    - CFG-08.1
    - CPL-01

extra:
  owner: SC2
  last_reviewed: 2025-04-16
  major_revisions:
    - date: 2025-02-11
      description: Initial version.
      revised_by: Ben Craton
      approved_by: Ben Craton
      version: "1.0"

---

The following document summarizes the regulatory, statutory, and contractual requirements that {{ org() }} must comply with. The table is organized by region and includes the type of requirement, owner, scope, source, encryption standards, and the date the requirement came into force.

## United States
### Azure

| Type     | Owner        | Scope                                | Source                                                                              | Encryption standards | In force     |
| -------- | ------------ | ------------------------------------ | ----------------------------------------------------------------------------------- | -------------------- | ------------ |
| Contract | InfoSec Team | All Azure locations (US, UK, Canada) | [Azure EA](https://www.microsoft.com/en-us/licensing/licensing-programs/enterprise) | RSA 4096; AES-256    | 2016-Current |

#### Requirement

Partnership agreement with Information Security Policy requirements.

#### Description

Basic Security Requirements.

#### Consequences

Legal tort action

### Customer Contracts

| Type     | Owner        | Scope                                | Source                                                                              | Encryption standards | In force     |
| -------- | ------------ | ------------------------------------ | ----------------------------------------------------------------------------------- | -------------------- | ------------ |
| Contract | Revenue | All customer contracts               |  [Salesforce](https://www.salesforce.com/)                       |   | 2014-Current |

#### Requirement

Partnership agreement with Information Security Policy requirements.

#### Description

Basic Security Requirements.

#### Consequences
Legal tort action

### Vendor Contracts

| Type     | Owner   | Scope            | Source                                    | Encryption standards | In force     |
| -------- | ------- | ---------------- | ----------------------------------------- | -------------------- | ------------ |
| Contract | Revenue | Critical Vendors | [Salesforce](https://www.salesforce.com/) |                      | 2024-Current |

#### Requirement

Partnership agreement with Information Security Policy requirements.

#### Description
Basic Security Requirements.
#### Consequences
Legal tort action

### HIPAA

| Type       | Owner        | Scope                    | Source                                                                                   | Encryption standards | In force     |
| ---------- | ------------ | ------------------------ | ---------------------------------------------------------------------------------------- | -------------------- | ------------ |
| Regulation | InfoSec team | USA healthcare customers | [HIPAA](https://www.hhs.gov/hipaa/for-professionals/privacy/laws-regulations/index.html) | RSA 4096; AES-256    | 2018-current |

#### Requirement

> - ePHI Security awareness Training
> - HIPAA-compliant Policies
> - Signed NDA re: PHI from all employees
> - HIPAA NDA within 60 days of start of employment
> - Uses and disclosures of protected health information and other actions are consistent with the covered entity's privacy policies
> - Develop procedures that ensure the confidentiality and security of protected health information (PHI) when it is transferred, received, handled, or shared
> - Follow procedures that ensure the confidentiality and security of protected health information (PHI) when it is transferred, received, handled, or shared
> - Insure that only the minimum health information necessary to conduct business is to be used or shared"

#### Description

Requirements required as HIPAA compliant Business Associate; need to abide by Security (Technical, Physical, Administrative) and Privacy Rules.

[{{ org() }} Statements about HIPAA GLBA FERPA](@/policies/compliance/regulatory-statements.md)

#### Consequences

| Tier | Violation                                                                                                                                                                             | Penalty                                             |
| ---- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| 1    | A violation that the covered entity was unaware of and could not have realistically avoided, had a reasonable amount of care had been taken to abide by HIPAA Rules                   | Minimum fine of $100 per violation up to $50,000    |
| 2    | A violation that the covered entity should have been aware of but could not have avoided even with a reasonable amount of care. (but falling short of willful neglect of HIPAA Rules) | Minimum fine of $1,000 per violation up to $50,000  |
| 3    | A violation suffered as a direct result of “willful neglect” of HIPAA Rules, in cases where an attempt has been made to correct the violation                                         | Minimum fine of $10,000 per violation up to $50,000 |
| 4    | A violation of HIPAA Rules constituting willful neglect, where no attempt has been made to correct the violation                                                                      | Minimum fine of $50,000 per violation               |

### FERPA

| Type       | Owner        | Scope                                  | Source                                                             | Encryption standards | In force     |
| ---------- | ------------ | -------------------------------------- | ------------------------------------------------------------------ | -------------------- | ------------ |
| Regulation | InfoSec Team | USA educational institutions/customers | [FERPA](https://www2.ed.gov/policy/gen/guid/fpco/ferpa/index.html) | RSA 4096; AES-256    | 2018-current |

#### Requirement
Safeguard educational PII
#### Description

According to [Ed.gov](https://studentprivacy.ed.gov/ferpa), a FERPA-Compliant Third-Party provider:

> - Performs an institutional service or function for which the agency or institution would otherwise use employees;
> - Has been determined to meet the criteria set forth in the school’s or district’s annual notification of FERPA rights for being a school official with a legitimate educational interest in the education records;
> - Is under the direct control of the agency or institution with respect to the use and maintenance of education records; and
> - Uses education records only for authorized purposes and may not re-disclose PII from education records to other parties, unless the provider has specific authorization from the school or district to do so and it is otherwise permitted by FERPA. (See 34 CFR § 99.31(a)(1)(i))."

[{{ org() }} Statements about HIPAA GLBA FERPA](@/policies/compliance/regulatory-statements.md)

#### Consequences

Fines up to $1.5m not exceeding 10% of annual budget

### GLBA

| Type       | Owner        | Scope                   | Source                                                                    | Encryption standards | In force     |
| ---------- | ------------ | ----------------------- | ------------------------------------------------------------------------- | -------------------- | ------------ |
| Regulation | InfoSec Team | USA financial customers | [GLBA](https://www.fdic.gov/regulations/compliance/manual/8/viii-1.1.pdf) | RSA 4096; AES-256    | 2018-current |

#### Requirement
Privacy and Safeguard Rules

#### Description
> Because {{ org() }} is not a financial institution, we do not need to be, and cannot be, GLBA compliant.
> However, because we receive and store NPI from financial institutions, we are limited by proxy in how we use that NPI."

[{{ org() }} Statements about HIPAA GLBA FERPA](@/policies/compliance/regulatory-statements.md)

#### Consequences

Fines of up to $100,000 per violation, with fines for officers and directors of up to $10,000 per violation. May also include criminal penalties of up to five years in prison, and the revocation of licenses.

### NYCRR 500 Part 23

| Type        | Owner        | Scope        | Source                                                                                    | Encryption standards | In force     |
| ----------- | ------------ | ------------ | ----------------------------------------------------------------------------------------- | -------------------- | ------------ |
| Legislation | InfoSec Team | NY Customers | [NYCRR 500 Part 23](https://www.dfs.ny.gov/industry_guidance/guidance_documents/part_500) | RSA 4096; AES-256    | 2018-current |

#### Requirement
Notification to NY customers of breaches within 72 hours

#### Description
{{ org() }}' products hold confidential information of NY customers. Therefore, {{ org() }} complies with the NYDFS 500 Part 23 requirements for data protection and notification.

#### Consequences

Up to (1) $2,500 per day during which a violation continues (b) $15,000 per day in the event of any reckless or unsound practice or pattern of miscount, or © $75,000 per day in the event of a knowing and willful violation.

### California Privacy Rights Act (CPRA)

| Type        | Owner        | Scope                  | Source                                                                 | Encryption standards | In force     |
| ----------- | ------------ | ---------------------- | ---------------------------------------------------------------------- | -------------------- | ------------ |
| Legislation | InfoSec Team | California residents   | [CPRA](https://leginfo.legislature.ca.gov/faces/codes_displayText.xhtml?lawCode=CIV&division=3.&title=1.81.5.&part=4.&chapter=&article=) | RSA 4096; AES-256    | 2023-current |

#### Requirement
CPRA expands CCPA requirements to:

- Provide consumers with rights to correct inaccurate personal information
- Opt-out of both data sales **and sharing**
- Limit use of sensitive personal information (race, health data, geolocation)
- Conduct annual cybersecurity audits for high-risk processing
- Implement contractual data processing agreements with third parties
- Maintain 12-month data retention limits unless legally required

#### Description
The CPRA establishes enhanced privacy protections for California residents, applying to businesses that:

- Exceed $25M annual revenue
- Handle personal data of 100,000+ consumers/households
- Derive 50%+ revenue from selling/sharing consumer data

It introduces new obligations including a dedicated Privacy Protection Agency for enforcement and stricter rules for third-party data transfers. The law covers both employees and B2B contacts, unlike CCPA.

#### Consequences

- **Fines**: $2,500 per unintentional violation; $7,500 per intentional violation
- **Private right of action**: Available for breaches involving email/password combinations
- **Audit authority**: Mandatory compliance reviews for high-risk data processors
- **Global turnover penalties**: Up to 4% annual revenue for systemic violations

## North America

### The Personal Information Protection and Electronic Documents Act (PIPEDA)

| Type        | Owner        | Scope         | Source                                                                                | Encryption standards | In force     |
| ----------- | ------------ | ------------- | ------------------------------------------------------------------------------------- | -------------------- | ------------ |
| Legislation | InfoSec Team | Canadian Data | [PIPEDA](https://www.priv.gc.ca/en/privacy-topics/privacy-laws-in-canada/02_05_d_15/) | RSA 4096; AES-256    | 2020-current |

#### Requirement
Privacy Protection with the following explanation:

> Organizations covered by PIPEDA must generally obtain an individual's consent when they collect, use or disclose that individual's personal information. People have the right to access their personal information held by an organization. They also have the right to challenge its accuracy.
> Personal information can only be used for the purposes for which it was collected. If an organization is going to use it for another purpose, they must obtain consent again. Personal information must be protected by appropriate safeguards.

#### Description
PIPEDA sets the ground rules for how private-sector organizations collect, use, and disclose personal information in the course of for-profit, commercial activities across Canada. It also applies to the personal information of employees of federally-regulated businesses such as: banks, airlines, and telecommunication companies.  

See also [Dataguidance](https://www.dataguidance.com/sites/default/files/gdpr_v_pipeda.pdf)

#### Consequences

For offences punishable on summary conviction, fines do not exceed CAD 10,000 (approx. €6,610) per offense. For indictable offences, fines do not exceed CAD 100,000 (approx. €66,140) per offense.

### Quebec’s Bill 64 (Law 25)

| Type        | Owner        | Scope       | Source                                                             | Encryption standards | In force     |
| ----------- | ------------ | ----------- | ------------------------------------------------------------------ | -------------------- | ------------ |
| Legislation | InfoSec Team | Quebec Data | [Law 25](https://www.legisquebec.gouv.qc.ca/en/document/cs/p-39.1) | RSA 4096; AES-256    | 2022-current |

#### Requirement
Law 25 requires organizations to:

- make data breach notifications to Le Commission d’accès à l’information du Quebec
- Appoint a Data Protection Officer
- Ensure the following Data Subject rights:
  - Right to be informed
  - Right to access
  - Right to rectification
  - Right to erasure
  - Right to withdraw consent
  - Right to restrict processing
  - Right to data portability

#### Description
Law 25 grants new data protection rights to individuals residing in Quebec, along with increased obligations for the public and private organizations that handle their personal information. The organizations do not need to be based in Quebec for this law to affect them; if a company does business with residents of Quebec, they are subject to this law.

See also: [OneTrust](https://www.onetrust.com/blog/quebecs-law-25-what-is-it-and-what-do-you-need-to-know/)

#### Consequences

Law 25 increases the fines for non-compliance with privacy legislation. Private-sector entities are subject to fines ranging from $15,000 to $25,000,000 CAD, or an amount corresponding to four percent of worldwide turnover for the preceding fiscal year (whichever is greater).

The registry currently lacks dedicated sections for emerging AI governance frameworks. Based on {{ org() }}' operations and product capabilities, the following additions are recommended:

### NIST AI Risk Management Framework (AI RMF)

| Type | Owner | Scope | Source | Alignment | Status |
|------|-------|-------|--------|-----------|--------|
| Framework | Security Team | AI/ML development lifecycle | [NIST AI RMF](https://www.nist.gov/itl/ai-risk-management-framework) | SOC 2/ISO 27001 | Draft |

#### Requirement
Core functions for AI governance:

1. **Govern**: Establish AI risk culture
2. **Map**: Document system components/data flows
3. **Measure**: Implement quantitative ML testing
4. **Manage**: Continuous monitoring protocols

#### Description
Complements existing infosec programs with:

- Adversarial attack testing requirements
- Model card/documentation standards
- Bias detection metrics (disparate impact ratios)
- Third-party AI vendor assessment criteria

#### Consequences

- Required for U.S. federal contractors (DFARS 7021)
- Becomes contractual obligation for government clients

## EMEA

### EU-U.S., UK, and Swiss Data Privacy Frameworks (DPFs)  

| Type        | Owner               | Scope                       | Source                                                                 | Encryption Standards | In Force       |  
| ----------- | ------------------- | --------------------------- | ---------------------------------------------------------------------- | -------------------- | -------------- |  
| Framework   | European Commission | EU-U.S. Data Transfers      | [EU-U.S. DPF](https://www.dataprivacyframework.gov)                    | RSA 4096; AES-256    | 2023–current   |  
| Framework   | UK Government       | UK-U.S. Data Transfers      | [UK Extension](https://www.dataprivacyframework.gov)                  | RSA 4096; AES-256    | 2023–current   |  
| Framework   | Swiss Government    | Swiss-U.S. Data Transfers   | [Swiss-U.S. DPF](https://www.dataprivacyframework.gov)                | RSA 4096; AES-256    | 2023–current   |  

#### Requirement  

- **Certification**: Organizations must self-certify compliance with DPF Principles (notice, choice, accountability, security, data integrity, access, recourse/enforcement).
- **Data Protection**: Ensure personal data transfers meet adequacy standards equivalent to EU/UK/Swiss laws.  
- **Third-Party Transfers**: Bound by contractual obligations to maintain equivalent protections for onward data transfers.  
- **Enforcement**: Subject to oversight by the U.S. Federal Trade Commission (FTC) and cooperation with EU/UK/Swiss authorities.  

#### Description  
The **EU-U.S. DPF**, **UK Extension**, and **Swiss-U.S. DPF** are adequacy frameworks enabling lawful data transfers between the EU, UK, Switzerland, and U.S. organizations. {{ org() }}, Inc. has certified adherence to these frameworks, ensuring personal data receives protections comparable to GDPR, UK GDPR, and Swiss FADP. These frameworks replace the invalidated Privacy Shield and require organizations to implement safeguards like encryption (AES-256/RSA 4096), breach notification, and third-party accountability.  

#### Consequences  

- **Regulatory Action**: Non-compliance may lead to investigations by the FTC, EU DPAs, UK ICO, or Swiss FDPIC, with potential fines up to **4% of global revenue** (GDPR alignment).  
- **Binding Arbitration**: Individuals may invoke binding arbitration under the DPF if disputes remain unresolved.  
- **Suspension/Removal**: Organizations can be removed from the DPF list if violations persist, halting data transfers.


### European Union General Data Protection Regulation (GDPR)

| Type        | Owner         | Scope   | Source                        | Encryption standards | In force     |
| ----------- | ------------- | ------- | ----------------------------- | -------------------- | ------------ |
| Legislation | Security Team | EU Data | [GDPR](https://gdpr-info.eu/) | RSA 4096; AES-256    | 2018-current |

#### Requirement

> Data protection and privacy of personal information; right-to-be-forgotten, mandatory data breach notifications, mandatory data protection officers and fines of 4% or €20m; Align privacy policy with the new regulations
> Based on the IP address, ask site visitors to provide explicit permission for continued contact whenever they fill out a form to download a gated asset.
> Allow site visitors to specify what types of content they'd like to receive from {{ org() }}.

#### Description

Companies must ensure they have appropriate security measures in place to protect the personal data held.
This is the ‘integrity and confidentiality’ principle of the GDPR – also known as the security principle.

#### Consequences

Fines of up to €20 million (roughly $20,372,000), or 4 percent of worldwide turnover for the preceding financial year—whichever is higher

### EU Artificial Intelligence Act (AI Act)

| Type | Owner | Scope | Source | Standards | In Force |
|------|-------|-------|--------|-----------|----------|
| Regulation | Product Team | AI systems impacting EU residents | [EU AI Act](https://digital-strategy.ec.europa.eu/en/policies/european-approach-artificial-intelligence) | ISO/IEC 23053 ML metrics | 2025+ (Phased) |

#### Requirement
Categorizes AI systems by risk level:

- **Prohibited**: Social scoring, manipulative subliminal techniques
- **High-Risk**: Critical infrastructure, employment decisions, law enforcement
- **Limited Risk**: Chatbots requiring transparency disclosures
- **Minimal Risk**: Recommender systems, spam filters

#### Description
Applies to providers and deployers of AI systems affecting EU markets, requiring:

- Fundamental rights impact assessments for high-risk systems
- Technical documentation retention (10 years)
- Human oversight mechanisms
- Accuracy/robustness testing protocols

#### Consequences

- Fines up to €35M or 7% global turnover for prohibited AI violations
- Mandatory system recalls for non-compliant high-risk AI

### Bundesdatenschutzgesetz-new (BDSG) (Germany)

| Type        | Owner        | Scope                                 | Source                                                              | Encryption standards | In force     |
| ----------- | ------------ | ------------------------------------- | ------------------------------------------------------------------- | -------------------- | ------------ |
| Legislation | InfoSec Team | {{ org() }} customers residing in Germany | [BDSG](https://www.gesetze-im-internet.de/englisch_bdsg/index.html) | RSA 4096; AES-256    | 2018-current |

#### Requirement
"Privacy protection, with the following explanation:

> In general the rules of the BDSG-new do not apply if the GDPR is applicable (Sec. 1 V BDSG-new) because the GDPR is considered a superior rule of law. That means that as far as privacy rules are set by the GDPR EU-Member States are not allowed to enact national rules. Only as far as the GDPR provides for opening clauses, is there room for national rules.
#### Description

The purpose of the BDSG is especially to make use of the numerous opening clauses under the GDPR which enable Member States to specify or even restrict the data processing requirements under the GDPR.

As an EU-regulation the GDPR is considered a superior rule of law.

See also: [Deloitte](https://www2.deloitte.com/dl/en/pages/legal/articles/neues-bundesdatenschutzgesetz.html)

#### Consequences

Fines of up to €20 million (roughly $20,372,000), or 4 percent of worldwide turnover for the preceding financial year—whichever is higher

### Protection of Personal Information Act (POPI Act)

| Type        | Owner        | Scope             | Source                        | Encryption standards | In force     |
| ----------- | ------------ | ----------------- | ----------------------------- | -------------------- | ------------ |
| Legislation | InfoSec Team | South Africa Data | [POPIA](https://popia.co.za/) | RSA 4096; AES-256    | 2020-current |

#### Requirement
Privacy Protection with the following explanation:

> The purpose of this Act is to — give effect to the constitutional right to privacy, by safeguarding personal information when processed by a responsible party, subject to justifiable limitations that are aimed at—
>
> - (a) balancing the right to privacy against other rights, particularly the right of access to information; and
> - (b)protecting important interests, including the free flow of information within the Republic and across international borders;

See also [POPIA](https://popia.co.za/section-2-purpose-of-act/)

#### Description
POPIA is South Africs's Privacy Protection law is intended to regulate the procesing of personal information, force breach reporting, and enforce business' responsiblity to develop a clera data protection plan.  

This Act is heavily based off of the EU's GDPR.

See also [Dataguidance](https://www.dataguidance.com/sites/default/files/onetrustdataguidance_comparingprivacylaws_gdprvpopia.pdf)

#### Consequences

Section 109 sets a fine maximum of ZAR1 10 million (roughly $651,012.00).  

## APAC

### Privacy Act 1988 (Australia)

| Type        | Owner        | Scope                                   | Source                                                               | Encryption standards | In force     |
| ----------- | ------------ | --------------------------------------- | -------------------------------------------------------------------- | -------------------- | ------------ |
| Legislation | InfoSec Team | {{ org() }} customers residing in Australia | [Privacy Act 1988](https://www.oaic.gov.au/privacy/the-privacy-act/) | RSA 4096; AES-256    | 1988-current |

#### Requirement
Privacy rules and principles

> An APP entity is required to notify the OAIC and all affected individuals to whom the information relates where: (i) the APP entity holds personal information; and (ii) there is unauthorised access, disclosure of loss of that information; and (iii) such is likely to result in 'serious harm' to an individual.

Also requires that the entity notify the data breach to the OAIC and all affected individuals as soon as practicable after the entity becomes aware or reasonably believes that there may have been an eligible data breach.

#### Description
The Privacy Act 1988 (No. 119, 1988) (as amended) ('the Privacy Act') is Australia's consolidated data protection law which aims to promote the protection of individuals' privacy.
See also: [Dataguidance](https://www.dataguidance.com/sites/default/files/gdpr_v_australia.pdf)

#### Consequences

None specified

The Privacy Act does not detail specific security measures that must be in place and leaves this to the discretion to the entity insofar as the entity takes steps that are reasonable in the circumstances to protect the information.

Maximum penalty of $2.1 million for serious or repeated breaches of privacy will increase to not more than the greater of $10 million, or three times the value of any benefit obtained through the misuse of information, or 10 per cent of the entity's annual Australian turnover

### New Zealand Privacy Act

| Type        | Owner        | Scope            | Source                                                                                        | Encryption standards | In force     |
| ----------- | ------------ | ---------------- | --------------------------------------------------------------------------------------------- | -------------------- | ------------ |
| Legislation | InfoSec Team | New Zealand Data | [Privacy Act 2020](https://www.legislation.govt.nz/act/public/2020/0031/latest/LMS23223.html) | RSA 4096; AES-256    | 2020-current |

#### Requirement
Purpose of this Act

> The purpose of this Act is to promote and protect individual privacy by—
>
> - (a)
>   providing a framework for protecting an individual’s right to privacy of personal information, including the right of an individual to access their personal information, while recognising that other rights and interests may at times also need to be taken into account; and
> - (b)
>    giving effect to internationally recognised privacy obligations and standards in relation to the privacy of personal information, including the OECD Guidelines and the International Covenant on Civil and Political Rights."

#### Description
The Privacy Act 2020 provides the rules in New Zealand for protecting personal information and puts responsibilities on agencies and organizations about how they must do that. For example, people have a right to know what information your agency holds about them and a right to ask you to correct it if they think it is wrong.

See also [Privacy.org.nz](https://privacy.org.nz/tools/knowledge-base/view/209), [Natlawreview](https://www.natlawreview.com/article/less-two-weeks-to-go-new-zealand-privacy-act-commences-1-december-2020), and [HWLEbsworth](https://hwlebsworth.com.au/the-new-new-zealand-privacy-act-is-more-in-line-with-australias-but-there-are-still-some-stark-differences/).

#### Consequences
Quote from the Office of the Privacy Commisioner

>"the Tribunal has said that cases at the less serious end of the spectrum will range from $5,000 to $10,000, more serious cases can range from $10,000 to around $50,000, and the most serious cases will range from $50,000 upwards. The most the HRRT has awarded so far for a privacy matter is just over $168,000."

## Depreciated

### Privacy Shield

| Type       | Owner      | Scope       | Source                                                  | Encryption standards | In force  |
| ---------- | ---------- | ----------- | ------------------------------------------------------- | -------------------- | --------- |
| Regulation | Leadership | All EU data | [Privacy Shield](https://www.privacyshield.gov/welcome) | RSA 4096; AES-256    | 2020-2022 |

#### Requirement
Provides companies on both sides of the Atlantic with a mechanism to comply with data protection requirements when transferring personal data from the European Union to the United States in support of transatlantic commerce

#### Description

The EU–US Privacy Shield (PS) was a framework for regulating transatlantic exchanges of personal data for commercial purposes between the European Union and the United States. One of its purposes was to enable US companies to more easily receive personal data from EU entities under EU privacy laws meant to protect European Union citizens. Even though PS is being contested, {{ org() }} maintains the PS standards to better assure customers of the privacy of EU customer data.


#### Consequences

Loss of privacy shield. Potential for fines up $40k per violation or $40k per day for continuing violations
