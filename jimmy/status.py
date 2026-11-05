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
    }
    tmp = out + ".tmp"
    with open(tmp, "w") as f:
        json.dump(status, f, separators=(",", ":"))
    os.replace(tmp, out)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "status.json")
