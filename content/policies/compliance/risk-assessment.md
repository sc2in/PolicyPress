---
title: "Risk Assessment"
description: "Procedures for conducting a risk assessment on the ISMS & PIMS"
date: 2022-12-08
weight: 10
taxonomies:
  TSC2017:
    - A1.2
    - CC3.1
    - CC3.2
    - CC3.4
    - CC4.1
    - CC5.1
    - CC8.1
    - CC9.1
    - PI1.1
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

This risk assessment policy documents the authority of "{{ config.extra.organization }}" to conduct investigations and take actions as required to assess risks to {{ config.extra.organization }} and take mitigating actions to reduce, eliminate, or manage risks. This Risk Assessment Policy specifies how and when risk assessments will be done and who will be responsible for them.

This Risk Assessment Policy is intended to specify how to identify risk in order to remediate it. Risk assessments are conducted under the authority of {{ config.extra.organization }} Chief Technology Officer. {{ config.extra.organization }} Chief Technology Officer appoints staff to conduct risk assessments. All those involved with a risk assessment must fully cooperate with {{ config.extra.organization }} members conducting the assessment. Cooperation must be complete for both the risk assessment and the remediation process since this is a critical business function.

This Policy is approved by {{ config.extra.organization }}' leadership team.

## Scope

This Risk Assessment Policy applies to all systems and data on {{ config.extra.organization }}' network, owned by {{ config.extra.organization }}, or operated on behalf of {{ config.extra.organization }}. This policy is effective as of August 1, 2018 and does not expire unless superseded by another policy.

Risk assessments should look at services offered by projects such as web sites with specific project functionality or business functionality along with infrastructure such as computer networks, buildings and other infrastructure. The risk assessment should include security risk, privacy risk, and risk due to natural disasters to both infrastructure, equipment, data (confidentiality, integrity, and availability), loss of productivity, loss of revenue, and personnel. Although many risk assessments are specific to systems, the overall risk to {{ config.extra.organization }} should be considered as well as to {{ config.extra.organization }} clientele. Also, a general risk assessment of organizational functions should be periodically evaluated such as risks to {{ config.extra.organization }} network considering its structure and state of security in the world, physical security, risks of natural disasters, risks of man-made disasters, etc.

## Definitions

1. Hazard - Something that can cause harm, injury, sickness, or loss to an individual or an organization.
1. Risk - The chance that a threat or hazard will have an undesirable outcome combined with the amount of harm that may occur.
1. Risk Assessment - An examination of all possible risk along with implemented and non-implemented solutions to reduce, eliminate, or manage the risk.
1. Threat - A potential incident or activity which may be deliberate, accidental, or caused by nature which may cause physical harm to a person or financial harm to an organization.
1. Incident data retained for investigation will exclude any sensitive information that is not required for incident response, analysis, or by law, regulation, or {{ config.extra.organization }} policy.
1. Project – a new Product (e.g., OnSemble Cloud)

## Risk Assessment Participants and Skills

The staff members who perform the risk assessment should be familiar with computer technology and computer security in particular. The risk assessment leader should be the security officer or one of their staff members. The leader of the risk assessment team should have a minimum of 2 years computer security experience preferably in risk assessment. The other team members should have a minimum of 3 months computer security training and/or 1-year computer security experience.

The following employees constitute {{ config.extra.organization }}' Risk Assessment Team:

- Marc Huffman, CEO
- Tim Adair, Chief Product Officer
- Robin Fleming, Chief Technology Officer
- Warren McComb, Director of IT & Security
- Tim Taylor, CFO

Business owners and technical support staff that provide information for the risk assessment do not need to be experienced in either risk assessments or computer security.

## Risk Assessment Deliverables

Risk assessment deliverables include a risk assessment report with a risk reduction action plan (see {{ config.extra.organization }} Risk Reduction Action Plan Template) to manage or mitigate any unacceptable risks. The action plan may be included with the risk assessment report. The action plan will be an action plan for implementing additional controls and solutions to mitigate or manage risk. The action plan may define participants and actions to be taken during the implementation of the action plan.

## Risk Assessment Requirements

