---
title: Editing an Existing Policy
weight: 1
description: How to change a policy
summary: How to add change a policy
---

## Live Editing

Any page, including policies and this one, can be edited with any markdown or text editor (eg, notepad, VSCode, etc).
However, it is often convenient to see what the changes will look like as they are made.

To do this, you can run `devbox run serve` in the root of the project. This will start a local web server that serves the site and automatically reloads the page when changes are made.

## Editing a Policy

To edit a policy, you will need to edit the front matter and the content of the policy.

### Front Matter

When editing, you will need to update the front matter to reflect the changes made to the policy. This includes updating the `last_reviewed` date, adding a new entry to the `major_revisions` list, and updating the `version` number.

You can refer to [Adding a Policy](@/guides/adding-a-policy.md#adding-front-matter) for more information on the front matter.

### Saving Changes

After making changes to the policy, save the file. If you are running `devbox run serve`, the changes will be automatically reflected in the local web server.

## Committing Changes

Once you are satisfied with the changes, you can commit them to the repository. Make sure to include a clear and concise commit message that describes the changes made.

```bash
$> git add .
$> git commit -m "Edited policy for clarity and accuracy"
```