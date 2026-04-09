---
title: Compliance Frameworks
weight: 6
description: How to map policies to compliance frameworks and build a custom control taxonomy
summary: Define control taxonomies, tag policies to controls, and generate coverage reports for any compliance framework
---

PolicyPress can map your policies to any compliance framework - SOC 2, ISO 27001, a custom internal framework, or anything else. The mapping shows up on the website as a coverage report per framework, and links each control to the policies that satisfy it.

This guide walks through building a taxonomy from scratch. The Secure Controls Framework (SCF) is the example that ships with PolicyPress, so you can study those files as a reference.

## How it works

The compliance framework feature has two parts:

1. **Taxonomy declaration** - tells Zola that a framework exists and how to route its pages
2. **Control data file** - a YAML list of the controls in that framework, used by the report template to compute coverage

Policies opt in to a framework by listing control IDs in their front matter. The report page then shows which controls are covered (at least one policy tagged to them) versus uncovered.

## Step 1 - Declare the taxonomy

Add a `[[taxonomies]]` block to `config.toml` for each framework:

```toml
[[taxonomies]]
name = "ACME"     # used in front matter and URLs
render = true     # generates browseable pages at /ACME/{control-id}/
```

`name` is case-sensitive and becomes the key in policy front matter. `render = true` generates a page for each control showing which policies are tagged to it. Set `render = false` to index the taxonomy for reports without exposing public pages.

You can declare as many frameworks as you need:

```toml
[[taxonomies]]
name = "ACME"
render = true

[[taxonomies]]
name = "ISO27001"
render = false
```

## Step 2 - Create a control data file

Create a YAML file listing every control in your framework. Place it anywhere in the repository - `templates/opencontrols/standards/` is the convention.

```yaml
- domain: Access Control
  control_id: AC-01
  control: Access Control Policy

- domain: Access Control
  control_id: AC-02
  control: Account Management

- domain: Incident Response
  control_id: IR-01
  control: Incident Response Policy

- domain: Incident Response
  control_id: IR-02
  control: Incident Handling
```

Each entry requires three fields:

| Field | Description |
|---|---|
| `domain` | Group label - used to organize controls into sections on the report page |
| `control_id` | Unique identifier - must match exactly what you'll write in policy front matter |
| `control` | Short name for the control |

> [!NOTE]
> Do not include description text copied verbatim from a third-party framework (such as SCF or ISO 27001) without verifying the framework's license allows redistribution. The SCF example files ship with descriptions removed for this reason. If you are authoring your own framework from scratch, write your own descriptions - or omit the field entirely.

Point PolicyPress at the file by adding an `[extra]` key to `config.toml`. The key name is arbitrary, but pick something that matches your template (you'll reference it there):

```toml
[extra]
acme_controls = "templates/opencontrols/standards/ACME.yml"
```

## Step 3 - Create the report template

PolicyPress ships templates for SCF (`templates/SCF/list.html`) and SOC 2 (`templates/TSC2017/list.html`). Copy one and adapt it for your framework.

Create `templates/ACME/list.html`:

```html
{% extends "reports/base.html" %}
{% import 'macros/coverage-bar.html' as macros_coverage %}

{% block report_content %}
{% set tax = get_taxonomy(kind="ACME") %}
{% set data = load_data(path=config.extra.acme_controls) %}
{% set line_items = tax.items | group_by(attribute="name") %}

{% set covered_count = tax.items | length %}
{% set total_count = data | length %}
{{ macros_coverage::coverage_bar(covered=covered_count, total=total_count, label="ACME Control Coverage") }}

{% set domain_groups = data | group_by(attribute="domain") %}

{% for domain, domain_items in domain_groups %}
<div class="report-section">
  <h2 class="section-title">{{ domain }}</h2>
  {% for ctrl_id, ctrl_group in domain_items | group_by(attribute="control_id") %}
  {% set ctrl = ctrl_group | first %}
  {% set covered = ctrl_id in line_items %}
  <div class="control-item {{ 'covered' if covered else 'not-covered' }}">
    <span class="control-id">{{ ctrl_id }}</span>
    <span class="control-name">{{ ctrl.control }}</span>
    {% if covered %}
    <ul class="policy-list">
      {% for item in line_items[ctrl_id] %}
      <li><a href="{{ item.permalink }}">{{ item.name }}</a></li>
      {% endfor %}
    </ul>
    {% endif %}
  </div>
  {% endfor %}
</div>
{% endfor %}
{% endblock report_content %}
```

The key variables:
- `get_taxonomy(kind="ACME")` - loads all policies tagged to any `ACME` control
- `load_data(path=...)` - loads your YAML control list
- `line_items` - a map from control ID to the policies tagged to it

## Step 4 - Create the report content page

Create a content page that uses your template. The `template` field must match the filename you created in the previous step:

```
content/reports/acme.md
```

```toml
+++
title = "ACME Framework Coverage"
description = "Policy coverage against the ACME control framework"
template = "ACME/list.html"
weight = 3
[extra]
+++
```

Then add a link to it in `config.toml` if you want to reference it from other parts of the site:

```toml
[extra]
acme_report_page = "@/reports/acme.md"
```

## Step 5 - Tag policies

In each policy's front matter, list the control IDs it satisfies:

```yaml
---
title: Access Control Policy
taxonomies:
  ACME:
    - AC-01
    - AC-02
---
```

The IDs must match `control_id` values in your YAML file exactly (case-sensitive). A policy can cover controls from multiple frameworks simultaneously:

```yaml
taxonomies:
  ACME:
    - AC-01
  SCF:
    - IAC-01
    - IAC-02
```

## The SCF example

The SCF files in `templates/opencontrols/standards/` show a real-world example of this pattern at scale (~1,200 controls). The SCF is published by the [Secure Controls Framework Council](https://securecontrolsframework.com/) under CC BY-ND 4.0. The files ship with descriptions removed - only control IDs, names, and domains are included.

To use SCF, the taxonomy is already declared in the starter `config.toml`:

```toml
[[taxonomies]]
name = "SCF"
render = false
```

And the control data path:

```toml
[extra]
scf_controls = "templates/opencontrols/standards/SCF.yml"
```

Tag a policy to SCF controls the same way as any other framework:

```yaml
taxonomies:
  SCF:
    - GOV-01
    - HRS-05
    - IAC-01
```

## Custom internal frameworks

You are not limited to published frameworks. An internal framework might map policies to your company's own control catalogue, risk register, or department-specific requirements:

```yaml
- domain: HR Controls
  control_id: HR-AUP-01
  control: Acceptable Use Acknowledgement

- domain: HR Controls
  control_id: HR-NDA-01
  control: Confidentiality Agreement on Hire

- domain: IT Controls
  control_id: IT-ACC-01
  control: Least-Privilege Access Review
```

The workflow is identical - declare the taxonomy, create the YAML, create the template, tag your policies.
