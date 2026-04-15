---
title: Securing Your Repository
weight: 9
description: How to control access to your policy repository and published site
summary: Protect your policies with branch protection, approval gates, and access-controlled deployments. Covers GitHub Pages, Azure Static Web Apps, and Cloudflare Zero Trust.
---

PolicyPress stores your policies in Git — which means your security depends on who can read the repo and who can merge changes. This guide covers three areas: access control for the repository itself, a compliant policy-revision workflow, and controlling who can view the published website.

## Private vs. public repositories

| Setting | When to use |
|---|---|
| **Private** | Policies contain internal procedures, personnel details, or pre-publication drafts. Default for most organizations. |
| **Public** | Policies are intentionally published for transparency (e.g. a vendor's privacy policy). Use `redact_web = true` in `[extra.policypress]` to hide sensitive sections. |

A private repository keeps the Markdown source private but does **not** automatically restrict access to the published website — those are controlled separately (see [Deployment options](#deployment-options) below).

## Repository branch protection

Branch protection turns the `main` branch into an audit trail by requiring that every policy change passes through a documented review.

<div class="tab-group" data-default="Azure DevOps">
<div class="tab-pane" data-tab="GitHub">

### Recommended settings for `main`

In **Settings → Branches → Add rule** for the `main` branch:

- **Require a pull request before merging** — no direct pushes to `main`
- **Required approvals: 2** — one must be the CISO (enforced via CODEOWNERS, below)
- **Dismiss stale pull request approvals when new commits are pushed** — re-approval required if the policy text changes after review
- **Require status checks to pass** — select the PolicyPress CI check so the build must succeed before merging
- **Do not allow bypassing the above settings** — applies the rules to administrators too

### CODEOWNERS

Create a `.github/CODEOWNERS` file to ensure the CISO is always a required reviewer for policy files:

```text
# All policy files require CISO sign-off
content/policies/ @your-org/ciso

# Config and templates require a maintainer review
config.toml @your-org/policypress-maintainers
```

Replace `@your-org/ciso` with the GitHub team or username for your CISO. GitHub will block merges until that person approves.

</div>
<div class="tab-pane" data-tab="Azure DevOps">

### Branch policies for `main`

In **Project Settings → Repos → [your repo] → Policies**, add branch policies for `main`:

- **Minimum number of reviewers: 2** — disable "Allow requestors to approve their own changes"
- **Reset all approval votes when there are new changes** — re-approval required after new commits
- **Required reviewers** — add your CISO's account or AD group; this makes their approval mandatory on every PR
- **Build validation** — add your PolicyPress pipeline as a required check; PRs can't merge if the build fails

Unlike GitHub CODEOWNERS, ADO enforces required reviewers through the **Required Reviewers** policy rather than a file in the repository. The CODEOWNERS file still works for suggesting reviewers automatically, but enforcement comes from the policy settings.

To restrict who can push or create branches at all: **Project Settings → Repos → [repo] → Security** — set "Contribute" to Deny for anyone who should not push directly.

</div>
</div>

## Policy revision workflow

This workflow creates a complete, auditable record of every policy change — which is what makes a Git-based policy system defensible in ISO 27001 or SOC 2 audits.

### Creating a revision

1. **Branch from `main`** using a descriptive name:

   ```text
   policy/access-control-annual-review-2026
   policy/incident-response-add-ransomware-section
   ```

2. **Make your changes** to the policy Markdown. Update the `major_revisions` list in the policy front matter with the new version, date, and approval information.

3. **Open a pull request** with:
   - A clear title summarizing the change
   - A description explaining *why* the change was made — the business or compliance reason, not just "what" was changed
   - A link to any related issue, incident, or external requirement

4. **Request review** from the CISO and one other designated reviewer.

### Handling non-technical reviewers

Reviewers — especially the CISO — may not be comfortable using GitHub or Azure DevOps directly. That is expected and acceptable, as long as the record exists in Git. The recommended workflow:

- Share the diff link from the pull request over email or Slack for out-of-band review
- Hold a meeting to discuss the changes if needed
- The reviewer **must** then formally approve the PR in the platform (or ask a delegate to do so on their behalf)
- Any feedback, discussion, or decisions made outside the platform should be **summarized in a PR comment** before merging, so the audit trail is complete

The key principle: *out-of-band communication is fine, but the decision and its rationale must land in the PR before the merge*.

### Commit and PR message guidance

Auditors read commit messages. Write them as if explaining the change to someone unfamiliar with the context:

```text
# Good
fix(access-control): require MFA for all admin accounts per CIS v8 control 6.5

Following the Q1 pen test finding that admin SSH access was password-only,
this revision adds mandatory MFA for all privileged accounts. Approved by
CISO in the 2026-04-10 security steering meeting.

# Not useful
updated policy
```

### Minimum viable approval gate

For small teams, the simplest compliant configuration is:

- **2 required approvers** on `main`
- **Approver 1**: CISO (required via branch policy)
- **Approver 2**: any other named reviewer who is *not* the policy author — this prevents self-approval

Even if the CISO and the second reviewer are the same two people every time, the dual-approval requirement is what satisfies the control.

## Deployment options

The published website needs its own access controls, separate from the repository. Choose the option that matches your infrastructure.

<div class="tab-group" data-default="Azure Static Web Apps">
<div class="tab-pane" data-tab="Azure Static Web Apps">

Best for: organizations using Microsoft 365 and Azure AD. This is the recommended deployment for PolicyPress in enterprise environments.

Azure Static Web Apps (SWA) natively integrates with Azure Active Directory. You register the app, configure an access policy, and only users in your Azure AD tenant (or specific groups) can reach the site.

**Steps:**

1. **Create the Static Web App** in the Azure Portal:
   - Resource type: **Static Web App**
   - Plan: **Standard** (required for custom auth)
   - Region: your preference
   - Deployment source: connect to your policy repository

2. **Add a `staticwebapp.config.json`** to your repository root (committed alongside `config.toml`):

   ```json
   {
     "auth": {
       "identityProviders": {
         "azureActiveDirectory": {
           "registration": {
             "openIdIssuer": "https://login.microsoftonline.com/<YOUR_TENANT_ID>/v2.0",
             "clientIdSettingName": "AAD_CLIENT_ID",
             "clientSecretSettingName": "AAD_CLIENT_SECRET"
           }
         }
       }
     },
     "routes": [
       {
         "route": "/*",
         "allowedRoles": ["authenticated"]
       }
     ],
     "responseOverrides": {
       "401": {
         "statusCode": 302,
         "redirect": "/.auth/login/aad"
       }
     }
   }
   ```

3. **Register an application in Azure AD:**
   - Azure Portal → Azure Active Directory → App Registrations → New Registration
   - Name: `PolicyPress` (or your org name)
   - Supported account types: **Accounts in this organizational directory only**
   - Redirect URI: `https://<your-swa-url>/.auth/login/aad/callback`
   - Under **Certificates & secrets**, create a client secret
   - Copy the **Application (client) ID** and **Tenant ID**

4. **Set application settings** in the SWA resource:
   - `AAD_CLIENT_ID` = Application (client) ID from above
   - `AAD_CLIENT_SECRET` = the client secret value

5. **Restrict to specific users or groups** (recommended):
   - App Registrations → your app → **Enterprise applications** → Users and groups
   - Add only the users or Azure AD groups that should have access

6. **Add the deploy step to your pipeline.** See [Deploying to Production](@/guides/deployments.md) for the GitHub Actions and Azure DevOps pipeline snippets.

Users who visit the site are redirected to Microsoft login. Only members of your Azure AD tenant (or the groups you specified) can authenticate.

</div>
<div class="tab-pane" data-tab="GitHub Pages">

Best for: small teams already on GitHub, minimal setup.

**Limitation:** GitHub Pages visibility controls only work on GitHub Enterprise Cloud (GHEC) or public repositories. For private repos on GitHub Free/Pro, the site is either public or requires GHEC to restrict to org members.

**Steps (GHEC):**

1. In **Settings → Pages**, set source to the `gh-pages` branch (or `/ (root)` of a dedicated branch as output by the build)
2. Under **Visibility**, select **Private** to restrict access to members of the organization
3. Members must be signed in to GitHub to view the site

No additional configuration is required on the PolicyPress side.

</div>
<div class="tab-pane" data-tab="Cloudflare Pages">

Best for: teams already using Cloudflare, or who want granular per-user/group access policies without Azure.

Deploy the built site to Cloudflare Pages, then wrap it with a Cloudflare Zero Trust Access application that enforces identity before serving any content.

**Steps:**

1. **Deploy to Cloudflare Pages:**
   - Cloudflare dashboard → Pages → Create a project
   - Connect your repository
   - Build command: leave blank (PolicyPress pre-builds to `public/`)
   - Build output directory: `public`

2. **Create a Zero Trust Access application:**
   - Cloudflare Zero Trust dashboard → Access → Applications → Add an application
   - Type: **Self-hosted**
   - Application domain: your Cloudflare Pages URL or custom domain
   - Session duration: `8 hours` (recommended)

3. **Configure an identity provider:**
   Zero Trust supports Azure AD, GitHub, Google Workspace, Okta, and others. For Azure AD:
   - Zero Trust → Settings → Authentication → Add new provider → Azure AD
   - Follow the on-screen instructions to register the Cloudflare app in your Azure tenant

4. **Define an access policy:**
   - Add a **Policy** (e.g. `Employees only`)
   - Rule action: **Allow**
   - Include: **Emails ending in** `@yourdomain.com` — or use **Azure Groups** for granular control
   - Add a **Catch-all** deny rule for everyone else

5. **Set a custom domain** (optional):
   - Cloudflare Pages → your project → Custom domains → Add a custom domain
   - Cloudflare automatically provisions TLS

Users are redirected to your identity provider before they can view any page.

</div>
</div>

## Audit log and access reviews

- **Repository access:** Review collaborators and team membership quarterly. Remove access for staff who have left or changed roles.
- **Pipeline secrets:** Rotate deployment tokens annually or immediately after team changes.
- **Merge history:** The `git log` on `main` is your policy change audit trail. Export it periodically or reference it during audits with `git log --all --oneline --no-merges content/policies/`.
- **Azure AD / Cloudflare:** Review user and group assignments in your identity provider when running access reviews. Remove individuals who no longer need access.
