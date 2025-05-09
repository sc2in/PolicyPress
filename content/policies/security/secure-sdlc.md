---
title: "Secure Agile SDLC Policy and Procedures"
description: "Secure software development life-cycle for agile frameworks"
date: 2022-12-08
weight: 1
taxonomies:
  TSC2017:
    - A1.1
    - CC3.2
    - CC3.4
    - CC4.1
    - CC4.2
    - CC5.1
    - CC5.2
    - CC6.1
    - CC6.5
    - CC6.6
    - CC7.1
    - CC7.2
    - CC8.1
    - PI1.1
    - PI1.2
    - PI1.3
    - PI1.4
    - P4.1
    - P4.3
  SCF:
    - PRM-07
    - PRM-08
    - RSK-01
    - TDA-01.3
    - TDA-01.4
    - TDA-02
extra:
  owner: SC2
  last_reviewed: 2025-04-16
  major_revisions:
    - date: 2025-02-06
      description: Initial version.
      revised_by: Ben Craton
      approved_by: Ben Craton
      version: "1.0"
---

## Overview

In accordance with mandated organizational security requirements set forth and approved by management, {{ config.extra.organization }}, Inc. ("{{ config.extra.organization }}") has established a formal Secure Agile Software Development Life Cycle Policy and supporting procedures. This policy is to be implemented immediately along with all relevant and applicable procedures. Additionally, this policy is to be evaluated on a periodically for ensuring its adequacy and relevancy regarding {{ config.extra.organization }}' needs and goals. {{ config.extra.organization }} is a HIPAA, FERPA and GLBA-Compliant organization. On occasion, customers and prospects, as part of their due diligence, require information regarding our software development. {{ config.extra.organization }} is therefore transparent regarding our software development and security practices.

## Purpose

This policy and supporting procedures are designed to provide {{ config.extra.organization }} with a documented and formalized Secure Agile Software Development Life Cycle Policy that is to be adhered to and utilized throughout the organization at all times. Compliance with the stated policy and supporting procedures helps ensure the Confidentiality, Integrity and Availability (CIA) of Customer data and {{ config.extra.organization }} system resources.

## Scope

This policy and supporting procedures encompasses all system resources that are owned, operated, maintained, and controlled by {{ config.extra.organization }} and all other system resources, both internally and externally, that interact with these systems.

Internal system resources are those owned, operated, maintained, and controlled by {{ config.extra.organization }} and include all network devices (firewalls, routers, switches, load balancers, other network devices), servers (both physical and virtual servers, along with the operating systems and applications that reside on them) and any other system resources deemed in scope.

External system resources are those owned, operated, maintained, and controlled by any entity other than {{ config.extra.organization }}, but for which these very resources may impact the CIA and overall security of {{ config.extra.organization }}' services.

## Policy

{{ config.extra.organization }} is to ensure that the Secure Agile Software Development Life Cycle Policy adheres to the following conditions for purposes of complying with the mandated organizational security requirements set forth and approved by management:

### Security

{{ config.extra.organization }} engineering teams shall employ a continuous focus on security ensuring the Confidentiality, Integrity, and Availability (CIA) of {{ config.extra.organization }} customers' data and the services we provide to them which enable customer access to data. {{ config.extra.organization }} engineering teams shall adhere to the Open Web Application Security Project (OWASP) standard for Web development and maintain a constant diligence in avoiding the OWASP Top 10 most critical web application security risks.

**OWASP Top 10 (2021)**

- Broken Access Control
- Cryptographic Failures
- Injection
- Insecure Design
- Security Misconfiguration
- Vulnerable and Outdated Components
- Identification and Authentication Failures
- Software and Data Integrity Failures
- Security Logging and Monitoring Failures
- Server-Side Request Forgery

