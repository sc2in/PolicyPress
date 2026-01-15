# PolicyPress

> Open-source compliance automation for ISO 27001, SOC 2, and Secure Controls Framework. Build, version, and publish policies at scale.

[![GitHub Stars](https://img.shields.io/github/stars/sc2in/PolicyPress?style=flat-square)](https://github.com/sc2in/PolicyPress)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Built with Zig](https://img.shields.io/badge/Built%20with-Zig-F7A41D?style=flat-square)](https://ziglang.org)

## The Problem

Compliance tools are expensive ($15K–50K/year), slow, and lock you into their UX.

- **Vanta, Drata, Secureframe:** $20K–50K/year, vendor lock-in, policies trapped in their database
- **DIY compliance:** Spreadsheets, outdated Word docs, zero version control
- **Audit hell:** Scrambling to find evidence when auditors ask for policies from 6 months ago

**You own your source code. You should own your compliance policies.**

---

## What PolicyPress Does

**PolicyPress is a compliance automation engine that:**

✅ **Generates policies** from structured markdown + YAML configuration
✅ **Supports frameworks:** ISO 27001, SOC 2 (Type II), Secure Controls Framework (SCF)
✅ **Outputs:** PDF reports, static HTML sites, JSON evidence exports
✅ **Versioning:** Full git history of every policy change
✅ **Self-hosted:** Run anywhere (Nix, Docker, bare metal)
✅ **No lock-in:** AGPL-licensed, your data stays yours
✅ **Audit-ready:** Automated evidence collection, control mapping, versioning

---

## Quick Start

### Prerequisites
- **Devbox** ([Install](https://www.jetify.com/docs/devbox/installing-devbox))

### Installation

**Option 1: Clone and build**
```bash
git clone https://github.com/sc2in/PolicyPress
cd PolicyPress
devbox run ci
```


### Create Your First Policy

**1. Create a [Zola config](https://www.getzola.org/documentation/getting-started/configuration/) file** (`config.toml`):
```toml
# TODO
```

**2. Write a policy** (`policies/access-control.md`):
```markdown
---
# TODO
---

# Access Control Policy

## Scope
This policy applies to all employees and contractors.

## Policy Statement
All systems require multi-factor authentication (MFA).

### Implementation Details
- Enforce MFA at login
- Use TOTP (RFC 6238) or hardware security keys
- Disable password-only access after 2026-02-01

## Evidence
- [ ] MFA audit logs (last 90 days)
- [ ] User access review completed
```

**3. Generate outputs:**
```bash
devbox run ci          # Generates PDFs + HTML site and reports
devbox run build-pdfs          # Generates PDFs 
devbox run build-site          # Generates HTML site
devbox run serve          # Local web server on :8080
devbox run test       # Run all tests, including checking framework coverage
```

---

## Why PolicyPress?

### Compared to Enterprise Tools

| Feature                 | PolicyPress      | Vanta       | Drata       | Secureframe |
| ----------------------- | ---------------- | ----------- | ----------- | ----------- |
| **Cost**                | Free             | $20K–50K/yr | $10K–40K/yr | $15K–25K/yr |
| **Self-hosted**         | ✅ Yes            | ❌ No        | ❌ No        | ❌ No        |
| **Open-source**         | ✅ Yes (AGPL)     | ❌ No        | ❌ No        | ❌ No        |
| **Policy versioning**   | ✅ Git-native     | ❌ Limited   | ❌ Limited   | ❌ Limited   |
| **Markdown policies**   | ✅ Yes            | ❌ UI-only   | ❌ UI-only   | ❌ UI-only   |
| **PDF export**          | ✅ Professional   | ❌ Basic     | ✅ Yes       | ✅ Yes       |
| **Evidence automation** | 🔄 In development | ✅ Yes       | ✅ Yes       | ✅ Yes       |
| **Custom frameworks**   | ✅ Yes            | ❌ No        | ❌ No        | ❌ No        |

### Why Zig?

- **Performance:** Compiled binary, 0 dependencies, instant startup
- **Memory safety:** No garbage collection, no crashes from NULL pointers
- **Simplicity:** Minimal runtime, easy to audit (security-critical tool)
- **Cross-platform:** Single binary works on Linux, macOS, Windows

---

## Features

### Core

- ✅ **Policy Generation:** Markdown → PDF/HTML/JSON
- ✅ **Multi-framework Support:** ISO 27001, SOC 2, SCF (extensible)
- ✅ **Version Control:** Full git history of changes
- ✅ **Configuration Management:** TOML-based, validated at build time
- ✅ **PDF Rendering:** High-quality PDFs with Pandoc + Eisvogel template
- ✅ **Webhook Support:** Trigger builds on policy changes

### In Development

- 🔄 **CLI Tooling:** Full command-line interface
- 🔄 **Static Site Generation:** Professional compliance portal
- 🔄 **Automated Evidence Collection:** API integrations (GitHub, AWS, GCP)
- 🔄 **Control Mapping Dashboard:** Visual ISO 27001/SOC 2 coverage
- 🔄 **Audit Reports:** Automated compliance reports with timestamps
- 🔄 **Template Library:** Pre-built policies for common frameworks

### Planned

- 📋 **OIDC/OAuth2 Integration:** GitHub/Google login
- 📋 **Policy Comments:** Internal review workflow
- 📋 **Diff Viewer:** See changes side-by-side
- 📋 **Multi-tenant:** Manage multiple organizations

---

## Architecture

### Build Pipeline

```
Markdown Policies (+ YAML frontmatter)
    ↓
Configuration Validation
    ↓
Framework Mapping (ISO 27001 → Controls)
    ↓
Template Rendering (Tera engine)
    ↓
Pandoc Processing
    ├→ PDF Output (Eisvogel template)
    ├→ HTML Output (Zola static site)
    └→ JSON Output (Evidence export)
```

### Tech Stack

- **Language:** Zig 0.15.1+
- **PDF Generation:** Pandoc + Eisvogel LaTeX template
- **Web UI:** Zola static site generator + vanilla JS
- **Templating:** Tera (Jinja2-compatible)
- **Configuration:** Zola configuration extension
- **Styling:** SCSS compiled to CSS
- **CI/CD:** GitHub Actions (Devbox(nix) + Zig)

---

## Roadmap

- [ ] Automated AWS/GitHub evidence collection
- [ ] Control mapping dashboard
- [ ] Pre-built template library (HIPAA, PCI-DSS, FedRAMP)
- [ ] Multi-tenant hosting
- [ ] Audit report generation (with timestamps)
- [ ] Policy review workflow
- [ ] Integrations: Slack, Jira, Linear
- [ ] Managed hosting (PolicyPress Cloud)
- [ ] White-label version for consultancies
- [ ] Advanced analytics (control effectiveness, audit trends)

---

## Examples

### Real-World Use Cases

TODO

## Community & Support

### Contributing

We welcome:
- Bug reports ([GitHub Issues](https://github.com/sc2in/PolicyPress/issues))
- Feature requests
- Policy templates
- Framework additions (HIPAA, PCI-DSS, FedRAMP, etc.)
- Documentation improvements

**Development setup:**
```bash
git clone https://github.com/sc2in/PolicyPress
cd PolicyPress
devbox shell    # Reproducible dev environment
zig build docs  # Build documentation pages
zig build test  # Run tests
zig build       # Build release binary, site, and pdfs
```

### Community

- **Discussions:** [GitHub Discussions](https://github.com/sc2in/PolicyPress/discussions)
- **Chat:** [Discord](https://discord.gg/policypress) (coming soon)


---

## Licensing

PolicyPress is licensed under the **GNU Affero General Public License v3 (AGPL v3)**.

This means:
- ✅ Free to use, modify, and distribute
- ✅ If you modify and distribute PolicyPress, you must share your modifications
- ✅ If you use PolicyPress in a SaaS, users get the source code
- ✅ Perfect for compliance (full transparency)

[Read the full license](LICENSE)

---

## FAQ

### Is PolicyPress a replacement for Vanta/Drata?

**Not yet, but it will be.** Current status:
- ✅ Policy generation & management
- ✅ Versioning & audit trail
- ✅ PDF/HTML export
- 🔄 Evidence automation (in progress)
- 🔄 Control dashboard (in progress)

If you need automated evidence collection today, PolicyPress works great **alongside** Vanta/Drata (use PolicyPress for policy management, export evidence to their platform).

### Can I use this for HIPAA/PCI-DSS?

**Yes.** PolicyPress supports:
- Custom framework definitions (YAML)
- Any control mapping you need
- Audit-ready output with timestamps

We have HIPAA and PCI-DSS template bundles in progress.

### How is this different from open-source documentation tools?

PolicyPress is **compliance-aware:**
- Automatic control mapping
- Framework validation
- Evidence collection built-in
- Audit reporting
- Policy versioning

Tools like Docusaurus/Notion are great for docs, but they don't understand your compliance obligations.

### Can I self-host this in production?

**Yes.** PolicyPress is:
- Stateless (no database required)
- Fast (builds 100 policies in <2 seconds)
- Lightweight (single binary, ~50MB)
- Deploy anywhere: Kubernetes, VMs, serverless, bare metal

### What about pricing? Will you charge for this?

PolicyPress core will always be **free and open-source** (AGPL).

We plan optional commercial services:
- **Managed hosting** ($99–299/month)
- **Premium templates** (HIPAA, PCI-DSS, FedRAMP)
- **Support & consulting** (hourly)
- **White-label licensing** (for consultancies)

**You can always self-host for free.**

### How do I get started?

1. Clone the repo: `git clone https://github.com/sc2in/PolicyPress`
2. Follow [Quick Start](#quick-start)
3. Check out [examples](examples/) for sample policies
4. Read the [docs](docs/) for deep dives

---

## Acknowledgments

PolicyPress stands on the shoulders of giants:

- **Zig community** for an amazing language
- **Pandoc** for incredible document conversion
- **Zola** for static site generation
- **Eisvogel** for beautiful LaTeX templates
- **Compliance community** for feedback & inspiration

---

## Status

**Current Version:** v0.3.0 (Beta)

- [x] Core policy generation
- [x] PDF/HTML output
- [x] Multi-framework support
- [x] CLI tooling
- [x] Static site generation
- [ ] Automated evidence collection
- [ ] Control dashboard
- [ ] Template library
- [ ] SaaS hosting

---

## Contact

- **Email:** <inquiries@sc2.in>
- **GitHub:** [@sc2in](https://github.com/sc2in)
- **Issues:** [GitHub Issues](https://github.com/sc2in/PolicyPress/issues)

---

**PolicyPress: Compliance automation that respects your freedom.**
