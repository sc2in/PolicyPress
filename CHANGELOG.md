# Changelog

All notable changes to PolicyPress are documented here.

Versions track the tool and theme API. The major version will remain 0.x
until the public API (action inputs/outputs, config.toml schema, front matter
keys) is considered stable.

## [Unreleased]

### Added

- Example content for demo and onboarding purposes.
- LICENSE, README, CONTRIBUTING, SECURITY, and CODE_OF_CONDUCT.
- GitHub Action (`action.yml`) for building the site and generating PDFs.
- Draft watermark and redaction mode support.
- Compliance report views for SCF and SOC 2 TSC.
- Nix flake devshell with Zola, Pandoc, XeLaTeX, and Zig toolchain.
- PDF naming convention: `{Title}_-_v{version}.pdf` with Draft/Redacted variants.