See the [OWASP Top 10](https://owasp.org/www-project-top-ten/) project site for more information on specific risks and up to date information.

### Privacy

{{ config.extra.organization }} commits to the protection of the confidential and private information entrusted to us by our customers. During the development of new products and features, the protection of such information is considered at each step of the SDLC. Personal identifiable information (PII) will never be used for the purposes of testing and will not be copied to any non-production application environment for developmental purposes without express written consent from the customer. Any feature or enhancement which may process PII will be developed with privacy and security of customer confidential information in mind as set forth in the [Privacy Policy](@/policies/privacy/policy.md) and other processes and procedures.

Access to production data, including confidential information and PII, is restricted via {{ config.extra.organization }}' [Access Control Policy](@/policies/security/access-control.md). Data will be stored in a secure manner, and all data will be encrypted at rest and in transit. To the extent possible, data will be stored within a data center located in or near a customer's geographic and jurisdictional region. {{ config.extra.organization }} will comply with all applicable laws and regulations regarding the collection, use, and storage of personal information. See the [Data and Business Intelligence Policy](@/policies/data/data-and-bi.md) for more information.

### Automated Systems and Artificial Intelligence

{{ config.extra.organization }} is committed to the responsible use of automated systems and artificial intelligence (AI) in our products and services. No confidential or sensitive information will be used to train AI models, internal or external, without express written consent from the customer. {{ config.extra.organization }} will not use AI to make decisions that affect individuals without human oversight and accountability. We will ensure that any AI systems used in our products and services are transparent, explainable, and auditable and will comply with all applicable laws and regulations regarding the use of AI and automated systems. See the [{{ config.extra.organization }} AI Acceptable Use Policy](@/policies/vendor/generative_ai.md) for more information.

### Deployment

{{ config.extra.organization }} engineering teams shall employ practices necessary to facilitate a continuous stream of new functionality, enhancements, and maintenance of our products. This will foster greater sales and a greater sense of assurance with customers that {{ config.extra.organization }} listens to their needs and makes every attempt to provide the highest software industry customer experience and meet the evolving needs of our current and future customers.

### Quality

{{ config.extra.organization }} engineering teams shall employ such practices as, but not limited to, Test-Driven Development/Behavior-Driven Development, Automated Functional/System and Behavior Testing, automated and manual code review to ensure that we practice the highest software quality standards and deliver the experience our customers expect.

### Vendor Management

{{ config.extra.organization }} engineering teams shall ensure that any third-party software, services, or components are vetted, licensed, and approved by the appropriate {{ config.extra.organization }} personnel prior to being utilized in any product or service. This includes, but is not limited to, open source software, libraries, and frameworks. Teams are expected to maintain a Software Bill of Materials (SBOM) for each of their projects that includes the license type of each external component. (See the {{ config.extra.organization }} [Vendor Management Policy](@/policies/vendor/vendor-3rd-party-management.md) for more information.)

### Communication

{{ config.extra.organization }} engineering teams shall ensure a common understanding and collaboration is built between the engineers, testers, stakeholders, and all other participants, while keeping management aware of significant issues, concerns, constraints, and risks.

## Secure Agile Software Development Life Cycle

The fast-paced and complex business needs of {{ config.extra.organization }} and our customers demand software solutions much quicker and more efficiently than traditional Software Development Life Cycle (SDLC) methodologies, such as waterfall and other similar methods. Because software requirements often cannot be given in the beginning of an SDLC, agile development methodologies need to be incorporated for allowing speed, collaboration, and flexibility in designing, developing, and deploying software.

Simply stated, agile methodologies allow for the development of software through an iterative approach, whereby the entire SDLC process is adhered to, but in incremental steps, by dividing the SDLC into modules and sequences (Sprints). At the end of each Sprint, the Development Team delivers incremental work on a given project/product, which ultimately allows for requirements gathering to be a continuous process, thereby ensuring the stakeholders determine the course of the software being developed. Thus, the following phases for SDLC are implemented throughout the agile development process, but not sequentially in terms of traditional SDLC, rather in Sprints and revisited and reassessed as needed throughout the product life cycle.

Traditional SDLC (Waterfall) Process:

- Strategic Planning
- Initiation
- System Concept Development
- Planning
- Requirements Analysis
- Design
- Development
- Integration and Testing
- Implementation
- Maintenance
- Disposition

{{ config.extra.organization }} Agile Scrum Process:

- Strategic Planning
- Inception Deck Creation (Initiation)
- Leadership Approval of Product/Project
- Feature consideration and evaluation
- Feature Design
- User Story and Backlog Creation (Requirements Analysis)
- Backlog Grooming (Feature Prioritization and requirements refinement)
- Sprint Iteration:
  - Sprint Planning (Final Prioritization, Story Sizing, Story Selection)
  - Daily Scrums
  - Development with Manual Code Review
  - Automated and Manual System Testing
  - Sprint Review
  - Sprint Retrospective
- Feature Launch/Application Deployment

The principal participants of a sprint are referred to as a Scrum Team. A scrum team requires the following roles:

- **Product Manager** – The Product Manager is a person with vision, authority, and availability and is responsible for continuously communicating the vision and priorities to the Development Team. Product Manager must be available to answer questions from the team.
- **Product Owner** – The Product Owner is a person who is responsible for turning the vision of the Product Manager into tangible work for the development team and for assisting the development team throughout the implementation of that vision during sprints.
- **Scrum Master** – The Scrum Master acts as a facilitator for the Product Manager and/or Product Owner and the team. The Scrum Master does not manage the team. The Scrum Master works to remove any impediments that are obstructing the team from achieving its sprint goals. This helps the team remain creative and productive while making sure its successes are visible to the Product Manager. The Scrum Master also works to advise the Product Manager about how to maximize ROI for the team.
- **Development Team** – The Development Team is responsible for self-organizing to complete work. A Scrum Development Team contains three to nine fully dedicated members. A typical team includes a mix of software engineers, architects, QA engineers & testers, and UI designers, although this may change based on product needs. Each Sprint, the team is responsible for determining how it will accomplish the work to be completed. The team has autonomy and responsibility to meet the goals of the Sprint.

The Scrum Team functions as a single unit through collaboration and experience sharing. Team members may possess more than one of the roles listed above.

### Benefits of the Secure Agile Software Development Life Cycle

There are a number of benefits for {{ config.extra.organization }} implementing agile software development, specifically, the following:

- Helps in ultimately speeding up all the relevant and in-scope SDLC phases, thus forgoing steps deemed unnecessary or redundant.
- Leads to more secure software as more frequent and more intensive manual and automated testing and code review is performed.
- Promotes a less formal and rigid culture, ultimately encouraging a collaborative team approach, which results in delivering stated goals on time.
- Genuinely advances and facilitates the concept of collaborative knowledge sharing and true distribution of leadership throughout the life of a given product.
- Keeps all stakeholders informed and engaged on a continuous basis, ultimately improving metrics related to requirements gathering and other important criteria.
- Allows for the introduction and incorporation of frequent and rapid changes into the SDLC methodology as needed.
- By identifying deviations early on, it allows for substantial cost and time savings for all involved in the overall process.
- Ultimately provides for a high-quality software product that's more meaningful and one that truly mirrors end-user demands because of the continued collaborative process throughout its development.

### Agile Manifesto Principles

In using the agile development process, {{ config.extra.organization }} strives all time for adhering to the following best practices as put forth by the Agile Manifesto:

1. Our highest priority is to satisfy the customer through early and continuous delivery of valuable software.
1. Welcome changing requirements, even late in development. Agile processes harness change for the customer's competitive advantage.
1. Deliver working software frequently, from a couple of weeks to a couple of months, with a preference to the shorter timescale.
1. Business people and developers must work together daily throughout the project.
1. Build projects around motivated individuals. Give them the environment and support they need, and trust them to get the job done.
1. The most efficient and effective method of conveying information to and within a development team is face-to-face conversation.
1. Working software is the primary measure of progress.
1. Agile processes promote sustainable development. The sponsors, developers, and users should be able to maintain a constant pace indefinitely.
1. Continuous attention to technical excellence and good design enhances agility.
1. Simplicity--the art of maximizing the amount of work not done--is essential.
1. The best architectures, requirements, and designs emerge from self-organizing teams.
1. At regular intervals, the team reflects on how to become more effective, then tunes and adjusts its behavior accordingly.
1. {{ config.extra.organization }} Secure Scrum Process

### Strategic Planning

A critical component of any Software Development Life Cycle (SDLC) initiative entails undertaking necessary strategic planning for the entire product life cycle. This includes identifying long-term operational and business goals of the envisioned product, challenges that lay ahead, along with opportunities for supporting the mission and vision of the organization as a whole. While systems development is often extremely technical, the business vision and strategic goals are what ultimately drive a product, thus requiring clear and concise directives at all times. In essence, the goals and related deliverables of strategic planning are to identify, discuss, collaborate, and engage in constructive dialogue pertaining to the actual aforementioned SDLC phases.

**Tasks:** Vice President of Product meets with leadership to discuss, coordinate and align company strategy with product strategy.

**Deliverables:** Production of Corporate and Product-related goals or "Rocks" are created and tracked, and if necessary, an Inception Deck meeting is called

### Inception Deck

The Inception Deck meeting consists of undertaking necessary measures for determining the actual business case for a given product and aligning the product team behind the purpose of the product. Constant improvement, refinement, and adding of product features and/or services is necessary for ensuring sustained business viability. Because of this, documentation known as the Inception Deck is to be compiled that effectively addresses the following subject matter. The following list comprises the Inception Deck deliverables:

- Executive summary
- Answers the question "Why should or does this product exist?"
- Business challenge, issue, or opportunity
- Elevator Pitch – Succinct story of the product benefits bringing clarity to the product team
- Product Box – Comprehensive list of benefits of the product
- The NOT List – List of features/benefits the product is NOT going to be
- List of Product Team members including development staff, Product Manager, Marketing team, contractors, designers, customer advisory board, etc.
- Architecture and flow diagrams
- Risk Assessment
- Product Milestones
- Prioritization of Time vs. Budget vs. Scope vs. Quality
- Finalization of Product Essentials – name the Development Team, set expectations, name the Product Owner, estimate the number of people, time to reach milestones, and costs

**Tasks:** Vice President of Product conducts Inception Deck meeting(s). Product team assesses business needs, costs, benefits, risks, gather all required information, submit to Leadership for approval.

**Deliverables:** Product Inception Deck

### Leadership Product/Project Approval

Following the creation of the Inception Deck, a final pass of the Inception Deck with Leadership is needed to gain product/project approval. As such, the Inception Deck is studied and analyzed in an in-depth manner regarding costs and benefits, feasibility, risk management, along with system boundaries. Additionally, compensating or alternative systems and/or solutions are to be identified and relevant costs and benefits of such options. Moreover, all operational, business specific, and information security and privacy requirements are to be identified and documented accordingly.

**Tasks:** Leadership to meet with Vice President of Product to analyze Inception Deck, study and assess business needs, assess costs, benefits, risks, determine product/project go/no-go.

**Deliverables:** Go/No-Go Product/Project Approval

### Feature Consideration and Evaluation

Once a product has been selected for development, or within the product's lifetime a functional change to the product must be made, the packages of updates to facilitate that change, known as Features, will be created. Features are changes that either add functionality and experience to the product or modify it in a meaningful way. The product manager must define the feature in order for any further progress to begin. This definition should include what audience will benefit from the feature, what problem the feature sets out to solve, and the rationale for the solution (the Who, What, and Why).

All features must then be evaluated before they can be considered for development and inclusion in the product. The product manager is responsible for evaluating the following metrics for each feature under consideration:

- Customer Value
- Customer Usability
- Development Feasibility
- Business Viability

The product manager should employ the assistance of an engineer for the product as well as a designer for purposes of evaluating architecture capabilities, security implications, and other technical considerations. The products of this discovery may then be circulated for internal {{ config.extra.organization }} stakeholder or customers for feedback on the intended solution.

Once the product manager has determined the scope and evaluation of the feature to their satisfaction, the feature may move forward within the SDLC.

**Tasks:** Product manager evaluates a feature for product inclusion

**Deliverables:** A feature with scope definition and evaluation metrics

### Feature Design

Design of a feature is one of the most critical parts of the overall creation process as it will be the overall experience our customers will ultimately have with the product. During this phase, the product manager will, with scope and requirements in hand, work closely with the design team to define and evaluate workflows, interactive elements, and messaging that will become the interface for the feature within the product and solve the problem that the feature sets out to address. These designs and prototypes may be circulated within {{ config.extra.organization }} to key stakeholders and with target customers to elicit feedback to be used at the product manager's discretion.

Once the product manager has determined that the designs are sufficient for their vision of the feature, the feature may begin engineering development.

**Tasks:** Product manager and design team create designs to be implemented for the feature

**Deliverables:** Designs defining look and feel, workflows, and messaging for the feature.

### User Story and Backlog Creation

User Story and Backlog Creation is vitally important to the overall success of the product as the following major initiatives are to be addressed:

- Identification of technical requirements
- Prioritization of User Stories based on stakeholder/customer needs
- Engineering architecture discussion of features
- Engineering assessment of security issues

A User Story is a format for capturing what a user or system needs to do, and also describes the value that the user would get from a specific functionality. User and System Stories are often used in agile product management. Here, we use the term "user story" to denote the format in which the needs are written down, not the size of the work or feature that implementing it involves. Organizations that have comprehensive agile product management pipelines often use different names for different levels, or sizes, of stories: large stories may be known as epics and smaller stories as features, user stories, and tasks. A user story, as a format, is suitable for each of these levels. Many of these user stories would be what many companies would call features or requirements.

User Stories are typically written in one of the following two formats:

> Given [I am a type of user]
>
> When [the following conditions or actions occur]
>
> Then [the following purpose or outcome is shown]

Or:

> As a [type of user]
>
> I can [perform an action]
>
> So that [the following purpose or outcome is shown]

User Stories can be as granular or as large as is necessary to successfully complete the requirement and test it within a reasonable period of time, ideally within one sprint cycle.

The product Backlog in Scrum is a prioritized User Stories list, containing short descriptions of all functionality desired in the product. When applying Scrum, it's not necessary to start a project with a lengthy, upfront effort to document all requirements. Rather, only the stories which will bring the biggest business and customer value first are prioritized in the list and scheduled for work in the next Sprint.

**Tasks** : Product manager or product owner identifies technical requirements not yet in story form, prioritize Backlog.

**Deliverables:** Prioritized Backlog of User Stories ready to be assigned to specific sprint cycles.

### Sprint Cycle

A Sprint is a time-box of one month or less during which a "Done", useable, and potentially releasable product increment is created. Sprints have consistent durations throughout a development effort. A new Sprint starts immediately after the conclusion of the previous Sprint.

During the Sprint:

- No changes are made that would endanger the Sprint Goal
- Quality goals do not decrease
- Security goals do not decrease
- Scope may be clarified and re-negotiated between the Product Manager and Development Team as more is learned
- Each Sprint may be considered a project with no more than a one-month horizon. Like projects, Sprints are used to accomplish something. Each Sprint has a definition of what is to be built, a design and flexible plan that will guide building it, the work, and the resultant product.

At {{ config.extra.organization }}, Sprint cycles are two weeks in duration. When a Sprint's horizon is too long the definition of what is being built may change, complexity may rise, and risk may increase. Sprints enable predictability by ensuring inspection and adaptation of progress toward a Sprint Goal with each at most every two weeks. Sprints also limit risk to two weeks of cost.

At the end of each sprint, the Scrum Team should ideally have produced a Potentially Shippable Product Increment (PSPI). The PSPI should be the deliverable that every sprint outputs and ensures that the Scrum Team is able to deliver value to customers quickly.

The following are detailed descriptions of the various activities in a Sprint Cycle:

#### Sprint Planning

The sprint planning meeting is required for all sprints for the purpose of defining what work will be done during the sprint and how the work is to be carried out. It is attended by the Product Manager and/or Product Owner, Scrum Master and the Development Team. There are two defined artifacts that result from a sprint planning meeting:

- Sprint Goal
- Sprint Backlog

During the sprint planning meeting, the Product Manager or Product Owner describes the highest priority features to the team and proposes what they believe should be the overall goal for the sprint. A sprint goal is a short, one- or two-sentence, description of what the team plans to achieve during the sprint. It is written collaboratively by the team and the product owner. The Scrum Team then debates if the goal is both feasible and appropriate given the overall product vision, team capacity, and current architecture. If the goal is acceptable, the team adopts the goal and commits to delivering on that goal by the end of the sprint as a team. If it is not, the team works with the Product Manager or Product Owner to amend the goal to fit within the aforementioned parameters. The sprint goal can be used for quick reporting to those outside the sprint. Some stakeholders will want to know what the team is working on, but do not need to hear about each sprint backlog item (user story) in detail.

The success of the sprint will later be assessed during the sprint review meeting against the sprint goal, rather than against each specific item selected from the product backlog.

Once the goal is decided, attention is turned to what items from an ordered product backlog can be done within the sprint. These items will constitute the sprint backlog. A sprint backlog is a list of the product backlog items the team commits to delivering plus the list of tasks necessary to delivering those product backlog items. Considerations for what work should be used to create a sprint backlog, include: the team's capacity, any new or outstanding impediments the team has, the PSPI, and any actions that came out of the previous sprint's retrospective. Each task on the sprint backlog is also checked to ensure that all tasks are defined, have an estimated cost associated with it, and acceptance criteria appropriate for testing and quality assurance has been created for it.

It is important to note that the Scrum Team itself selects how much work they can do in the coming sprint. The Product Manager or Product Owner does not unilaterally determine how much work is accomplished with each sprint.

**Participants** : Product Manager and/or Product Owner, Scrum Master, Development Team

**Inputs** : Ordered product backlog, draft of sprint goal, team capacity, list of impediments, the PSPI, previous retrospective actions

**Time** : Up to 4 hours

**Tasks** : Conduct Sprint Planning meeting, analyze Product Backlog, build Sprint Backlog.

**Deliverables:** Sprint Goal, Sprint Backlog with scored User Stories

#### Daily Standup

In Scrum, on each day of a sprint, the team holds a short daily meeting called the "daily standup." Meetings are typically held in the same location and at the same time each day. Ideally, a daily scrum meeting is held in the morning, as it helps set the context for the coming day's work. These standup meetings are strictly time-boxed to 15 minutes. This keeps the discussion brisk but relevant.

The purpose of the standup is to resync the Development Team and plan work for the day and to bring up and discuss any impediments the team has encountered. Use of metrics such as a burndown chart (a chart showing the relative progress the team has made day over day during the sprint) may be employed to inform the team of any potential issues with the progress of the sprint. The standup is not intended to be a status meeting.

As communication is a value highly regarded in Scrum, anyone within {{ config.extra.organization }} may attend a daily standup meeting as an observer, but only the listed participants may speak.

**Participants:** Development Team, Product Manager and/or Product Owner (Optional), Scrum Master (Optional)

**Inputs:** Sprint backlog, burndown chart, list of impediments.

**Time:** 15 minutes

**Tasks** : Create a plan for the day to implement the user stories within the sprint backlog

**Deliverables:** Plan for the upcoming day, a list of raised impediments

#### Development and Code Review

In development, the engineering team takes all the applicable design specifications along with technical user stories and turns them into actual working software. Additionally, during development a common understanding and collaboration is built between the engineers, stakeholders, and all other participants, while also keeping management aware of significant issues, concerns, constraints, risks, etc.

During development, engineers will follow the following methodology:

1. Review the sprint backlog and select the next story in priority order
1. Code the solution to the story following the requirements set forth in the description, the design specifications, and acceptance criteria while adhering to accepted coding standards and remaining risk aware.
1. Test the solution locally ensuring that all acceptance criteria are met. This may entail writing to updating automated testing methods to match the acceptance criteria.
1. Request a peer review of the coded solution from other team members and adjust the solution if problems are identified
1. Send the accepted reviewed code to QA for full integration testing before the solution is accepted into the product internally.
1. Should QA find an issue with the full integration test, the work is sent back to the engineer for further refinement. Upon acceptance, QA will mark the work complete.
1. Throughout development, collaboration and openness about the work that is being done is encouraged and expected from all engineers to mitigate both security risks with the products and defects introduced into the product. All work and changes to the code base for all products is tracked with an emphasis on auditability.

**Tasks** : Develop the envisioned feature set, through both manual and automated processes, rigorously validate code changes and new code with essential quality and security checks. Pass changes through CI pipeline and run manual and automated test battery as needed. Queue code ready for delivery through CD.

**Deliverables:** High-quality, highly secure code ready for Release.

#### Continuous Integration, Testing, Continuous Delivery

{{ config.extra.organization }} employs a Continuous Integration/Continuous Delivery practice for code changes with emphasis on automated testing.

##### Continuous Integration

Continuous Integration (CI) involves producing a clean build of the system several times per day, usually with a CI tool. Agile teams typically configure CI to include automated compilation, unit test execution, and source control integration. This is the model {{ config.extra.organization }} has implemented.

The purpose of the CI practice is summed up by two objectives:

Minimize the duration and effort required by each integration episode

Be able to deliver a product version suitable for release at any moment

In practice, this dual objective requires an integration procedure which is reproducible and largely automated. Reproducibility and automation are achieved through version control tools, team policies and conventions, and tools specifically designed to help achieve continuous integration.

{{ config.extra.organization }}' Automated Code Validation CI Policy and Practices are outlined below:

- Code Review – Executed when an engineer merges completed code with the shared development branch for a feature. This must be accepted by 2 or more other engineers before continuing
- CI Trigger – After code review, the pull-request is completed and the code is merged with the common branch. A build is initiated following code check-in.
- CI unit test validation – The first step in the CI build is to validate unit tests. The binaries are built, and all implemented unit tests are run. If failures are detected, the build fails and engineers are notified to handle the failed condition.
- CI service image build – The CI build then creates a container for the service to be deployed to any environment very quickly. This container is stored in a container registry to be utilized in the future.
- CI test deployment – The built container is deployed to an isolated test environment for integration testing.
- CI Automated penetration testing – A penetration discovery tool to test vulnerabilities of raw API endpoints for common exploits
- CI integration testing – A set of API tests are executed against the test environment to ensure that input and output formatting of all API requests are as expected to test end-to-end functionality in the service. If any tests fail, the build fails and developers are notified
- CI automated UI testing – A set of automated experience tests are run against any UI elements implemented in the service. If any tests fail, the build fails and developers are notified.
- CI handover to release pipeline – This is the process defined with users physically needing to verify and approve functionality in multiple environments before code can be pushed to a production server, and integrated into the available services. It is expected that most builds do not pass this point in the process triggering many WIP pull requests for engineering re-work and review. Only after software changes have met the highest quality standards will they pass this stage.
- Static Code Analysis – handled via Microsoft Managed Recommended Rules and FXCop

##### Testing

Unit tests:

Unit tests run very close to core components in the code. They are the first line of defense in ensuring quality. Unit tests should be easy to write, run fast, closely model the architecture of the code base. Other testing is necessary since unit tests only validate core components of software and don't reflect user workflows which often involve several components working together.

Since a unit test explains how the code should work, {{ config.extra.organization }} developers can review unit tests to get current on that area of the code.

API tests:

{{ config.extra.organization }} software is modular, which allows for clearer separation of work across several applications. APIs are the end points where different modules communicate with one another, and API tests validate them by making calls from one module to another. API tests are generally easy to write, run fast, and can easily model how applications will interact with one another.

Since APIs are the interfaces between parts of the application, they are especially useful when preparing for a release. Once a release candidate build passes all its API tests, the team can be much more confident releasing it to customers.

Functional tests:

Functional tests work over larger areas of the code base and model user workflows. {{ config.extra.organization }} employs a series of manual and automated system and functional tests per release. A standard battery of tests is run regularly per sprint cycle and full software regression is run prior to each release of new software deployed to customers. Functional tests are more likely to find bugs because they mimic user actions and test the interoperability of multiple components.

##### Continuous Delivery

Continuous Delivery (CD) is the practice of using automation to produce releasable software in short iterations, allowing {{ config.extra.organization }}' Development Teams to ship working software more frequently. Along with CI, automated testing, constant monitoring, and analytics feedback, CD gives {{ config.extra.organization }} an increasing the ability to react to change.

Since tests are run constantly, and {{ config.extra.organization }} tests are written and reviewed in such a way as to provide a measurable guarantee of quality and security, then it is possible for {{ config.extra.organization }} to release software at any point in time. CD therefore doesn't always mean delivering, but rather it represents a {{ config.extra.organization }} philosophy and commitment to ensuring that our code is always in a release-ready state.

**Tasks** : Create automated Unit, API and Functional tests. Run all automated tests as software is integrated, deliver integrated/tested software to production repository release candidacy.

**Deliverables:** Unit, API and Functional automated tests, manual Functional tests, fully tested code deployed to production repository.

#### Sprint Review

At {{ config.extra.organization }}, each Sprint is required to deliver a potentially shippable product increment (PSPI). This means that at the end of each Sprint, the team will have produced a coded, tested and usable piece of software. So, at the end of each Sprint, a Sprint Review meeting will be held. During this meeting, the Scrum team shows what they accomplished during the Sprint. Typically, this may take the form of a demo of the new features.

The purpose of the sprint review is to display the PSPI to all stakeholders in order for the stakeholders to inspect the PSPI and assist the Product Manager or Product Owner in adapting the product for future goals. It is also an opportunity for non-Scrum Team {{ config.extra.organization }} employees to become familiar with current and upcoming changes to the product to best prepare their own teams to adapt to these changes.

The Sprint Review meeting will be kept very informal and allowing no more than two hours of preparation time for the meeting. A Sprint Review meeting should not become a distraction or significant detour for the team; rather, it should be a natural result of the Sprint.

Participants in the Sprint Review will include the Product Manager and/or Product Owner, the Development Team, the Scrum Master, management, and any other stakeholders of the product.

At the Sprint Review, the outcome is assessed against the sprint goal determined during the Sprint Planning meeting. Ideally, the team has completed each product backlog item brought into the Sprint, however, a greater importance is placed on achieving the overall goal of the Sprint.

**Participants:** Scrum Team, all product stakeholders

**Inputs:** PSPI, Ordered Product Backlog, Sprint Metrics, Sprint Goal

**Time:** Up to 2 hours

**Tasks** : Conduct Sprint Review meeting, review sprint goals and sprint backlog, inspect and adapt the product

**Deliverables:** An updated product backlog

#### Sprint Retrospective

The Sprint Retrospective is a dedicated period at the end of each sprint to deliberately reflect on how the team is doing and to find ways to improve. The Sprint Retrospective is usually the last thing done in a sprint. The entire team, including both the Scrum Master and the Product Manager and/or should participate.

As the purpose of the sprint review is to inspect and adapt the product, the purpose of the sprint retrospective is to inspect and adapt the scrum team itself. The retrospective is to be a place of open and honest discussion among the team about challenges and triumphs the team experienced during the sprint. Utilizing a list of these items, the team decides on a goal for itself to improve upon in the upcoming sprint. This retrospective goal should be an action item that is focused and achievable within the team's capacity.

Due to the desire for an open and honest conversation during the retrospective, it is advisable that only scrum team members attend and that, as much as possible, members of management with direct reports on the scrum team do not attend. Discussion should focus on work and the interaction between functional roles to avoid interpersonal conflict from arising. It is the responsibility of the leader of the retrospective to facilitate a healthy and productive exchange.

As the scrum master is a part of the scrum team, it is also advisable that the facilitator role for the retrospective be changed among team members sprint-over-sprint.

**Participants:** Scrum Team

**Inputs:** Sprint metrics, list of impediments, previous retrospective goal, definition of done, sprint review feedback

**Time:** Up to 1.5 hours

**Tasks** : Inspect and adapt the team

**Deliverables:** Improvement action item in the form of a retrospective goal.

### Feature Launch and Application Patches

Feature Launch, which includes application patches, requires many touch-points with each department at {{ config.extra.organization }}. Particular emphasis is placed on Customer Success, Training and Marketing. Prior to Feature Launch, comprehensive manual and automated quality and security checks are performed, including full regression analysis and testing to ensure the confidentiality, integrity and availability (CIA) of the software and environment. Internal "customers" such as Customer Success Managers, Sales staff and Technical Support agents are also trained.

Once all internal teams are satisfied that their members are ready for feature or patch release, the release team made up of representatives of these teams will hold a "Go/No-Go" launch meeting. If a release team member, speaking on behalf of their team, issues a "no-go," the release team will take appropriate steps to address the cause of the denial of launch. IF all members issue a "Go," the Product Manager, or Product Owner, is then authorized to release the feature or patch to general availability (GA). Once the Feature Launch or "go live" is complete, marketing materials are finalized and sent out, customer training webinars are scheduled and feedback is taken. Feature Launch only is considered complete when all business, security, technical, and operational needs and requirements are ultimately met.

**Tasks** : "Go Live" with the feature set selected for release to the entire or segmented customer base, along with performing procedures that effectively address the aforementioned subject matter, "Go/No-Go" launch meeting

**Deliverables:** Release Retrospective meeting, internal and customer/prospect training webinars, updated marketing materials, etc.

## Maintenance

Maintenance of {{ config.extra.organization }}' software consists of undertaking necessary measures for ensuring all operational, performance, security – and other necessary needs and measures – are being met at all times. Meeting such goals ensures the confidentiality, integrity, and availability (CIA) of the system itself. This requires a structured change management | change control process, one that has well-established and formalized policies, procedures, and supporting practices in place. Please see the {{ config.extra.organization }} Change Control Policy for more information. Furthermore, code reviews and other necessary testing for security measures are to be undertaken on a regular basis. Once operational, performance, security, or architectural changes have been identified and approved by the Change Control Board, the {{ config.extra.organization }}' software Engineering Team follows the Scrum process outlined above in section V.3. {{ config.extra.organization }} Secure Agile Scrum Process to ensure a high level of security, along with meeting the Service Level Objectives outlined in the {{ config.extra.organization }} Service Level Agreement are maintained while allowing for high throughput and quick time-to-market.

## Responsibility for Policy Maintenance

The {{ config.extra.organization }} Vice President of Product Management in conjunction with the Chief Information Security Officer and Vice President of Engineering is responsible for ensuring that the aforementioned policy is kept current as needed for purposes of compliance with mandated organizational security requirements set forth and approved by management.
