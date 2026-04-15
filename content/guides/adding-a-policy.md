---
title: Creating a New Policy
weight: 1
description: How to scaffold and publish a policy in PolicyPress
summary: Use the CLI to scaffold a policy file, fill in the front matter, and open a PR for review.
---

Policies are Markdown files with YAML front matter. Here's how to create one.

## Scaffold the file

Run `policypress new` from your repository root (the directory with `config.toml`):

```bash
policypress new "Acceptable Use Policy"
```

This creates `content/policies/acceptable-use-policy.md` with the front matter and stub sections already in place. Open it and keep going from there.

To point at a different config file:

```bash
policypress new "Acceptable Use Policy" --config path/to/config.toml
```

## Front matter

Every policy file starts with a YAML block between `---` delimiters. Full example:

```yaml
---
title: "Acceptable Use Policy"
date: 2026-04-15
description: "Rules governing use of company IT systems, networks, and data"
draft: true

# SCF and TSC2017 are the two report-backed taxonomies.
# Any other taxonomy you declare in config.toml will still show up
# in the Framework Coverage section on the policy page.
taxonomies:
  SCF:
    - IAC-01
    - IAC-06
  TSC2017:
    - CC6.1
    - CC6.3

extra:
  owner: "Alice Bueler"
  last_reviewed: 2026-04-15
  major_revisions:
    - date: 2026-04-15
      description: "Initial draft."
      revised_by: "Alice Bueler"
      approved_by: ""
      version: "0.1"
---
```

### Field reference

| Field | Required | Notes |
|---|---|---|
| `title` | yes | Shown on the policy page, in PDFs, and in the compliance reports |
| `description` | yes | Short summary, shown in the policy index table |
| `date` | no | Used by Zola for ordering. Defaults to file creation date |
| `draft` | no | Set to `true` to skip PDF generation. The PDF link is hidden unless `show_draft_pdfs = true` |
| `extra.owner` | no | The individual responsible for the policy. Shown in the revision table |
| `extra.last_reviewed` | yes | ISO date (`YYYY-MM-DD`) of the last formal review. A warning shows if this is more than a year ago |
| `extra.major_revisions` | yes | At least one entry is required. See below |

### Revision entries

Each entry in `major_revisions` is a row in the revision history table on the policy page.

| Field | Required | Notes |
|---|---|---|
| `date` | yes | ISO date of the revision |
| `description` | yes | What changed and why |
| `revised_by` | yes | Who authored the change |
| `approved_by` | yes | Who approved it. Required for the audit trail |
| `version` | yes | Version string, e.g. `"1.0"` or `"2.3"` |

## Compliance framework taxonomies

Tagging controls links this policy to the SCF and SOC 2 coverage reports. Values must match control IDs in the framework data exactly. They're case-sensitive.

**SCF** uses control IDs from the Secure Controls Framework (e.g. `IAC-01`, `DCH-01`). See the SCF report page for the full list.

**TSC2017** uses SOC 2 Trust Services Criteria identifiers (e.g. `CC6.1`, `A1.2`). See the SOC 2 report page.

Any taxonomy declared in `config.toml` will show up in the Framework Coverage section on the policy page, even without a dedicated report.

## Writing the policy content

After the front matter, write the policy body in Markdown. The `policypress new` scaffold includes stubs to fill in:

```markdown
## Purpose

State what this policy is for and why it exists.

## Scope

Who and what systems this applies to.

## Policy

The substantive requirements. What is allowed, required, and prohibited.

## Exceptions

How to request an exception and who approves it.
```

Use `{{/* org() */}}` to inject the organization name from `config.toml`. Handy if the org name ever changes.

For content that should be redacted on the website but visible in internal PDFs, use the `redact` shortcode:

```markdown
{%/* redact() */%}
This text is hidden on the web but appears in the unredacted PDF.
{%/* end */%}
```

## Remove the draft flag when ready

Once the policy is reviewed and approved, set `draft: false` (or remove it). The next build generates the PDF and the policy goes live.

Update the front matter to reflect the approved revision:

```yaml
draft: false
extra:
  last_reviewed: 2026-04-15
  major_revisions:
    - date: 2026-04-15
      description: "Initial policy approved."
      revised_by: "Alice Bueler"
      approved_by: "CISO"
      version: "1.0"
```

## Open a pull request

Commit the new file on a branch and open a pull request. See [Securing Your Repository](../securing-your-repository/) for the branch protection settings and review workflow.

```bash
git checkout -b policy/acceptable-use-policy
git add content/policies/acceptable-use-policy.md
git commit -m "feat(policy): add acceptable use policy draft"
git push -u origin policy/acceptable-use-policy
```