- A risk assessment is required when a new project _(see definitions)_ is started. This assessment will be performed within the scope of the project only and will only consider factors and equipment outside the project when it affects the risk to the project.
- A risk assessment is required when data associated with a project is stored on a different system than when the last security assessment was performed. This assessment will consider the change in risk due to the change in the storage location for the data and will only need to point out the differences from the last assessment unless the last assessment is inaccurate or out of date.
- If a risk assessment of any systems or applications has never been done, a risk assessment should be done.
- A risk assessment is required when the project or application(s) associated with the project are modified enough to add, remove, or modify data such that the sensitivity and security requirements may change.
- Risk assessments may be used to assess all risks to {{ config.extra.organization }}.
- A risk assessment should be done or reviewed on systems or applications no less than every two years. Risk assessments should look at services offered by projects such as web sites with specific project functionality or business functionality along with infrastructure such as computer networks, buildings and other infrastructure. The risk assessment should include security risk and risk due to natural disasters to both infrastructure, equipment, data (confidentiality, integrity, and availability), loss of productivity, loss of revenue, and personnel.
- A risk assessment is required when a new system is being purchased from a vendor or will be operated through a vendor.
- A risk assessment is required when a risk is perceived that has not been previously assessed.
- A risk assessment is required when the security classification of the data used on the system is changed.

## Risk Assessment Method

The risk assessment method is defined by the risk assessment process. The risk assessment process will be updated as required due to results of audits and incidents.

## Accountable Parties

Senior management is responsible for developing a risk assessment framework which can assess, remediate, and manage risk. A specific executive should sponsor risk management and work to communicate its value. The management must be representative of IT and the business functions performed by {{ config.extra.organization }}. Management must buy into the risk assessment and management process, communicate it clearly, and require it to be enforced.

A team or unit in {{ config.extra.organization }} should have an enterprise wide responsibility for promoting good risk management practices. This group would normally conduct the risk assessments and must be trained in risk management. The manager of the risk management group has access to all levels of management in {{ config.extra.organization }}. The risk management group manager maintains contact with external risk management and security specialists including those in government and commercial areas. The risk management group manager keeps current on security threats, technologies, and mitigation methods.

Staff members are expected to cooperate with other staff members who are conducting a risk assessment regarding equipment or systems they are responsible for. Remediation measures taken are the joint responsibilities the security officer and the business owner of the systems involved. Staff members that maintain or developed the system may be expected to work with the risk assessment staff to develop a risk remediation plan. Where security issues or risk extends beyond the system of the business owner, the judgement of the security officer will take priority.

The agency or organizational security officer is responsible for ensuring that risk assessments are performed in a timely manner. The security officer has authority to shut down services if serious risks caused by the services warrant a shutdown or due to seriously critical lack of cooperation by the service provider to provide required information. The security officer shall notify the provider of the service of a shutdown at least two weeks prior to a shutdown except in cases of emergencies.

The security officer will require both technical and business information to conduct a security assessment. The owner of the service and those who maintain the service will be responsible for providing required information to the security officer or staff within a two-week time period from the date of the request.

The security officer or staff will be responsible for providing an information request to the business owners or maintainers of the service. The information request should list required items for the risk assessment and be properly dated and signed by the security officer or authorized representative.

Once the risk assessment report is complete, responsible parties must tape appropriate remediation actions specified in the report within the specified time period. Someone must be assigned the task of remediation. An auditor or security officer does a follow up to be sure appropriate remediation steps were taken in a timely manner.

## Risk Assessment Steps

- Management defines scope of risk assessment and creates the risk assessment team with a focal point person to guide the process.
- If risk assessment procedures are not defined, the team should define them. The proper time and method of communicating the selected risk treatment options to the affected IT and business management should be included.
- Evaluate the system - Determine if the system is critical to {{ config.extra.organization }}' business processes and determine the data classification and security needs of the data on the system considering confidentiality, integrity, and availability needs.
- List the threats - List possible threat sources such as an exploitation of a vulnerability
- Identify vulnerabilities
- Evaluate security controls
- Identify probabilities
- Quantify damage (impact) - Categorize the damage and possibly place a dollar amount on the damage where possible. This will help when looking at cost of controls to reduce the risk
- Determine risk level - Use likelihood times impact to quantify the amount of risk.
- Determine affected parties should the risk materialize.
- Evaluate and recommend controls to reduce or eliminate risk - Identify existing controls and those that may further reduce probabilities or mitigate specific vulnerabilities. List specific vulnerabilities for the system and threat to help identify mitigating controls.
- Create the risk assessment report.
- The method of communicating the selected risk treatment options to the affected IT and business management and staff should be followed.
- Take recommended risk mitigation actions.
- Monitor the effectiveness of risk mitigation actions and document the results.

## Risk Assessment Findings

- Risk assessment reports and findings are confidential.
- Risk assessment report results and expected actions taken should be defined by management and the stakeholders.

## Risk Assessment Vulnerabilities

