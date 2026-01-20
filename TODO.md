# PolicyPress Q1 2026 Release TODO

**Target Date:** March 31, 2026  
**Current Status:** 0.3.0 Beta → 1.0.0 Production  
**Release Goal:** Users can run PolicyPress as a GitHub Action on their policy repo

---

## 🎯 CRITICAL PATH (Weeks 1-4)

### Week 1: GitHub Action Foundation

- [ ] **Create `action.yml`**
  - [ ] Define inputs: `config_path`, `output_dir`, `draft_mode`, `redact_mode`
  - [ ] Define outputs: `pdf_path`, `site_path`, `report_path`
  - [ ] Set up composite action or Docker action
  - [ ] Test locally with `act`

- [ ] **Build Docker Image**
  - [ ] Create `Dockerfile` with:
    - [ ] Zig 0.15.2
    - [ ] Pandoc latest
    - [ ] Zola 0.20.0
    - [ ] mermaid-filter (with ARM fallback)
    - [ ] ImageMagick
    - [ ] All fonts/LaTeX dependencies
  - [ ] Multi-stage build for size optimization
  - [ ] Publish to `ghcr.io/sc2in/policypress`

- [ ] **Test End-to-End**
  - [ ] Create test repo: `policypress-test-action`
  - [ ] Add sample config + policies
  - [ ] Run action in `.github/workflows/test.yml`
  - [ ] Verify PDFs and site generate

---

### Week 2: Starter Template & Examples

- [ ] **Create `policypress-starter` Repository**
  - [ ] Minimal `config.toml` with comments explaining each field
  - [ ] Example policies:
    - [ ] `access-control.md` - Shows SCF/ISO 27001 mapping
    - [ ] `incident-response.md` - Shows revisions, owner fields
    - [ ] `data-classification.md` - Shows redaction shortcode
  - [ ] `.github/workflows/build.yml`:

    ```yaml
    name: Build Policies
    on: [push]
    jobs:
      build:
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v4
          - uses: sc2in/policypress@v1
            with:
              config_path: config.toml
          - uses: actions/upload-artifact@v4
            with:
              name: policies
              path: zig-out/
    ```

  - [ ] README with:
    - [ ] "Click Use This Template" instructions
    - [ ] How to customize config
    - [ ] How to add your first policy
    - [ ] How to deploy site (GitHub Pages, Netlify, Cloudflare)

- [ ] **Update Main README**
  - [ ] Replace TODO in Quick Start with real config example
  - [ ] Add GitHub Action usage section
  - [ ] Link to starter template
  - [ ] Add architecture diagram (Mermaid)

---

### Week 3: Documentation & Error Hardening

- [ ] **Complete Documentation**
  - [ ] Create `docs/github-actions.md`:
    - [ ] Basic usage
    - [ ] All action inputs/outputs documented
    - [ ] Deployment examples (Pages, S3, etc.)
    - [ ] Troubleshooting common issues
  - [ ] Create `docs/configuration.md`:
    - [ ] Every `config.toml` field explained
    - [ ] Policy frontmatter reference
    - [ ] Framework taxonomy guide (SCF, ISO 27001, SOC 2)
  - [ ] Create `docs/policy-writing.md`:
    - [ ] Frontmatter requirements
    - [ ] Shortcodes: `{{ org() }}`, `{% mermaid() %}`, `{% redact() %}`
    - [ ] Versioning best practices
    - [ ] Zola `@/` link syntax

- [ ] **Error Message Audit**
  - [ ] Add startup validation (check pandoc, zola, mermaid-filter exist)
  - [ ] Replace internal paths with user-friendly messages:
    - Before: `File: /home/user/project/... not found`
    - After: `Policy file not found: policies/access-control.md`
  - [ ] Add "Did you forget to...?" suggestions for common errors
  - [ ] Make Pandoc errors propagate cleanly (fix TODO in `pandoc.zig:25`)

