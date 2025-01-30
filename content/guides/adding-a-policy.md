---
title: Creating a New Policy
weight: 1
description: How to add a policy to the SC2 Policy Center
summary: How to add a policy to the SC2 Policy Center
---

Policies are the core content type of the SC2 Policy Center. This guide will help you create a policy and get it published.

## Creating a new policy file

Navigate to the `content/policies` directory and create a new file with the following naming convention:

```bash
$> nano <policy-slug>.md
```

## Adding front matter

The front matter is a set of key-value pairs that provide metadata about the policy. This information is used to generate the policy's page, produce the pdfs, and create reports. The front matter format is [YAML](https://www.cloudbees.com/blog/yaml-tutorial-everything-you-need-get-started), which is a human-readable data serialization format. Here is an example of the front matter for a policy:

```yaml
---
# These fields are required
title: Privacy Policy
description: The SC2 Privacy Policy
weight: 1

# Optional fields
summary: We take your privacy seriously.
date: 2023-09-07 16:13:18+02:00
lastmod: 2023-09-07 16:13:18+02:00

# Taxonomies are used to group policies by the frameworks they address
taxonomies:
  # Each unique standard that the policy supports should have its own entry
  TSC2017: ["CC1.1","P1.1"]
  # Specific control IDs that the policy supports or implements should be listed
  ISO27001:
  - '2.1'
  - '2.2'
  - '5.3'

extra:
  # Owner is the individual ultimately responsible for the policy. 
  # This should not be a team or group
  owner: Ben Craton
  # Last reviewed date is the last time the policy was reviewed 
  # for accuracy and completeness. 
  # This is separate from the date the policy was last updated. 
  # The date should be in the format YYYY-MM-DD
  last_reviewed: 2024-02-20
  # Major revisions are significant changes to the policy that 
  # materially affect its content or implementation
  major_revisions:
  - date: 2023-09-07 # Date of the revision
    description: Initial version. # Description of what was changed
    revised_by: Ben Craton # Individual who made the changes
    approved_by: Ben Craton # Individual who approved the changes
    version: '1.0' # Version of the policy after the changes were made
---
```

### Important notes on front matter

- Taxonomies are used to group policies by the frameworks they address. Each unique standard that the policy supports should have its own entry. Specific control IDs that the policy supports or implements should then be listed under the appropriate standard. If a policy does not support a specific control ID, it should not be listed.
  - Using YAML, these can be listed as a string (e.g. `TSC2017: "CC1.1"`) or as a list (e.g. `TSC2017: ["CC1.1", "CC1.2"]`).
  - The list may also be expressed with one item per line for easier readability (as shown in the ISO example above).
- The `extra` section is used to capture additional information about the policy.
  - The `owner` field should be an individual, not a team or group.
  - The `last_reviewed` field should be a date in the format YYYY-MM-DD.
  - The `major_revisions` field should capture significant changes to the policy, including the date of the revision, a description of what was changed, the individual who made the changes, the individual who approved the changes, and the version of the policy after the changes were made.

## Adding content

After the front matter, you can add the content of the policy. You can use [Markdown](https://www.markdownguide.org/) to format the text. For example:

```markdown
# Introduction
This policy outlines our commitment to protecting the privacy of our users.
# Scope
This policy applies to all users of our services.
```
## Saving and committing the file
After you have added the front matter and content, save the file and commit it to the repository:

```bash
$> git add <policy-slug>.md
$> git commit -m "Add <policy-slug> policy"
```