- All identified vulnerabilities will be assessed for impact and criticality. Vulnerabilities that are serious and unnecessary must be remediated as soon as possible as mandated by the Chief Security Officer or their empowered staff.
- Existing procedures, system controls, and management controls must first be identified and employed to control risk before adding new controls.

## Acceptable Risks

When the probability of threat materialization times maximum damage amount is less than $1000 annually, the risk is acceptable. For higher amounts, on a yearly basis, acceptance of the risk will depend on the cost of implementing measures to reduce the risk. If the risk cannot be reduced and the amount per year is greater than $50,000, the risk should be transferred by purchasing insurance.

## Risk Mitigation

- Options for mitigating risk shall be provided by the risk assessment including the following possibilities:
  - Reducing the chance of an occurrence of an event.
  - Reducing the damage due to an occurrence.
  - Avoiding the risk.
  - Transferring the risk by taking action such as purchasing insurance.
- Costs of implementing each control is considered and compared to the benefits, both cost and intangible, of implementing each control.
- Cost-benefit analysis is done to evaluate proposed controls versus risks. When the controls are evaluated, the benefits, costs, and cost savings of applying the controls both individually and in combination should be determined. Performance measures for determining the effectiveness of the new controls are created.
- Risks shall be ranked and the controls to be implemented are selected and a plan is created to implement the controls. Responsibilities for implementing the controls are determined and communicated. Budgeting and schedules are set and the expected outcome from mitigating the risks with the controls are documented. Residual risk after full implementation is considered.
- Decisions regarding residual risk are made whether to accept the risk, transfer the risk, or take other action including adding additional controls.
- Safeguard options for addressing high risk scenarios must be considered and utilized appropriately while the extent of risk reduction and benefits are considered. Cost-benefit analysis is done to evaluate safeguard options.
- If the cost of safeguard options or recommended risk controls is above the ability of the budget to cover the cost, the options and controls are prioritized to reduce as much risk as possible within the allowable budget.
- The method of communicating the selected risk treatment options to the affected IT and business management and staff shall be followed when the risk assessment report is completed.

## Enforcement

Since risk assessment is an important part of protecting data and systems for {{ config.extra.organization }}, employees that purposely violate this policy may be subject to disciplinary action up to and including denial of access, legal penalties, and/or dismissal. Any employee aware of any violation of this policy is required to report it to their supervisor or other authorized representative.

## Other Requirements

- Additional security, reliability requirements and control measures for systems that store, transmit, or receive sensitive (confidential, secret, or top secret) data should be established. Logical and physical access should be considered.
- Protection measures for all data must be communicated to stakeholders and users. The measures cover confidentiality, integrity, and availability of data in each sensitivity classification.
- Each system and project should have a plan to protect data through the lifecycle of the system and project to ensure the data is adequately protected from when it is created to when it is destroyed.
- A systematic risk assessment process must be developed. Skilled risk assessors and management must be a part of this process.
- The risk assessment process must be reviewed every year in the light of new risks and technologies. Skilled risk assessors must be a part of this process. Audits, inspections, and incidents that occurred over the last year are used to evaluate the effectiveness of the process. The risk assessment process must be re-issued if gaps or weaknesses are found.
- A third party should check the risk assessment strategy to evaluate its effectiveness objectively. This should be done at least every two years.
- Part of the risk assessment process must include a review by senior management, IT management and the business owners.
- A process must be developed and communicated which can establish the owner for data and for systems and system components.
- The expected results of the risk assessment report must be defined by management including the stakeholders and expected results must be agreed upon.
- Implement a process for monitoring the effectiveness of risk mitigation actions and safeguards across the enterprise. The process should cover documenting and reporting the results.
- For each project, a project risk log and a project issues log should be created. Management should review the logs regularly.

## Methodology

The Risk Assessment methodology used in the ISMS Risk Management process is in accord with the methodology described in **ISO 27005:2011 Information technology - Security techniques - Information security risk management**.
Step One - List all ISMS information security related assets relevant to {{ config.extra.organization }} information security, their owners and location.
Step Two - Estimate the value (i.e., cost incurred due to loss of CIA) of the related assets given their role and criticality within the business process.
Step Three - List vulnerabilities the assets are exposed to and the threats that may exploit those vulnerabilities. Step Four - Calculate the qualitative risk based on the formula: **RISK VALUE = HARM x PROBABILITY.**

**HARM** - Refers to the harm or cost that an event can cause to any one of the information security attributes (Confidentiality, Integrity and Availability) inherent to the assets. The impact can include different components: financial, reputational, legal, lost income, recovery costs, etc..

