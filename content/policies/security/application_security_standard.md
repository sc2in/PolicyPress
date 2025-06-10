---
title: Application Security Standard
description: The SC2 Application Security Standard
summary: This document outlines our commitment to implementing and maintaining extensive security practices throughout our software development lifecycle.
date: 2025-04-16
weight: 2
taxonomies:
  SCF:
    - "MON-01"
    - "PRM-07"
    - "SEA-01"
    - "TDA-01"
    - "TDA-01.1"
    - "TDA-01.2"
    - "TDA-01.3"
    - "TDA-01.4"
    - "TDA-02"
    - "TDA-02.3"
    - "TDA-02.4"
    - "TDA-03"
    - "TDA-04.2"
    - "TDA-05"
    - "TDA-06"
    - "TDA-06.4"
    - "TDA-06.5"
    - "TDA-09"
    - "TDA-09.1"
    - "TDA-09.2"
    - "TDA-09.3"
    - "TDA-09.4"
    - "TDA-09.5"
    - "TDA-18"
    - "TPM-01"
    - "TPM-01.1"
    - "TPM-02"
    - "TPM-03"
    - "TPM-04"
    - "VPM-01"
    - "VPM-02"
    - "VPM-03"
    - "VPM-04"
    - "VPM-05"
    - "VPM-06"
    - "VPM-06.2"
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

In today’s digital landscape, safeguarding application security is not just a technical necessity, but a fundamental aspect of organizational integrity. This application security standard, tailored for {{ config.extra.organization }}, outlines our commitment to implementing and maintaining extensive security practices throughout our software development lifecycle. It serves as a comprehensive guide, establishing clear policies, procedures and best practices to mitigate
risks and protect sensitive information in our software applications.

This standard is designed to evolve with emerging security threats and technological advancements, ensuring {{ config.extra.organization }} remains at the forefront of application security.

## Secure Software Development Lifecycle (SSDL)
  
The SSDL is a framework that integrates security best practices and methodologies into the software development process from inception to deployment and beyond. SSDL is often referred to as a subset of SDLC. This lifecycle is not static; it evolves with emerging technologies and changing project requirements, emphasizing the need for continuous improvement.

### Continuous Improvement

Regular reviews of the SSDL are essential to ensure it remains effective and relevant. This includes reassessing security practices, tools and methodologies in response to new security threats and technological advancements. Organizations should cultivate a culture of learning and adaptation, where feedback from security incidents, code reviews and testing is used to refine and enhance the SSDL.

### Methodology-Agnostic Approach

The SSDL framework is designed to be flexible and adaptable to various development methodologies, including waterfall, Agile, DevOps and others.

High-level guidance is provided to ensure the security integration is seamless across different methodologies.

### Phases and Security Checks

- **Initial phase**: Security requirements should be defined and integrated into the project objectives. This includes threat modeling, risk assessment and defining security benchmarks.
- **Development phase**: Emphasis is on “shifting left,” which means integrating security as early as possible in the development cycle and incorporating tools like SAST, code quality checks and peer reviews in the early stages.
- **Testing phase**: Using DAST, penetration testing and security-focused quality assurance processes to identify vulnerabilities before deployment.
- **Deployment and maintenance phase**: Includes continuous monitoring of the application in production, using tools for vulnerability scanning and incident response. Regular updates and patches should be part of the maintenance cycle.

### Shifting Left

The concept of shifting left in the SSDL involves integrating security considerations early in the development process. This proactive approach reduces the likelihood of security vulnerabilities in the later stages of development. It encourages a more thorough and integrated approach to security, rather than treating it as an afterthought.

The SSDL is a dynamic, continuous process that adapts to the changing landscape of technology and security threats. By adopting a methodology-agnostic approach and focusing on continuous improvement, organizations can ensure their SSDL remains effective and efficient, thereby strengthening their overall security posture.

## Software Composition Analysis (SCA)

SCA is a process focused on identifying and managing vulnerabilities in third-party libraries and components used in software development. In addition to analyzing known security vulnerabilities in these components, considering the security posture of the vendors themselves can provide a more-comprehensive risk assessment.

### Vendor Risk Assessments

- Consideration of vendor security practices: Assess the security measures and history of the vendors. This is particularly crucial for major components in which the vendor’s security practices can significantly impact your application’s security.
- Integration with supply chain management: Aligning SCA with broader supply chain management practices allows for a holistic approach to third-party risk. This is not necessary for all organizations, but it can be invaluable for those with complex software supply chains.

### Regular Updates and Patching

- Maintain a routine process for reviewing and updating dependencies, including those provided by third-party vendors.
- Automate alerts for new vulnerabilities or patches in these components.

### Maintaining an Inventory

- Keep an updated inventory of all third-party components, including details about the vendors and their security practices.
- Use automated tools for real-time tracking of these components and their security statuses.

### Developer Education and Responsibility