- [ ] **Configuration Validation Improvements**
  - [ ] Validate `extra.logo` file exists in `static/`
  - [ ] Validate `extra.pdf_color` format (#RRGGBB)
  - [ ] Warn if `policies/` directory empty
  - [ ] Fail early if required frontmatter missing (move from runtime to parse time)

---

### Week 4: Polish & Beta Testing

- [ ] **Real-World Testing**
  - [ ] Internal test: Run on SC2's own policies
  - [ ] External test: Get 2-3 beta users to try starter template
  - [ ] Collect feedback on:
    - [ ] Setup friction points
    - [ ] Error message clarity
    - [ ] Missing features

- [ ] **Create `CHANGELOG.md`**
  - [ ] Document v1.0.0 features
  - [ ] Migration guide from v0.3.0 (if any breaking changes)

- [ ] **Add `CONTRIBUTING.md`**
  - [ ] Development setup (devbox shell)
  - [ ] How to run tests
  - [ ] Code style guide
  - [ ] PR process

---

## 🚀 SHOULD-HAVE (Weeks 5-8)

### Week 5: Release Automation

- [ ] **GitHub Release Workflow**
  - [ ] Create `.github/workflows/release.yml`
  - [ ] Trigger on tag push (`v*`)
  - [ ] Build cross-platform binaries:
    - [ ] Linux x86_64
    - [ ] macOS x86_64
    - [ ] macOS ARM64 (M1/M2)
    - [ ] Windows x86_64
  - [ ] Upload binaries to GitHub Release
  - [ ] Auto-generate release notes from `CHANGELOG.md`

- [ ] **Version Management**
  - [ ] Add version to `build.zig` (embed in binaries)
  - [ ] `--version` flag for all CLIs
  - [ ] Update Docker image tags on release

---

### Week 6: Cross-Platform Support

- [ ] **CI Matrix Testing**
  - [ ] Update `.github/workflows/ci.yml`:

    ```yaml
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    ```

  - [ ] Fix Windows-specific issues (path separators, etc.)

- [ ] **ARM Mac Support**
  - [ ] Investigate mermaid-filter alternatives for aarch64-darwin
  - [ ] Or: Build custom mermaid-filter for ARM
  - [ ] Or: Gracefully degrade (skip mermaid diagrams with warning)

---

### Week 7: Integration Testing

- [ ] **Full Pipeline Tests**
  - [ ] Test: Bad config → Clear error
  - [ ] Test: Missing frontmatter → Helpful error
  - [ ] Test: Valid policies → PDFs + HTML generated
  - [ ] Test: Draft mode adds watermark
  - [ ] Test: Redact mode removes sensitive content

- [ ] **Performance Benchmarks**
  - [ ] Measure build time for 1, 10, 100 policies
  - [ ] Document expected performance in README

---

### Week 8: Security & Compliance

- [ ] **Security Audit**
  - [ ] Review for path traversal vulnerabilities (especially in file sanitization)
  - [ ] Add SECURITY.md with disclosure policy
  - [ ] Run static analysis (if tools exist for Zig)

- [ ] **License Compliance**
  - [ ] Verify all dependencies compatible with AGPL-3.0
  - [ ] Add license headers to all source files (already in some)
  - [ ] Generate SBOM (Software Bill of Materials)

---

## 💎 NICE-TO-HAVE (Weeks 9-10)

### Polish & Marketing

- [ ] **Video Tutorial**
  - [ ] 5-minute "Getting Started" screencast
  - [ ] Upload to YouTube
  - [ ] Link from README

- [ ] **Real-World Examples**
  - [ ] Fill README line 162 (Real-World Use Cases)
  - [ ] Get testimonials from beta users
  - [ ] Create showcase page on GitHub Pages

- [ ] **Comparison Guide**
  - [ ] PolicyPress vs Vanta/Drata/Secureframe
  - [ ] When to use PolicyPress
  - [ ] Integration patterns

---

## 🔧 TECHNICAL DEBT (Future Releases)

### Post-1.0 Cleanup

- [ ] **Consolidate Frontmatter Parsers**
  - [ ] Pick canonical format: YAML or TOML
  - [ ] Merge `src/utils.zig:FM` into `src/frontmatter.zig`
  - [ ] Update all consumers to use unified API

- [ ] **Refactor `build.zig`**
  - [ ] Extract module setup into helper functions
  - [ ] Reduce duplication in dependency wiring

- [ ] **Logging Improvements**
  - [ ] Structured logging (JSON output for CI)
  - [ ] Verbosity levels (`-v`, `-vv`)
  - [ ] Quiet mode (`-q`)

---

## 📊 RELEASE CRITERIA

### Must Pass Before v1.0.0

- [x] Core functionality works (PDF + HTML + Reports)
- [ ] GitHub Action published and documented
- [ ] Starter template exists and is tested
- [ ] All README TODOs removed
- [ ] Error messages user-friendly
- [ ] At least 3 external beta testers successfully use it
- [ ] Zero P0 bugs (crashes, data loss, security issues)
- [ ] Cross-platform tested (Linux + macOS minimum)
- [ ] Documentation complete (setup, usage, troubleshooting)
- [ ] CHANGELOG.md and CONTRIBUTING.md exist

---

## 🎯 LAUNCH PLAN

### Week 9: Soft Launch

- [ ] Announce v1.0.0-rc1 to:
  - [ ] compliance/infosec subreddits
  - [ ] Zig community
  - [ ] Beta testers from Week 4
- [ ] Collect feedback
- [ ] Fix critical issues

### Week 10: Full Release

- [ ] Tag v1.0.0
- [ ] Publish GitHub Release with binaries
- [ ] Update README badges to remove "Beta"
- [ ] Announce on:
  - [ ] Twitter/X
  - [ ] Hacker News (Show HN)
  - [ ] Lobsters
  - [ ] Reddit (r/selfhosted, r/cybersecurity, r/compliance)
- [ ] Submit to:
  - [ ] GitHub Trending
  - [ ] Awesome Zig list

---

## 📝 NOTES

### Current Strengths

✅ Solid Zig codebase  
✅ Well-structured build system  
✅ Reproducible with Nix/Devbox  
✅ Core PDF/HTML generation works  

### Current Gaps

❌ No GitHub Action (core UX promise)  
❌ No starter template (high friction)  
❌ Incomplete documentation  
❌ Some error messages not user-friendly  

### Risk Mitigation

- **If running behind:** Cut Nice-to-Have features, focus on Critical Path
- **If Action is too complex:** Start with Docker action (simpler than composite)
- **If ARM Mac issues persist:** Document limitation, add to roadmap

---

**Timeline Summary:**

- **Weeks 1-4:** CRITICAL PATH → Minimum viable release
- **Weeks 5-8:** Quality & confidence → Production-grade
- **Weeks 9-10:** Launch & polish → Marketing-ready

**Estimated Effort:** ~120-160 hours (3-4 weeks full-time, or 8-10 weeks at 50% time)

**Next Action:** Start Week 1 with `action.yml` and Docker image. Everything else depends on this.
