---
title: "Server Hardening Guidelines"
description: "Procedures for security hardening for servers and virtual machines"
date: 2021-09-27
weight: 10
taxonomies:
  TSC2017:
    - CC5.2
    - CC6.8
    - PI1.2
    - PI1.3
    - PI1.4
extra:
  owner: SC2
  last_reviewed: 2025-04-16
  major_revisions:
    - date: 2025-02-26
      description: Initial version.
      revised_by: Ben Craton
      approved_by: Ben Craton
      version: "1.0"
---



## Azure-Specific Configuration Standards  

### Identity & Access Management

- **Managed Identities**: Use system-assigned managed identities for Azure resources instead of service accounts
- **Conditional Access Policies**: Enforce MFA for all administrative access to Azure control plane
- **Privileged Identity Management (PIM)**:  
  - Just-in-Time (JIT) access for privileged roles
  - Maximum 4-hour activation window for critical operations

### Network Security

| Control | Azure Implementation |  
|---------|----------------------|  
| Segmentation | Azure NSGs with application-centric rulesets |  
| DDoS Protection | Cloudflare enabled on all public endpoints |  
| Encryption | TLS 1.2+ enforced via Cloudflare/Azure Front Door/WAF |  
| Private Connectivity | Sophos SSL VPN for platform team remote access |

### Compute Security

- **VM Hardening**:  
  - Azure Security Center recommendations baseline  
  - Disable password authentication (SSH/RDP keys only)
- **Container Security**:  
  - Azure Policy for AKS:  
    - Image scanning via Defender for Containers or equivalent
    - Pod identity using Azure AD Workload Identity  

## Compliance Integration  

### Policy Enforcement

- Azure Policy assignments for:  
  - Disk encryption enforcement  
  - NSG flow logs retention (1 year minimum)  
  - Defender for Cloud auto-provisioning  

### Monitoring Framework

- **Critical Logs**:  
  - Activity Logs → Log Analytics Workspace (5-year retention)  
  - NSG Flow Logs → Azure Storage (retention aligned with [AEIP]({{< ref "/docs/isms/aeip.md#data-retention-and-backups" >}}))

### Patch Management

| Component | SLA |  
|-----------|-----|  
| OS Security Updates | 72hr deployment window |  
| Middleware Updates | 14-day cycle via Azure Update Manager |  
| Emergency Patches | 24hr deployment via Azure Automation |  
