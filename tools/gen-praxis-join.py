#!/usr/bin/env python3
"""Generate data/praxis-join.json from a praxis flake's control-join output.

Usage:
  gen-praxis-join.py <praxis-flake-ref> [options]
  gen-praxis-join.py --ids-json <FILE|-> [options]

A praxis flake publishes `praxis.joins.policypress` — a flat Nix list of the
bare SCF control ids it actively governs (managed controls plus opt-in
organizational families). This wraps

    nix eval --json <praxis-flake-ref>#praxis.joins.policypress

and emits the committed, provenance-carrying file PolicyPress consumes
(schema policypress/praxis-join/v1, read by src/praxis_join.zig).

praxis is NOT a flake input of PolicyPress (public repo <-> private GRC repo,
and the feature must work for any consumer with their own praxis-like list), so
the freshness check lives consumer-side — regenerate and diff against the
committed file (see content/guides/compliance-frameworks.md).

For offline/CI use without evaluating a flake, pass the id list directly with
--ids-json (a JSON array of strings; "-" reads stdin).

Options:
  --ids-json FILE            Read ids from FILE (a JSON array) instead of running
                             `nix eval`; use "-" to read stdin.
  --rev REV                  source.rev provenance value (default: "unknown").
  --scf-version VERSION      source.scf_version (default: "2026.1.1").
  --organizational-families F[,F...]
                             Families the spine was built from; repeatable and/or
                             comma-separated (default: GOV).
  --generated-at YYYY-MM-DD  Override the generation date (default: today, UTC).
  -o, --output FILE          Output path (default: <repo>/data/praxis-join.json);
                             "-" writes to stdout (for a `| diff -` drift check).

Stdlib only. Deterministic output: ids and families are sorted and deduped, keys
are emitted in a stable order, and there are no incidental timestamps beyond
generated_at, so the committed artifact diffs cleanly.
"""

import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

SCHEMA = "policypress/praxis-join/v1"


def load_ids(args: argparse.Namespace) -> list:
    """Resolve the bare id list from --ids-json or `nix eval`."""
    if args.ids_json is not None:
        raw = sys.stdin.read() if args.ids_json == "-" else Path(args.ids_json).read_text()
    else:
        attr = f"{args.flake}#praxis.joins.policypress"
        raw = subprocess.run(
            ["nix", "eval", "--json", attr],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
    ids = json.loads(raw)
    if not isinstance(ids, list) or not all(isinstance(x, str) for x in ids):
        raise SystemExit("praxis join input must be a JSON array of id strings")
    return ids


def parse_families(values) -> list:
    """Flatten repeated and comma-separated --organizational-families."""
    if not values:
        return ["GOV"]
    out = []
    for chunk in values:
        out.extend(f.strip() for f in chunk.split(",") if f.strip())
    return out or ["GOV"]


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate data/praxis-join.json from a praxis flake ref.",
        add_help=True,
    )
    parser.add_argument("flake", nargs="?", help="praxis flake ref (e.g. github:sc2in/Praxis)")
    parser.add_argument("--ids-json", metavar="FILE", help='read ids from FILE (JSON array); "-" for stdin')
    parser.add_argument("--rev", default="unknown", help="source.rev provenance value")
    parser.add_argument("--scf-version", default="2026.1.1", help="source.scf_version value")
    parser.add_argument(
        "--organizational-families",
        action="append",
        metavar="F[,F...]",
        help="families the spine was built from (repeatable/comma-separated)",
    )
    parser.add_argument("--generated-at", metavar="YYYY-MM-DD", help="override the generation date")
    parser.add_argument("-o", "--output", metavar="FILE", help='output path ("-" for stdout)')
    args = parser.parse_args()

    if args.ids_json is None and args.flake is None:
        parser.error("either a praxis flake ref or --ids-json is required")

    ids = load_ids(args)
    families = parse_families(args.organizational_families)
    generated_at = args.generated_at or datetime.now(timezone.utc).strftime("%Y-%m-%d")

    doc = {
        "schema": SCHEMA,
        "generated_at": generated_at,
        "source": {"rev": args.rev, "scf_version": args.scf_version},
        "organizational_families": sorted(set(families)),
        "ids": sorted(set(ids)),
    }

    rendered = json.dumps(doc, indent=2, ensure_ascii=False) + "\n"

    # `-o -` writes the document to stdout instead of a file, so a consumer can
    # pipe it straight into a drift check (`... -o - | diff - data/praxis-join.json`);
    # the human-readable summary always goes to stderr, keeping stdout clean.
    if args.output == "-":
        sys.stdout.write(rendered)
        out_path = "(stdout)"
    else:
        out_path = (
            Path(args.output)
            if args.output
            else Path(__file__).resolve().parent.parent / "data" / "praxis-join.json"
        )
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(rendered, encoding="utf-8")

    print(
        f"wrote {out_path} — {len(doc['ids'])} ids, families {doc['organizational_families']} "
        f"(rev {args.rev}, SCF {args.scf_version})",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