**PROBABILITY** - Refers to the likelihood of a threat successfully exploiting a vulnerability in an asset or group of assets. The threat and vulnerability pairing applicable to the respective assets are described in the Risk Assessment matrix.

**Tables of values**

| **HARM** | **DESCRIPTION**                              |
| :------: | -------------------------------------------- |
|    1     | The harm to the organization is **VERY LOW** |
|    2     | The harm to the organization is **LOW**      |
|    3     | The harm to the organization is **MEDIUM**   |
|    4     | The harm to the organization is **HIGH**     |
|    5     | The harm to the organization is **CRITICAL** |

<br/>

| **PROBABILITY** | **DESCRIPTION**                                |
| :-------------: | ---------------------------------------------- |
|        1        | The probability of such event is **VERY LOW**  |
|        2        | The probability of such event is **LOW**       |
|        3        | The probability of such event is **MEDIUM**    |
|        4        | The probability of such event is **HIGH**      |
|        5        | The probability of such event is **VERY HIGH** |

### Risk Treatment

This methodology considers 5 options to treat risks:

1. **Mitigate** - The risk is mitigated by controls, policies, procedures or any other means applied by {{ config.extra.organization }}
1. **Accept** - The risk is accepted by {{ config.extra.organization }} based upon the residual risk value and the risk acceptance criteria.
1. **Transfer** - The risk is transferred to a third party, e.g. the purchase of an insurance policy.
1. **Avoid** - The risk is avoided, i.e., the activity is not performed due to the nature of the inherent risk.
1. **Exclusion** - The risk is excluded because it is not considered in scope for {{ config.extra.organization }}.

### Risk Acceptance Criteria

- {{ config.extra.organization }} has decided to apply blanket acceptance of current risks rated less than or equal to 5,
- Based upon the unfavorable cost/benefit ratio of treating current risks in this value range.
- {{ config.extra.organization }} may also accept values above 5 whenever such risks are fairly justified and accepted,
- Based on valid business reasons or a highly unfavorable cost/benefit ratio.
- Independently of the acceptance criteria, all evaluated risks shall be reviewed, and their
- Acceptance approved, by the ISMS Steering Committee.

### Risk Formula

**HARM**

**x PROBABILITY**

**= RISK VALUE**

<table class="" style="border: 1px solid black">
<tr><th style="background-color: orange; color: white;">Category</th><th style="background-color: orange; color: white;">Range</th></tr>
<tr><td style="background-color: green; color: white; text-align: center; font-weight: bold">Low Risk</td><td>&lt;=5</td></tr>
<tr><td style="background-color: yellow; color: black; text-align: center; font-weight: bold">Medium Risk</td><td>&gt;5 &lt;=12 </td></tr>
<tr><td style="background-color: orange; color: white; text-align: center; font-weight: bold">High Risk</td><td>&gt;12 &lt; 20</td></tr>
<tr><td style="background-color: red; color: white; text-align: center; font-weight: bold">Critical Risk</td><td>=&gt; 20 </td></tr>
</table>

### Risk Calculation Matrix

<table class="table-6">
<tbody>
<tr><th>Risk</th><th colspan="5">Probability</th><tr>
<tr><th>Harm</th><th>1</th><th>2</th><th>3</th><th>4</th><th>5</th></tr>
<tr><th>1</th><td style="background-color: green; color: white;">1</td><td style="background-color: green; color: white;">2</td><td style="background-color: green; color: white;">3</td><td style="background-color: green; color: white;">4</td><td style="background-color: green; color: white;">5</td></tr>
<tr><th>2</th><td style="background-color: green; color: white;">2</td><td style="background-color: green; color: white;">4</td><td style="background-color: yellow; color: black;">6</td><td style="background-color: yellow; color: black;">8</td><td style="background-color: yellow; color: black;">10</td></tr>
<tr><th>3</th><td style="background-color: green; color: white;">3</td><td style="background-color: yellow; color: black;">6</td><td style="background-color: yellow; color: black;">9</td><td style="background-color: orange; color: white;">12</td><td style="background-color: orange; color: white;">15</td></tr>
<tr><th>4</th><td style="background-color: green; color: white;">4</td><td style="background-color: yellow; color: black;">8</td><td style="background-color: orange; color: white;">12</td><td style="background-color: orange; color: white;">16</td><td style="background-color: red; color: white;">20</td></tr>
<tr><th>5</th><td style="background-color: green; color: white;">5</td><td style="background-color: yellow; color: black;">10</td><td style="background-color: orange; color: white;">15</td><td style="background-color: red; color: white;">20</td><td style="background-color: red; color: white;">25</td></tr>
</tbody>
</table>

