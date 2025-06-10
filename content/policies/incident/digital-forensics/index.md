---
title: "Digital Forensics and e-Discovery Policy and Procedures"
description: "Procedures for investigating security breeches"
date: 2022-08-23
weight: 10
taxonomies:
   TSC2017:
      - CC3.3
      - CC7.2
      - CC7.3
      - CC7.5
      - C1.1
      - C1.2
      - CC6.7
   SCF:
      - IRO-09
      - MON-04
      - MON-05
      - MON-06
      - MON-08.1
      - MON-08.2
      - MON-08.3
      - MON-08.4
      - MON-09
      - LOG-02
      - LOG-04
      - LOG-09
      - DCH-25.1
extra:
  owner: SC2
  last_reviewed: 2025-04-16
  major_revisions:
    - date: 2022-08-01
      description: Initial version.
      revised_by: Ben Craton
      approved_by: Ben Craton
      version: "1.0"

---

## Purpose

If {{ org() }} faces an event that requires a time-sensitive search, review and extraction of large volumes of communications content, those involved need guidance regarding secure, timely, and immutable collection of relevant data. These events can be spurred by audits, regulatory investigations or litigation, which can often happen concurrently. Those involved include but are not limited to {{ org() }} management, law enforcement, and litigation specialists.

## Scope

The scope of this document covers legal requests for information needed to fulfill litigation.

## Important Note

e-Discovery and Forensics are complex legal processes to be pursued by qualified individuals. While Passageway seeks to provide guidance in this document, the majority of the processes, including any steps mentioned here, will be directed and dictated by legal professionals. This may include the determination of which professionals are to be used, based on mutual agreement by the parties involved.

## Evidential Process

The scope of the evidence collected will be guided by the following, including but not limited to legal representation, law enforcement, and subpoenas.

## 4-step process overview:

1. Acquire

2. Analyze

3. Evaluate

4. Present

![Shape2](digital-forensics-1.png)

## Extended Digital Forensics Process Overview

1. Identification
1. Preparation
1. Approach Strategy
1. Evidence preservation
1. Evidence Collection
1. Examination
1. Validation (of image)
1. Evidence of Analysis
1. Evaluation
1. Presentation
1. Returning Evidence

## Evidentiary Principles

In order to Acquire _(Identify, Collect, and Preserve)_ information that could serve as evidence, the following 4 principles must be followed by forensic examiners and {{ org() }} personnel:

1. Do not change any data _(e.g., forensic copy with hashed verification)_
1. Only access the original data in exceptional circumstances
   1. _Any data found outside of what is subpoenaed is not valid for further inquiry_
1. Keep an audit trail (who, what, where, when, why, how)
1. The person in charge (e.g., CISO) must ensure that the guidelines are followed

## Digital Forensics and e-Discovery Procedures

### Physical Hard Disk/SDD Digital Forensics

For legal cases (beyond any internal investigation for non-judicial proceedings), {{ org() }} opts to employ a private business due to that business having up-to-date industry standard forensics tools and Digital Evidence First Responder expertise, rather than using in-house expertise.

The following are characteristics that are necessary in selecting a forensics business who would make a proper copy of an HDD/SD:

1. Licensed

2. Experienced

3. Local

4. Immediately available

5. Agreed upon by the litigating parties (if applicable)

As of June 9, 2020, the following companies are possibilities. {{ org() }} reserves the right to update this list without noting it here, and even to choose a company not listed, in the event of an incident and/or upon recommendations or requirements by legal authorities.


### Virtual Digital Forensics (Azure)

With Azure, Network Forensics must be performed because {{ org() }} personnel do not have access to obtain a digital copy of the services or virtual machines for offline investigation.

## Appendix A – Definitions (Digital Forensics terms)

Acquisition – The beginning stage of a digital forensics investigation, when data is collected. The media is also copied bit-by-bit during this stage.

Ambient Data – Data located in areas not normally accessible to the user, usually stored in unallocated clusters, file slack, or virtual memory.

Bit-Stream Image – Used during the preservation process. A sector-by-sector/bit-by-bit copy of the original media, verifying each bit is a true and accurate copy.

Chain of Custody – The chronological and documented order and paper trail that records the sequence of custody, transfer, analysis, and disposition of physical and electronic evidence.

File Slack – The unused portion of the last cluster allocated to a file.

Hashing - The use of hash functions (e.g. CRC, SHA1, MD5) to verify that an image is identical to the source media.

Live Analysis - Analyzing of digital media from within itself. Used to acquire volatile data (e.g., from RAM).

Persistent data - data stored on a local hard drive and preserved when the computer is powered off.

Slack – Two types – RAM and File. The space within a storage block not utilized by a file.

Volatile data - data stored in memory and lost when computer is powered off.

Write Blocker – A hardware device or software app designed to prevent an OS from making any changes to the contents of a connected storage device. Typically used for imaging or triage.

## Appendix B – Manual Extraction of Volatile Data from Windows Machines

_Source: https://www.hackingarticles.in/forensic-investiagtion-extract-volatile-data-manually/_

_(at a Windows command prompt)_

```powershell
# Collect volatile data

systeminfo >> notes.txt

# Check currently available network connections
# (including state, PID, address, protocol)

netstat -nao >> notes.txt

# Router configuration

route print >> notes.txt

# Date and time of the system

echo %date% %time% >> notes.txt

dir

# Check System Variables

set >> notes.txt

# Get list of tasks/apps running

set >> notes.txt

# Showcase all the services taken by a particular task to operate its action.

tasklist /svc >> notes.txt

# Workstation details

net config workstation >> notes.txt

# ARP entries

arp -a >> notes.txt

# System User details

net user %username% >> notes.txt

# DNS details

ipconfig /displaydns >> notes.txt

# System network shares

net share >> notes.txt

# Network configuration

ipconfig /all >> notes.txt

```
