// Run axe-core (vendored, MIT) against a running site over the DevTools
// Protocol — no npm, no puppeteer. Node 24 has global fetch + WebSocket.
//
// Requires a Chromium listening on --remote-debugging-port=9222 and the site
// served at <baseUrl>. Scans each PAGES entry in both colour schemes and exits
// non-zero if any WCAG A/AA violation is found. Driven by tests/a11y/scan.sh.
//
// usage: node run-axe.mjs <baseUrl>

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const baseUrl = (process.argv[2] || "http://127.0.0.1:1200").replace(/\/$/, "");
const here = dirname(fileURLToPath(import.meta.url));
const axeSrc = readFileSync(join(here, "axe.min.js"), "utf8");

// One representative page per template. The example security policy is the
// densest page (every shortcode, diagram, table, redaction) — the key target.
const PAGES = [
  "/",
  "/policies/",
  "/policies/example-security-policy/",
  "/reports/scf/",
  "/reports/soc2/",
  "/reports/assurance/",
  "/guides/",
  "/guides/installation/",
  "/team/",
  "/news/",
];
const MODES = ["light", "dark"];

const cdpBase = "http://127.0.0.1:9222";

async function connect() {
  const ver = await (await fetch(`${cdpBase}/json/version`)).json();
  const ws = new WebSocket(ver.webSocketDebuggerUrl);
  let id = 0;
  const pending = new Map();
  ws.addEventListener("message", (e) => {
    const m = JSON.parse(e.data);
    if (m.id && pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
  });
  await new Promise((r) => ws.addEventListener("open", r));
  const send = (method, params = {}, sessionId) =>
    new Promise((res) => { const mid = ++id; pending.set(mid, res); ws.send(JSON.stringify({ id: mid, method, params, sessionId })); });
  return { ws, send };
}

const RUN =
  axeSrc +
  "\n;axe.run(document, {resultTypes:['violations'], runOnly:{type:'tag', values:['wcag2a','wcag2aa','wcag21a','wcag21aa','wcag22aa','best-practice']}})" +
  ".then(r => JSON.stringify(r.violations.map(v => ({id:v.id, impact:v.impact, help:v.help, nodes:v.nodes.map(n=>n.target.join(' '))}))))";

async function scan(send, url, mode) {
  const { result: t } = await send("Target.createTarget", { url: "about:blank" });
  const { result: a } = await send("Target.attachToTarget", { targetId: t.targetId, flatten: true });
  const sid = a.sessionId;
  const S = (m, p) => send(m, p, sid);
  await S("Page.enable");
  await S("Emulation.setEmulatedMedia", { media: "screen", features: [{ name: "prefers-color-scheme", value: mode }] });
  await S("Page.navigate", { url });
  await new Promise((r) => setTimeout(r, 1200));
  const res = (await S("Runtime.evaluate", { expression: RUN, awaitPromise: true, returnByValue: true })).result;
  await send("Target.closeTarget", { targetId: t.targetId });
  if (res.exceptionDetails || res.result.value == null) throw new Error("axe eval failed for " + url + " (" + mode + ")");
  return JSON.parse(res.result.value);
}

const { ws, send } = await connect();
let total = 0;
const results = [];
for (const path of PAGES) {
  for (const mode of MODES) {
    let violations;
    try {
      violations = await scan(send, baseUrl + path, mode);
    } catch (e) {
      console.error(`ERROR  ${path} (${mode}): ${e.message}`);
      total += 1;
      results.push({ page: path, mode, error: e.message, violations: null });
      continue;
    }
    results.push({ page: path, mode, violations });
    if (violations.length === 0) {
      console.log(`ok     ${path} (${mode})`);
    } else {
      for (const v of violations) {
        console.log(`FAIL   ${path} (${mode}): ${v.id} [${v.impact}] ${v.nodes.length}× — ${v.help}`);
        for (const n of v.nodes.slice(0, 5)) console.log(`         ${n}`);
      }
      total += violations.length;
    }
  }
}
ws.close();

// Structured evidence: when A11Y_REPORT names a path, write the full results
// there as JSON (consumed by the CI evidence artifact and the demo site's
// assurance page). No behaviour change when unset.
if (process.env.A11Y_REPORT) {
  const { writeFileSync, mkdirSync } = await import("node:fs");
  const { dirname } = await import("node:path");
  mkdirSync(dirname(process.env.A11Y_REPORT), { recursive: true });
  writeFileSync(
    process.env.A11Y_REPORT,
    JSON.stringify(
      {
        tool: "axe-core (vendored)",
        ruleset: "wcag2a, wcag2aa, wcag21a, wcag21aa, wcag22aa, best-practice",
        pages: PAGES.length,
        modes: MODES,
        total_violations: total,
        pass: total === 0,
        results,
      },
      null,
      1,
    ) + "\n",
  );
  console.log(`report: ${process.env.A11Y_REPORT}`);
}

console.log(`\n${total === 0 ? "PASS" : "FAIL"}: ${total} violation type(s) across ${PAGES.length} pages × ${MODES.length} modes.`);
process.exit(total === 0 ? 0 : 1);
