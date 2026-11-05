#!/usr/bin/env python3
"""Compose status.json for the demo site from what is on Jimmy's disk.

Every field comes from a file the Shadow or the gate wrote. Nothing is estimated here except the
offline plan, which is labelled as one. A missing source becomes null, never zero, so the page can
say it was not read.
"""

import json
import os
import subprocess
import sys
import time

HOME = os.path.expanduser("~")
LEGACY = os.path.join(HOME, "the-legacy")
RUN = os.path.join(HOME, "legacy-run")
JOURNAL = os.path.join(RUN, "journal", "1", "002079")
RELIC_DIR = os.path.join(RUN, "relics", "1", "002079")


def read_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def legacy_rev():
    try:
        with open(os.path.join(LEGACY, "REVISION")) as f:
            return f.read().strip()
    except OSError:
        return None


def journal_bytes():
    blocks = os.path.join(JOURNAL, "blocks")
    try:
        names = os.listdir(blocks)
    except OSError:
        return None
    return sum(
        os.path.getsize(os.path.join(blocks, n)) for n in names if n.endswith(".json.zst")
    )


def burrmill():
    """Burrmill's transcript, split per statement, with each result table parsed."""
    try:
        text = open(os.path.join(RUN, "evidence", "burrmill-2079.txt")).read()
    except OSError:
        return None
    out = []
    for chunk in text.split("\n\n-- ")[1:]:
        lines = chunk.splitlines()
        name = os.path.basename(lines[0]).removesuffix(".sql")
        sql, table, status = [], [], None
        for line in lines[1:]:
            if line.startswith("|"):
                table.append([c.strip() for c in line.strip("|").split("|")])
            elif line.startswith("+"):
                continue
            elif line.startswith("-- "):
                status = line[3:]
            elif not table:
                sql.append(line)
        out.append({
            "name": name,
            "sql": "\n".join(sql).strip(),
            "columns": table[0] if table else [],
            "rows": table[1:],
            "status": status,
            "refused": bool(status and status.startswith("refused")),
        })
    return out


def exact(v):
    """Integers as strings: a browser's JSON.parse rounds anything above 2^53, and the cross-check
    sums are 10^23 and up, so a match compared after parsing would prove nothing."""
    if isinstance(v, bool) or v is None:
        return v
    if isinstance(v, int):
        return str(v)
    if isinstance(v, dict):
        return {k: exact(x) for k, x in v.items()}
    if isinstance(v, list):
        return [exact(x) for x in v]
    return v


def main(out):
    status = {
        "generated_unix": int(time.time()),
        "host": "jimmy (ThinkPad P16, Debian 13)",
        "legacy_revision": legacy_rev(),
        "plan": {
            "relic": 2079,
            "start": 17031168,
            "end": 17039359,
            "method_calls": 16386,
            "credits_estimate": 327720,
            "note": "offline estimate from profiles/graphops.toml: 2 calls per block plus 2 probes, 20 credits per call, before retries",
        },
        "progress": read_json(os.path.join(JOURNAL, "progress.json")),
        "provenance": read_json(os.path.join(JOURNAL, "provenance.json")),
        "journal_bytes": journal_bytes(),
        "gate": read_json(os.path.join(RUN, "gate.json")),
        "sealed": read_json(os.path.join(RUN, "sealed-2079.json")),
        "showcase": burrmill(),
        "crosscheck": exact(read_json(os.path.join(RUN, "evidence", "crosscheck.json"))),
        "oracle": read_json(os.path.join(RUN, "oracle-1800.json")),
    }
    tmp = out + ".tmp"
    with open(tmp, "w") as f:
        json.dump(status, f, separators=(",", ":"))
    os.replace(tmp, out)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "status.json")
