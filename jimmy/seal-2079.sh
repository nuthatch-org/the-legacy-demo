#!/usr/bin/env bash
# Wait for the relic 2079 journal to finish, seal it as a detached pact start (RFC-0001 §8.4.1),
# clean it, and record both for the site. Sealing reads the journal only; the two probes it repeats
# (chain id, finality) are the only network calls.
set -euo pipefail
run="$HOME/legacy-run"
journal="$run/journal/1/002079"
out="$run/relics/1/002079"
legacy="$HOME/the-legacy"

until python3 -c "import json,sys; sys.exit(json.load(open('$journal/progress.json'))['state'] != 'journaled')" 2>/dev/null; do
  sleep 20
done

set -a; . "$HOME/.config/nightswatch/the-legacy.env"; set +a
cd "$legacy"
started=$(date +%s)
"$legacy/target/release/shadow" seal --source rpc --detached \
  --from 17031168 --to 17039359 --chain-id 1 \
  --endpoint https://rpc.graphops.xyz/v1/evm/1 --profile profiles/graphops.toml \
  --journal "$journal" --out "$out" --budget-requests 100 > "$run/seal-2079.txt" 2>&1
sealed=$(date +%s)
"$legacy/target/release/solo" clean --files "$out/manifest.json" > "$run/clean-2079.txt" 2>&1 || true
"$legacy/target/release/solo" clean --files --json "$out/manifest.json" > "$run/clean-2079.json" 2>/dev/null || true
cleaned=$(date +%s)

python3 - "$out" "$run" "$started" "$sealed" "$cleaned" <<'EOF'
import hashlib, json, os, sys
out, run, started, sealed, cleaned = sys.argv[1], sys.argv[2], *map(int, sys.argv[3:])
manifest_path = os.path.join(out, "manifest.json")
raw = open(manifest_path, "rb").read()
manifest = json.loads(raw)
try:
    import blake3  # optional; b3sum is the usual tool
    manifest_b3 = blake3.blake3(raw).hexdigest()
except ImportError:
    import subprocess
    try:
        manifest_b3 = subprocess.run([os.path.expanduser("~/.cargo/bin/b3sum"), "--no-names", manifest_path], capture_output=True, text=True).stdout.strip() or None
    except FileNotFoundError:
        manifest_b3 = None
clean = None
try:
    clean = json.load(open(os.path.join(run, "clean-2079.json")))
except (OSError, ValueError):
    pass
record = {
    "sealed_unix": sealed,
    "seal_seconds": sealed - started,
    "clean_seconds": cleaned - sealed,
    "manifest_blake3": manifest_b3,
    "pact_root": manifest.get("pact_root"),
    "detached_pact_start": manifest.get("detached_pact_start", False),
    "boundary": manifest.get("boundary"),
    "files": manifest.get("files"),
    "seal_transcript": open(os.path.join(run, "seal-2079.txt")).read().rstrip().splitlines(),
    "clean_transcript": open(os.path.join(run, "clean-2079.txt")).read().rstrip().splitlines(),
    "clean_checks": clean.get("checks") if clean else None,
}
json.dump(record, open(os.path.join(run, "sealed-2079.json"), "w"), indent=1)
EOF
bash "$HOME/the-legacy-demo/jimmy/publish.sh"
