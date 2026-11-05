#!/usr/bin/env python3
"""Run the RFC-0004 M1 gate on Jimmy and record exactly what it printed.

Two transcripts: the Shadow's fixture tests, and `solo clean --files` over the fixture relic those
tests sealed. Both are kept verbatim so the site shows output, not a summary of it.
"""

import glob
import json
import os
import re
import subprocess
import time

HOME = os.path.expanduser("~")
LEGACY = os.path.join(HOME, "the-legacy")
CARGO = os.path.join(HOME, ".cargo", "bin", "cargo")
OUT = os.path.join(HOME, "legacy-run", "gate.json")


def run(args, **kw):
    started = time.time()
    p = subprocess.run(args, cwd=LEGACY, capture_output=True, text=True, **kw)
    return p.returncode, p.stdout + p.stderr, round(time.time() - started, 2)


def main():
    code, out, secs = run([CARGO, "test", "--release", "-p", "shadow", "--", "--test-threads=8"])
    tests = [
        {"name": m.group(1), "result": m.group(2)}
        for m in re.finditer(r"^test (\S+) \.\.\. (ok|FAILED|ignored)$", out, re.M)
    ]
    summary = re.findall(r"^test result: .*$", out, re.M)

    tmp = os.environ.get("TMPDIR", "/tmp")
    relics = sorted(glob.glob(os.path.join(tmp, "shadow-rpc-full-*")), key=os.path.getmtime)
    clean = None
    if relics:
        d = relics[-1]
        ccode, cout, csecs = run(
            [CARGO, "run", "--release", "-q", "-p", "solo", "--", "clean", "--files",
             "--after", os.path.join(d, "002078.json"), os.path.join(d, "relic", "manifest.json")]
        )
        # The temp path is local noise; the reader needs the relic, not the directory.
        cout = cout.replace(d, "<fixture>")
        clean = {"exit": ccode, "seconds": csecs, "transcript": cout.rstrip().splitlines()}

    gate = {
        "ran_unix": int(time.time()),
        "tests_exit": code,
        "tests_seconds": secs,
        "tests": tests,
        "summary": summary,
        "clean": clean,
    }
    with open(OUT, "w") as f:
        json.dump(gate, f, indent=1)


if __name__ == "__main__":
    main()
