---
title: "Editing Without Git"
weight: 11
description: "Edit policies from your browser: the GitHub web editor, github.dev, and an optional CMS"
summary: "Edit policies from your browser: the GitHub web editor, github.dev, and an optional CMS"
---

You do not need a terminal, an editor, or any Git knowledge to maintain a
PolicyPress site. Every path below ends the same way: a commit lands in your
repository, the GitHub Action rebuilds the site and PDFs, and the revision
history keeps itself.

## The GitHub web editor (zero setup)

The simplest path, and the one we recommend for occasional edits:

1. Open your policy repository on github.com and browse to
   `content/policies/`.
2. Click the policy file, then the **pencil icon** (Edit this file).
3. Make your change. Remember the front matter contract: bump the version by
   adding a `major_revisions` entry and update `last_reviewed` if this was a
   review (see [Writing Policies](@/guides/writing-policies.md)).
4. Choose **Commit changes…**. If your repository protects `main`, pick
   *"Create a new branch and start a pull request"* — approval then happens as
   a pull-request review, which doubles as your documented approval trail.

Within a few minutes the site and the versioned PDF are rebuilt and published.

> [!TIP]
> Press <kbd>.</kbd> (period) on any repository page to open **github.dev** —
> a full VS Code editor in the browser, with the same commit/PR flow. Useful
> when an edit spans several files.

## Sveltia CMS (optional, for a friendlier editing UI)

If your editors would rather see a form ("Title", "Owner", "Body…") than raw
Markdown, [Sveltia CMS](https://github.com/sveltia/sveltia-cms) is a
lightweight, actively maintained content editor that runs entirely in the
browser against your GitHub repository — no server, no database, and your
content never leaves your repo. It is a drop-in successor to Decap/Netlify
CMS.

Minimal setup on a PolicyPress site:

1. Create `static/admin/index.html`:

   ```html
   <!doctype html>
   <html>
     <head>
       <meta charset="utf-8" />
       <meta name="viewport" content="width=device-width, initial-scale=1" />
       <title>Policy editor</title>
     </head>
     <body>
       <script src="https://unpkg.com/@sveltia/cms/dist/sveltia-cms.js"></script>
     </body>
   </html>
   ```

2. Create `static/admin/config.yml` describing the policy collection:

   ```yaml
   backend:
     name: github
     repo: your-org/your-policy-repo
     branch: main

   media_folder: static/images

   collections:
     - name: policies
       label: Policies
       folder: content/policies
       extension: md
       format: yaml-frontmatter
       fields:
         - { name: title, label: Title }
         - { name: description, label: Description }
         - name: extra
           label: Metadata
           widget: object
           fields:
             - { name: owner, label: Owner }
             - { name: last_reviewed, label: Last reviewed, widget: string }
         - { name: body, label: Body, widget: markdown }
   ```

3. Deploy, then open `https://your-site/admin/` and sign in with GitHub.

Two things to keep in mind:

- **Approvals still belong in `major_revisions`.** A CMS makes editing easier;
  it does not replace the review metadata your PDFs are built from. Keep the
  version/approver discipline regardless of the editor.
- The CMS script above loads from a CDN. If your policy is to self-host
  everything (as this demo does), vendor the file into `static/admin/`
  instead.

## Which should you use?

| Situation | Use |
| --- | --- |
| Occasional wording fix | GitHub web editor |
| Multi-file edit, comfortable with an editor UI | github.dev (<kbd>.</kbd>) |
| Non-technical editors, frequent changes | Sveltia CMS |
