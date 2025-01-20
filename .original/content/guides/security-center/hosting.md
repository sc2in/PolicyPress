---
title: "Static Web App"
description: "Hosting for the Security Center in Azure Static Web Apps"
summary: "Hosting for the Security Center in Azure Static Web Apps"
date: 2023-09-07T16:04:48+02:00
lastmod: 2023-09-07T16:04:48+02:00
draft: false
menu:
  guides:
    parent: ""
weight: 810
toc: true
---

### Static Web App

The static web app is loaded in the `SC2 Corporate / Security_Resources` resource group.

### Configuration

Two items are required for application settings. These come from a service principal needed for auth gating.

| Name| Purpose|
| ------------------- | -------------------------------------- |
| AZURE_CLIENT_ID     | Client ID for AD service principal     |
| AZURE_CLIENT_SECRET | Client secret for AD service principal |

If the auth stops working, its likely the token has expired. As of this writing **it will next expire 2025-03-28**

### Renewing the Token

To renew the token:

- Go to the service princple in the [azure portal](https://portal.azure.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Credentials/appId/c4418cb3-a4e0-47f8-8a5f-c16ff5092550/isMSAApp~/false)
- Click on the `Certificates & secrets` tab
- Click `New client secret`
- Copy the *value* of the secret (not the ID)
- Open the static web app in the [resouce group](https://portal.azure.com/#@SC2365.onmicrosoft.com/resource/subscriptions/c8f2782e-f376-43e2-8cad-e688dadd45d0/resourceGroups/Security_Resources/providers/Microsoft.Web/staticSites/security-center/environmentVariables)
- Click on the `Environment variables` tab
- Paste the value into the `AZURE_CLIENT_SECRET` field for the production environment
- Click `Apply`

### Auth

Auth configuration is contained in the repo itself. this file is in `static/staticwebapp.config.jcon`. `openIdIssuer` is the endpoint for the service principal

```kroki {type=mermaid}
---
title: Auth Flow
---
sequenceDiagram
title auth
participant U as User
participant SWA as Static Web App
participant SP as AD Service Principal
U ->> SWA: Access
SWA -->> SP: User logged in?
SP -->> U: Login via auth portal
U ->> SP: Login with pways creds
SP -->> SWA: Redirect
SWA ->> U: Page load
```
