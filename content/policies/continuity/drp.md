---
title: "Disaster Recovery Plan"
description: "Procedures for responding to and recovering from a disaster"
date: 2022-04-07
draft: false
weight: 10
taxonomies:
  TSC2017:
    - A1.2
    - CC9.1
  SCF:
    - BCD-01.6
    - BCD-02
    - BCD-02.1
    - BCD-09.2
    - BCD-09.3
    - BCD-09.4

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


## Overview

### Statement of Purpose

This document details the activities which must be completed in the event of a Disaster
Recovery situation.

### Plan Maintenance and Testing

1. This document will be reviewed and updated on an annual basis or as needed depending on any changes to infrastructure or organization policy.
1. The critical elements of this disaster recovery plan should be tested on an annual basis.
1. All vendors' recovery plans are carefully reviewed and meet {{ config.extra.organization }} recovery standards.

### Disaster Definition

For the purposes of this document, a disaster is defined as **any situation that impacts daily
operations by limiting or prohibiting access to any of the included systems.**

- This can include, but is not limited to, APTs (Advanced Persistent Threats), malware, cyber attacks, data destruction/corruption, fire, power outage, and flood.

### Disaster Declaration Criteria

For the processes and procedures in this document to be initiated, a disaster must be declared by one or a combination of the following {{ config.extra.organization }} staff:

- CEO, Marc Huffman
- CFO, Tim Taylor
- CMO, Rob Kunzler
- CRO, Kevin Donovan
- CPO, Tim Adair
- CPO, Denise DeThomas
- CTO, Robin Fleming
- Director, Security & IT, Warren McComb
- Director, Customer Experience, Chris Carpluk

## Recovery Strategy

In the event of a disaster, client data would be in no way affected. All client data is maintained offsite and managed by Microsoft Azure. All other client portal data is maintained by the client and would not be affected by a disaster at {{ config.extra.organization }} corporate offices.

In most circumstances, recovery of networking connectivity and/or phone systems will be carried out in parallel to other recovery efforts.

### Application and System Recovery

If any corporate server needs to be recovered, {{ config.extra.organization }} utilizes offsite cloud storage.

### Network Recovery

1. If the corporate offices should lose connectivity to primary internet connection for an extended period, resulting in a severe impact to business, {{ config.extra.organization }} systems are accessible to staff from any location with an internet connection. Employees will resume normal business operations from an alternative location.
1. If network connectivity is impacted, the Operations Team will work with vendors to restore connectivity as quickly as possible.

### Telecommunications Recovery

1. Should there be a temporary phone system failure, {{ config.extra.organization }} will work with the vendor to re-establish the system. Technical Support maintains and emergency support phone that will be available if the main phone system fails.
1. In the event of an extended phone system failure, {{ config.extra.organization }} staff will use personal and company provided cell phones to respond to calls.

### Support Center Recovery

1. Our help center, which is managed through Zendesk, is in the cloud. Staff can access Zendesk anywhere there is an internet connection. Any disaster to {{ config.extra.organization }} physical location would not affect our access to the help center.
1. Our customer records are in Salesforce, whose data is managed in the cloud. Staff can access Salesforce anywhere there is an internet connection. Any disaster to {{ config.extra.organization }} physical location would not affect our access to this information.

### Code Base

{{ config.extra.organization }}'s code base is contained within Visual Studio Online and stored in the cloud.

### Physical Location Backup

1. Should there be a total site loss at any {{ config.extra.organization }} office, alternative office locations have been identified.
1. If corporate offices are temporarily inaccessible, {{ config.extra.organization }} staff are equipped to work from remote locations and all systems can be accessed offsite.

## Notification Procedures

The Disaster Recovery teams will initiate the disaster recovery process and management will ensure the execution of the policy and the necessary tasks. The teams will work to communicate the status of all recoveries to the rest of the company. When possible, announcements and mass emails will be sent to all staff members. Alternatively, it will be the responsibility of the managers to call or communicate with their direct reports should the situation warrant it.

## Client Notification

Once the disaster recovery process has been initiated and staff members notified, clients will be contacted, if necessary. Management will determine if clients need to be contacted and take the steps necessary to send out a mass email communication.

## Disaster Recovery Teams

**Leadership Team**



**Operations Team**


**Facilities Resource Team**


## Company Information
