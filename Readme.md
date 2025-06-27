# PolicyPress

**Open-source, AGPL-licensed policy management for ISO 27001, SOC 2, and Secure Controls Framework compliance**

PolicyPress is a modern, automated policy management platform designed for SMBs, compliance managers, and organizations who want to streamline internal policy workflows, reduce audit stress, and ensure all improvements remain open and accessible to the community.  
Built with [Zola](https://www.getzola.org/) and [Pandoc](https://pandoc.org/), PolicyPress generates searchable internal websites and audit-ready PDFs directly from Markdown, with validation and mapping to ISO 27001, SOC 2, and the Secure Controls Framework (SCF).

## Features

- **Markdown-First**: Write and maintain policies in simple, version-controlled Markdown files.
- **Automated Website**: Build a searchable, internal policy portal using Zola.
- **PDF Generation**: Instantly create branded, audit-ready PDFs from your policies with Pandoc.
- **Framework Mapping & Validation**: Map and validate policies against ISO 27001, SOC 2, and SCF controls.
- **Reporting**: Generate JSON reports mapping your policies to control requirements.
- **Draft & Redacted Outputs**: Easily produce draft watermarked or redacted policy sets.
- **Open Source & Community-Oriented**: Licensed under AGPLv3 to ensure improvements benefit all.

## Quick Start

### Prerequisites

- [Zig](https://ziglang.org/) (for build automation)
- [Zola](https://www.getzola.org/) (static site generator)
- [Pandoc](https://pandoc.org/) (document converter)
- [Git](https://git-scm.com/) (for version control)

### Build Steps

All functionality is orchestrated via the Zig build system.  
To see available build steps, run:

```sh
zig build --help
```

Common build commands:

- **Build the internal website:**  

  ```sh
  zig build web
  ```

- **Serve the website locally:**  

  ```sh
  zig build preview
  ```

- **Generate all policy PDFs:**  

  ```sh
  zig build pdfs
  ```

  - Add `-Ddraft=true` to watermark as draft.
  - Add `-Dredact=true` to redact sensitive info.
- **Generate compliance reports:**  

  ```sh
  zig build reports
  ```

- **Run unit tests:**  

  ```sh
  zig build test
  ```

## Directory Structure

```
.
├── content/policies/           # Your Markdown policy files
├── static/logo.png             # Organization logo for branding
├── templates/                  # Zola and PDF templates
├── src/                        # Zig source modules (Pandoc, server, etc.)
├── public/                     # Built website output
├── pdfs/                       # Generated PDF outputs
├── docs/                       # Documentation output
├── LICENSE                     # AGPLv3 license
├── README.md                   # This file
```

## Example Policy Metadata

Each policy can include metadata for framework mapping and revision history.

```markdown
---
title: Access Control Policy
taxonomies:
  TSC2017:
    - CC6.1
    - CC6.2
    - CC6.3
    - CC6.6
  SCF:
    - HRS-05.7
    - HRS-06
    - HRS-06.1
    - HRS-13
    - HRS-13.1
    - HRS-13.2
    - HRS-13.3
    - IAM-01
    - IAM-02
    - IAM-16
    - IAM-17
extra:
  owner: SC2
  last_reviewed: 2025-04-16
  major_revisions:
    - date: 2025-02-06
      description: Initial version.
      revised_by: Ben Craton
      approved_by: Ben Craton
      version: "1.0"
---
Policy content goes here...
```

## License

PolicyPress is licensed under the **GNU Affero General Public License v3.0 (AGPL-3.0)**.

> You are free to use, modify, and distribute PolicyPress, provided that any modifications or derivative works, including those used over a network, are also licensed under the AGPL and the source code is made available.

For organizations wishing to use PolicyPress under different terms, please contact the maintainers for commercial licensing options.

## Contributing

Contributions are welcome! Please open issues or pull requests for bug fixes, improvements, or new features.

## Community & Support

- [Issues](https://github.com/your-org/policypress/issues)
- [Discussions](https://github.com/your-org/policypress/discussions)

**PolicyPress**: Compliance, Automated. Policies, Organized.  
Built for the community, by the community.

[1] <https://ppl-ai-file-upload.s3.amazonaws.com/web/direct-files/attachments/18980759/b23fe3b6-0c36-43c9-93af-d0693e1619a3/paste.txt>
