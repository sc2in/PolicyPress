# Web accessibility check

Runs [axe-core](https://github.com/dequelabs/axe-core) (the engine behind most
reputable WCAG scanners) against a representative page of every template, in
both light and dark mode, and fails on any WCAG 2.1/2.2 A or AA violation.

- `axe.min.js` — vendored axe-core (MIT), self-hosted like the rest of the
  site's assets; no npm/CDN dependency.
- `run-axe.mjs` — drives a headless Chromium over the DevTools Protocol
  (Node 24's global `fetch`/`WebSocket`, no puppeteer), injects axe on each
  page, and reports violations. Edit its `PAGES` list to change coverage.
- `scan.sh` — builds/serves the site, launches Chromium, runs the scan.

## Run it locally

From inside the dev shell (`nix develop`), which provides `zola`:

```sh
nix shell nixpkgs#chromium nixpkgs#nodejs --command bash tests/a11y/scan.sh
```

Exit code is non-zero if any page has a violation. It is also wired into CI as
the "Accessibility scan (axe-core)" step in `.github/workflows/ci.yml`.

## Notes

- Automated checks catch a large share of issues but are not a full audit;
  keyboard and screen-reader spot-checks still matter.
- The feature-dense **Example Security Policy** (every shortcode, diagram,
  table, redaction, callout) is the primary target page.
- To update axe-core, replace `axe.min.js` with a newer release from
  <https://github.com/dequelabs/axe-core/releases> (the `axe.min.js` asset).
