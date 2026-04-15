---
title: Writing Policies
weight: 2
description: How to structure and write policy content in PolicyPress
summary: Structure, front matter, shortcodes, and tone guidance for authoring policies
---

This guide covers how to write policy content that works in both the web view and the generated PDFs.

## Front matter reference

Every policy file starts with a YAML block between `---` delimiters. Here are the fields PolicyPress recognizes.

### Required fields

```yaml
---
title: Acceptable Use Policy
description: Rules governing use of company IT systems, networks, and data
extra:
  last_reviewed: 2026-01-01
  major_revisions:
    - date: 2026-01-01
      description: Initial version.
      revised_by: Alice Bueler
      approved_by: CEO
      version: "1.0"
---
```

| Field | Description |
|---|---|
| `title` | Policy title. Appears in the PDF header, cover page, and site nav |
| `description` | One-sentence summary shown in policy lists and search results |
| `extra.last_reviewed` | Date (YYYY-MM-DD) the policy was last reviewed for accuracy |
| `extra.major_revisions` | Array of revision entries. At least one is required |

Each revision entry needs:

| Sub-field | Description |
|---|---|
| `date` | Date of this revision (YYYY-MM-DD) |
| `description` | What changed |
| `revised_by` | Who made the change |
| `approved_by` | Who approved it |
| `version` | Version string after this revision (e.g. `"1.0"`, `"2.1"`) |

### Optional fields

```yaml
weight: 10                # sort order on the policies index page
taxonomies:
  TSC2017: [CC1.1, CC6.1]
  SCF: [GOV-01, IAC-01]
extra:
  owner: Alice Bueler     # person ultimately responsible for this policy
  math: true              # enable LaTeX math rendering on this page
```

Taxonomies link policies to compliance frameworks. Values must match exactly what is declared in `config.toml`. A policy not tagged to any framework won't show up in any report.

## Body structure

A well-structured policy has these sections, roughly in order:

1. **Purpose and Scope** - what the policy is for and who it applies to
2. **Definitions** - terms that need a precise meaning in this context
3. **Policy Statements** - the actual rules, organized by topic
4. **Roles and Responsibilities** - who is accountable for what
5. **Enforcement** - consequences for violations and who enforces them
6. **Exceptions** - how to request and document exceptions
7. **Review and Updates** - how often the policy is reviewed

Not every policy needs every section. Purpose/Scope and Policy Statements are always required.

## Shortcodes

PolicyPress provides a few shortcodes for common patterns.

### `{{/* org() */}}` - organization name

Inserts the organization name from `config.toml → [extra.policypress].organization`. Use this instead of hardcoding the name so policies stay correct if the config changes.

```markdown
This policy applies to all employees of {{/* org() */}}.
```

### `{%/* redact() */%} ... {%/* end */%}` - redactable content

Marks content for redaction on the website. When `redact_web = true` is set in `[extra.policypress]` (or passed via the `--redact` CLI flag), the enclosed text is replaced with a solid redaction bar. When redaction is off, the content displays normally.

```markdown
Contact the key custodian at:
{%/* redact() */%}security-keys@example.com{%/* end */%}
for access to the recovery vault.
```

Good uses:

- Contact details (email addresses, phone numbers)
- Internal system names or IP ranges
- Vendor names that shouldn't appear in external copies

### `{%/* mermaid() */%} ... {%/* end */%}` - diagrams

Renders a [Mermaid](https://mermaid.js.org/) diagram on the site and converts it to an image in PDFs.

```markdown
{%/* mermaid() */%}
graph TD
    A[Incident Detected] --> B{Severity?}
    B -->|Critical| C[Page on-call]
    B -->|Low| D[Create ticket]
{%/* end */%}
```

Supported types include `graph`, `sequenceDiagram`, `flowchart`, `classDiagram`, and `gantt`. See [Mermaid docs](https://mermaid.js.org/intro/) for the full syntax.

> [!NOTE]
> Mermaid diagrams require `mermaid-filter` at build time. It's included in the PolicyPress devshell and GitHub Action automatically.

### `{%/* admonition(type="...") */%} ... {%/* end */%}` - callout boxes

Highlights important information with a colored callout.

```markdown
{%/* admonition(type="warning") */%}
Access is suspended automatically after 30 days without completing attestation.
{%/* end */%}
```

Available types:

| Type | Color | Use for |
|---|---|---|
| `note` | Blue | Supplementary information |
| `tip` | Green | Helpful suggestions or shortcuts |
| `important` | Purple | Key points the reader must not miss |
| `warning` | Yellow | Situations that could cause problems |
| `danger` | Red | Serious risks or terminable offenses |

You can override the title:

```markdown
{%/* admonition(type="important", title="Legal Hold") */%}
Do not delete any documents if you receive a legal hold notice.
{%/* end */%}
```

## Writing guidance

**Use plain language.** Policies are read by everyone, not just legal or security teams. Short sentences and active voice are clearer than formal legalese.

> Instead of: *"Personnel shall ensure that all access privileges are commensurate with job function requirements."*
> Write: *"Only grant access that the role actually needs."*

**Be specific about scope.** Say exactly who the policy applies to: all employees, contractors only, systems that handle PII, etc. Ambiguous scope is a common audit finding.

**Separate what from how.** A policy states what must happen. Procedures and runbooks cover how to do it. Keep the two separate so policies don't need to change every time a tool changes.

**Every rule should have an owner.** Use `extra.owner` in front matter to record who is responsible for keeping this policy current. Ownerless policies go stale.

**Version material changes only.** Add a `major_revisions` entry when policy substance changes in a way that affects behavior or compliance posture. The following do not warrant a new revision entry:

- Fixing a typo or grammar error
- Formatting or whitespace changes
- Updating `extra.last_reviewed` as part of a periodic review where nothing changed
- Rewording a sentence without changing its meaning

If an auditor would ask "what changed and why," that's a material change. If they wouldn't notice, it isn't. PolicyPress uses the most recent revision's `version` field to name the PDF file, so bumping the version for a typo fix creates unnecessary churn in your audit trail.