- Educate developers about the importance of secure component usage and the potential risks associated with third-party vendors.
- Encourage responsible use of third-party components, including considerations of the vendor’s security posture.

Incorporating vendor risk assessments into SCA can provide a more-comprehensive approach to managing third-
party risks. While not mandatory for all organizations, it can significantly enhance the security of applications,
especially for those heavily reliant on third-party components.

## SAST (Static Application Security Testing)

SAST is a pivotal process for early detection of security vulnerabilities in application source code. This method
involves analyzing code for security flaws without executing it, providing a proactive approach to security.

### Best Practices for Implementing SAST

To maximize the effectiveness of SAST:

- Regularly update SAST tools to address emerging security vulnerabilities.
- Educate the development team on interpreting SAST reports and remediating flagged issues.
- Customize the SAST tool configurations to suit the specific coding languages and frameworks used in development projects. This should include identifying standard libraries adopted or built by the development team to address items such as validation of inputs and sanitization of potentially tainted values.

### Balancing Automation With Manual Review

While SAST tools automate vulnerability detection, they are not infallible. Supplementing automated scans with periodic manual code reviews is crucial for identifying complex security issues that may be overlooked by automated processes.

### Tracking and Prioritizing Findings

Effective management of SAST findings involves:

- Integrating SAST tools with the organization’s issue-tracking systems.
- Prioritizing the resolution of detected vulnerabilities, especially those classified as critical.
- Continuously monitoring the resolution process to ensure timely remediation of security issues.

SAST is an essential component in developing secure applications. Its early integration into the development process helps in identifying and mitigating security risks promptly. As threat landscapes evolve, so, too, should the organization’s approach to SAST, ensuring it remains an effective tool for identifying potential application security vulnerabilities.

## DAST (Dynamic Application Security Testing)

DAST is a security testing methodology that focuses on identifying vulnerabilities in a running application. Unlike SAST, which examines the source code, DAST evaluates the application in its running state, simulating an external attacker’s perspective. This approach is crucial for identifying security flaws that manifest during the application’s operation.

### Conducting DAST

DAST should be conducted at stages where the application is in a state close to its production environment, typically after the deployment of a new version in a staging or preproduction environment. The process involves using tools to actively test the running application for vulnerabilities an attacker could exploit, such as SQL injection, cross-site scripting and insecure server configurations.

### Integration in Development

DAST should be an integral part of the continuous integration/continuous deployment pipeline. This allows for regular and automated testing of applications as they are developed and updated. It’s crucial to ensure DAST tools are tuned and configured specifically for the application being tested to improveaccuracy and reduce false positives.

### Tracking and Remediating Findings

Findings from DAST should be systematically tracked, categorized by severity and assigned for remediation. The process for addressing these findings should be clearly defined, with timelines for resolution based on the severity and potential impact of the vulnerabilities.

### Complementing SAST and Other Methodologies

DAST complements SAST by identifying vulnerabilities that are only apparent when the application is running and interacting with other systems. It should be used in conjunction with other testing methodologies like SAST, manual code review and penetration testing to provide a comprehensive view of the application’s security posture.

### Tuning for Improved Accuracy

Regular tuning of DAST tools is essential for maintaining their effectiveness. This involves updating the tools with new threat intelligence and adjusting configurations to align with changes in the application and its environment.

DAST is a critical component of application security, providing insights into real-world attack scenarios and vulnerabilities. By integrating DAST into the development lifecycle, tracking and remediating findings effectively, and complementing it with other security testing methodologies, organizations can significantly enhance their
application security.

## Code Quality

Code quality is a critical aspect of application security, impacting the software’s comprehensiveness, reliability and overall security posture. High-quality code not only reduces the likelihood of vulnerabilities, but also makes the codebase more maintainable and secure.

### Integration With Existing Tools

Many development teams already use code quality tools like ESLint in their workflows. It’s often more effective to integrate security rules into these existing tools, rather than introduce new ones. Tuning and customizing these tools to include security rules can enhance their effectiveness in identifying potential security issues.

### Standards and Practices

- Adopt and enforce coding standards that emphasize best practices in readability, maintainability and security.
- Use automated tools, such as linters and formatters, to enforce these standards consistently across the development team.

### Impact on Security Posture

Quality code is less prone to common security issues like SQL injection, buffer overflows or cross-site scripting. Encourage developers to write secure code from the outset, reducing reliance on identifying and fixing vulnerabilities during later stages.

### Continuous Improvement and Training

- Implement continuous code review and refactoring processes to enhance code quality over time.
- Regularly train developers in secure coding practices, emphasizing the importance of integrating security into code quality.

### Tuning for Accuracy

- Regularly update and refine tool configurations to align with evolving coding practices and technologies.
- Ensure tools are tuned to the specific needs and context of the application, improving accuracy and relevance.

High code quality standards are vital for ensuring the security and integrity of software applications. By using existing tools, focusing on best practices and fostering a culture of continuous improvement and education, organizations can significantly enhance their security posture.

## APIs (Application Programming Interfaces)

