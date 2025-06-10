---
title: Application Security Policy
description: The SC2 Privacy Policy Update Policy and Procedure
summary: This document outlines the Application Security Policy for our applications, which incorporates best practices from leading application security frameworks, including NIST 800-218, the SSDF and the OWASP SAMM.
date: 2025-04-16
weight: 2
taxonomies:
  SCF:
    - "SEA-01"
    - "SEA-01.2"
    - "TDA-01"
    - "TDA-01.1"
    - "TDA-01.2"
    - "TDA-02"
    - "TDA-05"
    - "TDA-06"
    - "TDA-06.1"
    - "TDA-06.2"
    - "TDA-06.4"
    - "TDA-06.5"
    - "TDA-09"
    - "VPM-01"
    - "WEB-01"
    - "RSK-03"
    - "RSK-04"
    - "RSK-09"
    - "PRM-04"
    - "MON-01"
    - "CFG-02"
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

This document outlines the Application Security Policy at {{ config.extra.organization }}, which incorporates best practices from leading application security frameworks, including NIST 800-218, the SSDF and the OWASP SAMM.

{{ config.extra.organization }}’s commitment to application security means all software applications designed, developed or implemented will be produced following established best practices to deliver applications at the appropriate level of security. All applications will follow this policy, which provides a common guideline to follow established secure
software development principles and procedures.

## Scope

This policy applies to all software applications designed, developed or implemented (excluding commercial off-the-shelf software) at {{ config.extra.organization }}. Specifically, this includes:

- Server/client/mainframe software applications
- Cloud-based software using shared cloud infrastructure
- Mobile applications delivered both internally and through public application stores
- Operational and IoT-embedded software

## Foundational Practices

This section establishes clear expectations for secure software development minimums at {{ config.extra.organization }}. This begins with the organization’s established risk culture and tolerance levels for incorporating security practices into the SDLC. This includes data privacy and safety considerations, regulatory compliance, corporate ethics and values, resiliency and integrity of the computing environment, and maturity expectations within the SDLC. 

To enable the organization to adopt a foundational policy for secure application development, {{ config.extra.organization }} establishes the expectation that employees, corporate processes and technology are in place to implement this secure software development policy. This includes five key practices:

1. Define security requirements and expectations upfront before development begins and then apply them throughout the SDLC.
1. All members of the SDLC have a role in contributing security to application development. Security roles and responsibilities for the SDLC are defined in the job function or role description.
1. {{ config.extra.organization }} has invested in various development tools and code validation capabilities to automate the software development pipeline. These are used throughout the SDLC to generate artifacts to support the assertion of a secure software build.
1. Security considerations are incorporated into the development process at various stages so that code is verified it will meet company expectations for secure software development when completed.
1. All code is developed in the approved development environment, which incorporates protection measures to ensure the confidentiality and integrity of the developed code.

## Enhanced Practices

Enhanced practices rely on the foundations established in the previous section. However, enhanced practices operate through three Ps of secure software development (see Figure 1).

{% mermaid() %}
---
title: The 3 Ps of Secure Software Development
---
flowchart TD
    A[Protect] --> B[Produce]
    B --> C[Patch]
    C --> A
{% end %}

This continuous cycle of monitoring and remediation throughout the SDLC is driven by {{ config.extra.organization }} secure development standards and test scripts to validate compliance with application security requirements. Security requirements are specific and identified during the design phase, with inputs from customers, business units and regulatory requirements. Requirements are then incorporated into test scripts to ensure application security and functionality through manual and automated testing.

### Protect The Application

To ensure code integrity, {{ config.extra.organization }} requires that code is protected from theft, tampering and unauthorized access through all phases of the SDLC. This includes protection from intentional and accidental malicious or benign changes. This also includes theft or unauthorized disclosure, which may harm {{ config.extra.organization }}’s trade secrets and expose the software to undiscovered security flaws.

To ensure supply chain security for customers and downstream integrators, {{ config.extra.organization }} maintains a verification checksum for each version release to provide assurance code has not been tampered with. {{ config.extra.organization }} also maintains a historical repository of prior software versions, if applicable, to provide a source for research and discovery of downstream vulnerabilities after release.

### Produce The Application

To ensure the most cost-efficient and secure delivery of applications, {{ config.extra.organization }} strives to release minimal security vulnerabilities in all shipped code. To achieve this goal, {{ config.extra.organization }} adheres to the following secure
application development principles:

- **Secure design**: Developing secure applications begins well before the design phase, as demonstrated inthis policy. However, the design phase is critical to meeting security requirements and mitigating security risks. During this phase, {{ config.extra.organization }} will conduct threat modeling and risk assessments to determine what security risks the applications will likely face during operation and how the application’s design and architecture should mitigate those risks. This review also verifies the design will meet security requirements and address identified risks.
- **Secure development**: Creating secure code begins with following secure software development practices. This includes using approved function calls and libraries already assured of having a secure implementation, secure error handling, input validation and other well-defined secure coding practices. Rather than redeveloping and duplicating new code, {{ config.extra.organization }} developers are encouraged to reuse existing, reviewed, secure code when possible. This has the added benefit of reducing costs and expediting development timelines. This is particularly encouraged for software functions that include security features, such as cryptographic modules and protocols. \
Automated and manual code reviews must be conducted before any developed code can be put into production. This includes automated tools to identify common coding security errors and test scripts, and a review process for developers to investigate the source of the error once identified.
- **Secure defaults**: Application settings and defaults should be preconfigured to a secure state, and then security can be reduced based on user configuration or risk assessment. This includes secure defaults in both the development environment and the developed software. The compiler, interpreter and build processes are configured within the development environment to use secure versions and configurations during build time for execution security.\
Within the developed software, secure defaults include reusing well-secured software libraries, increasing supply chain security assurance and reducing the likelihood of introducing vulnerabilities due to an external library. Lastly, the default setting for user configurations must be set to the most secure state by default when the application is shipped.

### Patch The Application

The responsibility to develop and deliver secure code to {{ config.extra.organization }}’s customers does not end when the code is shipped. Our commitment to providing secure applications continues throughout the lifecycle of our applications. This includes processes to accept software vulnerability submissions from the public, such as through a bug bounty program. Once a tip is identified as a potential vulnerability through testing or a user submission, it is
confirmed and documented.

Vulnerabilities that have been confirmed and documented are entered into the vulnerability remediation workstream (specify the workstream) to assess, prioritize and put in place steps to remediate the vulnerability.

At least quarterly, the workstream is reviewed to identify common root causes that introduced vulnerabilities. This allows {{ config.extra.organization }} to continuously improve its secure application development processes and reduce the frequency of future vulnerabilities.