### Control Effectiveness and Maturity Rating

| Effectiveness               | Score | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| --------------------------- | ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Fully Matured or Automated  | 5     | Fully Matured: An enterprise wide risk and control framework based on ISO/IEC 27001 provides continuous and effective risk and control resolution. Internal control and risk management are integrated with enterprise practices, supported by automate real-time monitoring and full accountability for control monitoring, risk management and compliance enforcement. Controls are regularly assessed during internal audits and self-assessments. Root cause analyses is documented and corrective and preventive actions initiated. Employees are proactively involved in control assessments and continuous improvements. |
| Implemented and managed     | 4     | Implemented & managed: Internal control and risk management systems are effective within the {{ config.extra.organization }}' Environment. A formal, documented evaluation of controls occurs frequently and some of these controls are automated and regularly reviewed. Management detects control issues and consistently follows-up to address identified control weaknesses. Employees are evaluated on an annual basis against security requirements defined within their job descriptions.                                                                                                                                                   |
| Implemented but not managed | 3     | Implemented but not managed: Controls are in place and adequately documented. Operational effectiveness is evaluated on a periodic basis with an average number of issues resulting. Management is able to deal predictably with most control issues, however some control weaknesses continue to persist and the results of these impacts can be severe to regular operations. Employees are aware of their responsibilities for control.                                                                                                                                                                                      |
| Partly implemented          | 2     | Partially Implemented: Controls are in place but are not documented. Their intuitive operation is dependent on tribal knowledge and the motivation of employees to take extra steps during the regular execution of regular tasks. Effectiveness is not adequately evaluated and Management actions to resolve control issues are not prioritized or consistent. Employees may not be aware of their responsibilities.                                                                                                                                                                                                          |
| Non-existent                | 1     | Non- existent: Control(s) has not been implemented and there is a high risk of multiple incidents and faults.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |

<br/>

| **Maturity** | Score |                                                                                                                                                                       **Description**                                                                                                                                                                        |
| :----------: | :---: | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |
|  Optimized   |   5   |                         Processes have been refined to a level of best practice, based on the results of continuous improvement and maturity modelling with other enterprises. IT is used in an integrated way to automate the workflow, providing tools to improve quality and effectiveness, making the enterprise quick to adapt.                         |
|   Managed    |   4   |                                         It is possible to monitor and measure compliance with procedures and to take action where processes appear not to be working effectively. Processes are under constant improvement and provide good practice. Automation and tools are used in a limited or fragmented way.                                          |
|   Defined    |   3   |                         Procedures have been standardized and documented, and communicated through training. It is, however, left to the individual to follow these processes, and it is unlikely that deviations will be detected. The procedures themselves are not sophisticated but are the formalization of existing practices.                         |
|  Repeatable  |   2   | Processes have developed to the stage where similar procedures are followed by different people undertaking the same task. There is no formal training or communication of standard procedures, and responsibility is left to the individual. There is a high degree of reliance on the knowledge of individuals and, therefore, insufficiencies are likely. |
|   Initial    |   1   |                         There is evidence that the enterprise has recognized that the issues exist and need to be addressed. There are, however, no standardized processes; instead there are ad hoc approaches that tend to be applied on an individual or case-by-case basis. The overall approach to management is disorganized.                          |
| Non-existent |   0   |                                                                                                                 Complete lack of any recognizable processes. The enterprise has not even recognized that there is an issue to be addressed.                                                                                                                  |

### C-I-A Rating

<table class="table-center">
  <tr style="background-color: red">
    <td>H</td>
    <td>High</td>
    <td>3</td>
  </tr>
  <tr style="background-color: yellow">
    <td>M</td>
    <td>Medium</td>
    <td>2</td>
  </tr>
  <tr style="background-color: green">
    <td>L</td>
    <td>Low</td>
    <td>1</td>
  </tr>
  <tr>
    <td>N/A</td>
    <td>Not Applicable</td>
    <td>0</td>
  </tr>
</table>

<br/>
{{<drawRiskImpactTable data="people" >}}
<br/>
{{<drawRiskImpactTable data="information" >}}
<br/>
{{<drawRiskImpactTable data="software" >}}
<br/>
{{<drawRiskImpactTable data="hardware" >}}
<br/>
{{<drawRiskImpactTable data="telecommunication" >}}
<br/>
{{<drawRiskImpactTable data="facility" >}}
<br/>
{{<drawRiskImpactTable data="service" >}}