APIs are integral to modern application architectures, facilitating communication among various software systems. Securing APIs is crucial to prevent data breaches, unauthorized access and service disruptions.

### Security Considerations

- Implement extensive authentication, authorization and data validation measures in API design.
- Conduct regular security assessments, including both automated scanning and manual testing.

### Best Practices for Secure API Development

- Use secure coding practices and frameworks with built-in security features.
- Implement rate limiting and throttling to prevent API abuse and DoS attacks.
- Secure data transmission using HTTPS and other security protocols.

### Treating API Calls Like Functions

- Write unit tests for API calls, treating them similarly to function calls. These tests can automatically verifythe API’s behavior with malformed input or invalid auth tokens.
- Regularly run unit tests as part of the development and continuous integration processes to ensureongoing API integrity and security.

### Utilizing Infrastructure and Middleware

- Use API gateways or middleware packages to centralize and standardize request and response processing. This helps in managing security aspects like JSON Web Token integrity checking and security header writing.
- By using existing infrastructure, you can achieve a more consistent and maintainable security posture across all APIs.

### Integrating APIs Into the Development Process

- Include API security in the design phase and throughout the development lifecycle.
- Use API management tools for monitoring, managing and securing API traffic.

### Developer Training and Awareness

- Offer specific training on API security, covering secure coding practices, common vulnerabilities and best practices.
- Promote a security-first approach in API development and maintenance.

API security is a critical aspect of application security, requiring dedicated attention and specialized practices. Adopting a comprehensive approach to API security, including best practices, unit testing and infrastructure leverage, significantly enhances the security posture.

## Infrastructure as Code (IaC)

IaC is the practice of managing and provisioning infrastructure through machine-readable definition files, significantly streamlining and securing the deployment process. It plays a pivotal role in ensuring consistent, repeatable and secure infrastructure deployment, particularly in cloud environments and DevOps workflows.

### Building Standard IaC Libraries

Develop standard IaC libraries or modules, such as AWS Cloud Development Kit (CDK) constructs, to define baseline configurations for deploying specific types of services or infrastructure components. This approach promotes reusability and consistency.
These standardized libraries help enforce security baselines and best practices across the infrastructure, reducing the likelihood of misconfigurations and vulnerabilities.

### Security Best Practices

- Maintain IaC scripts in a version-controlled repository to track changes and preserve an audit trail.
- Implement automated testing of IaC scripts to ensure they conform to security policies before deployment.
- Apply the principle of least privilege to IaC script execution, minimizing the risk of unauthorized changes.

### Standardizing Security Configurations

- Use IaC to implement uniform security configurations across the infrastructure, ensuring consistent security postures and simplifying compliance.
- Define security baselines as code to be uniformly applied across all environments.

### Integrating Security Into the Lifecycle

- Embed security considerations into the lifecycle of IaC scripts, from planning and development to testing and deployment.
- Foster collaboration between development, operations and security teams to promote a culture of security awareness and shared responsibility.

### Monitoring and Continuous Improvement

- Continuously monitor infrastructure for security anomalies and deviations from defined IaC scripts, using automated tools for detection and alerting.
- Regularly update IaC scripts to address new security threats and changing business needs.

IaC offers an efficient and effective method for managing infrastructure, with substantial benefits for security and operational resilience. By adopting best practices, standardizing configurations through IaC libraries and maintaining a focus on continuous improvement, organizations can significantly enhance their infrastructure security posture.

## Dependency Monitoring and Management

Dependency monitoring and management involves tracking and managing the external libraries, packages and components an application relies on.
It’s crucial for identifying vulnerabilities in dependencies that could compromise application security.

### Continuous Monitoring

- Implement tools like GitHub Enterprise, Snyk or other dependency monitoring solutions for real-time tracking and alerting of vulnerabilities in dependencies.
- Ensure continuous monitoring and scanning of dependencies to quickly identify and address new security vulnerabilities as they are discovered.

### Regular Updating and Patching of Dependencies

- Establish a process for regularly updating and patching dependencies to their latest secure versions.
- Automate the detection of outdated or vulnerable dependencies as part of the development pipeline.

### Building Standard Libraries and Baselines

- Develop standard libraries or modules, such as AWS CDK constructs, to define baseline configurations for deploying services or infrastructure components.
- Use these standard libraries to enforce security baselines and best practices across different projects and teams.

### Developer Training and Responsibility

- Educate developers about the importance of managing dependencies securely and the risks associated with outdated or vulnerable dependencies.
- Encourage a proactive approach to dependency management, including regular reviews and updates.

### Integration With Development Processes

- Integrate dependency monitoring and management into the SDLC to ensure it is a continuous and integral part of the development process.
- Use automated tools and pipelines to manage dependencies effectively and securely.

Effective dependency monitoring and management is essential for maintaining the security integrity of applications. By incorporating continuous monitoring, regular updating and library standardization, organizations can
significantly mitigate risks associated with third-party dependencies.