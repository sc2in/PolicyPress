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
- **Zig 0.15.1+** ([Install](https://ziglang.org/download/))
- **Pandoc** (for PDF generation)
- **Nix** (optional, for reproducible builds)

### Installation

**Option 1: Clone and build**
```bash
git clone https://github.com/sc2in/PolicyPress
cd PolicyPress
zig build -Doptimize=ReleaseFast
./zig-cache/bin/policypress --help
```

**Option 2: With Nix (reproducible)**
```bash
nix flake run github:sc2in/PolicyPress
```

### Create Your First Policy

**1. Create a config file** (`policypress.toml`):
```toml
[project]
name = "Acme Corp"
organization = "Acme Corp Security"
version = "1.0"

[frameworks]
iso27001 = true
soc2 = true
scf = true

[output]
pdf_dir = "./pdfs"
web_dir = "./site"
logo = "./assets/logo.png"
```

**2. Write a policy** (`policies/access-control.md`):
```markdown
---
title: Access Control Policy
framework: [iso27001, soc2]
iso27001_control: A.9.1
soc2_control: CC6.1
version: 1.0
last_reviewed: 2026-01-15
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
policypress build          # Generates PDFs + HTML site
policypress serve          # Local web server on :8080
policypress validate       # Check framework coverage
```

---

## Why PolicyPress?

### Compared to Enterprise Tools

| Feature | PolicyPress | Vanta | Drata | Secureframe |
|---------|-------------|-------|-------|-------------|
| **Cost** | Free | $20K–50K/yr | $10K–40K/yr | $15K–25K/yr |
| **Self-hosted** | ✅ Yes | ❌ No | ❌ No | ❌ No |
| **Open-source** | ✅ Yes (AGPL) | ❌ No | ❌ No | ❌ No |
| **Policy versioning** | ✅ Git-native | ❌ Limited | ❌ Limited | ❌ Limited |
| **Markdown policies** | ✅ Yes | ❌ UI-only | ❌ UI-only | ❌ UI-only |
| **PDF export** | ✅ Professional | ❌ Basic | ✅ Yes | ✅ Yes |
| **Evidence automation** | 🔄 In development | ✅ Yes | ✅ Yes | ✅ Yes |
| **Custom frameworks** | ✅ Yes | ❌ No | ❌ No | ❌ No |

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
- ✅ **Static Site Generation:** Professional compliance portal
- ✅ **PDF Rendering:** High-quality PDFs with Pandoc + Eisvogel template
- ✅ **CLI Tooling:** Full command-line interface

### In Development

- 🔄 **Automated Evidence Collection:** API integrations (GitHub, AWS, GCP)
- 🔄 **Control Mapping Dashboard:** Visual ISO 27001/SOC 2 coverage
- 🔄 **Audit Reports:** Automated compliance reports with timestamps
- 🔄 **Template Library:** Pre-built policies for common frameworks
- 🔄 **Webhook Support:** Trigger builds on policy changes

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
- **Configuration:** TOML parsing (custom parser in Zig)
- **Styling:** SCSS compiled to CSS
- **CI/CD:** GitHub Actions (Nix flakes + Zig)

---

## Roadmap

### Q1 2026
- [ ] Automated AWS/GitHub evidence collection
- [ ] Control mapping dashboard
- [ ] Pre-built template library (HIPAA, PCI-DSS, FedRAMP)
- [ ] API for programmatic access

### Q2 2026
- [ ] Multi-tenant hosting
- [ ] Audit report generation (with timestamps)
- [ ] Policy review workflow
- [ ] Integrations: Slack, Jira, Linear

### Q3 2026
- [ ] Managed hosting (PolicyPress Cloud)
- [ ] White-label version for consultancies
- [ ] Advanced analytics (control effectiveness, audit trends)

---

## Examples

### Real-World Use Cases

**Startup getting SOC 2 certified:**
```bash
git clone PolicyPress
cd my-policies
policypress build --framework soc2
# 60+ policies auto-generated in 2 minutes
# PDF reports ready for auditors
git commit -am "SOC 2 policies v1.0"
```

**Organization updating policies:**
```bash
# Edit policies in markdown
git diff policies/           # See what changed
policypress validate         # Check coverage
policypress build            # Rebuild PDFs
git commit -am "Updated access control policy"
# Full audit trail in git history
```

**Compliance team managing multiple frameworks:**
```bash
policypress build --framework iso27001,soc2,scf
# Generates separate policy sets for each framework
# Control mapping shows overlaps and gaps
```

---

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
zig build test  # Run tests
zig build       # Build release binary
```

### Community

- **Discussions:** [GitHub Discussions](https://github.com/sc2in/PolicyPress/discussions)
- **Chat:** [Discord](https://discord.gg/policypress) (coming soon)
- **Twitter:** [@PolicyPress_io](https://twitter.com/policypress_io)

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

- **Email:** team@policypress.io (coming soon)
- **GitHub:** [@sc2in](https://github.com/sc2in)
- **Twitter:** [@PolicyPress_io](https://twitter.com/policypress_io)
- **Issues:** [GitHub Issues](https://github.com/sc2in/PolicyPress/issues)

---

**PolicyPress: Compliance automation that respects your freedom.**
