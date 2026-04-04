# Contributing to PolicyPress

Thank you for taking the time to contribute to PolicyPress. This project is maintained by Star City Security Consulting (SC2, [https://sc2.in](https://sc2.in)) and prefers minimal process, high quality, and secure design.

## Get started

1. Fork the repository.
2. Create a feature branch: `git checkout -b fix/whatever`
3. Build and test locally:

```bash
nix develop
zig build test
zola build   # verify template/theme changes render correctly
```

4. Commit with a clear message and include an issue reference (if any):

- `feat: add ...`
- `fix: correct ...`
- `docs: update ...`

5. Open a pull request from your branch to `main`.

## Development workflow

- Keep PRs focused and small.
- Rebase or merge `main` before final review.
- Include test coverage or update tests for behavior changes.
- Use existing style in Zig code and no trailing whitespace.
- Template (HTML/Sass) changes should be verified against the example content site.
- AI-assisted contributions are allowed, but every AI-generated suggestion must be reviewed and approved by a human maintainer before merge. No slop: the final code must be correct, secure, and idiomatic, with all edge cases covered.

## Testing

- Core test suite: `zig build test`
- Site build: `zola build` (must complete without errors or warnings)
- PDF generation: `policypress -c config.toml -o public` against the example content

## Issues

- Use GitHub issues for bug reports and enhancement ideas.
- For bugs, provide a minimal reproduction case and expected vs actual behavior.
- For PDF or rendering issues, include the relevant front matter and content snippet.

## SC2 ideals

- Security: PolicyPress processes user-supplied Markdown that may end up in PDFs or HTML — avoid introducing injection or path traversal vectors.
- Reliability: prefer stable, well-tested APIs.
- Simplicity: avoid overengineering; keep the action interface and config surface lean.

## Release notes

Follow `CHANGELOG.md` conventions; record notable changes at the corresponding version section. A maintainer may adapt as needed.
