#!/usr/bin/env bash
# RFC-0004 M2: relic 1800 sealed from era1 and from RPC must agree on every table's content_hash.
# The RPC side derives pre-merge total difficulty from a base, because GraphOps serves none; the
# base (TD of block 14,745,599) was read from the era1 relic's first header, and is the one value
# the RPC side did not get for itself.
set -euo pipefail
run="$HOME/legacy-run"
journal="$run/journal/1/001800"
era1="$run/relics/1/001800-era1"
rpc="$run/relics/1/001800-rpc"
legacy="$HOME/the-legacy"
base="0xa47b8a71e94dc3b6419"

until python3 -c "import json,sys; sys.exit(json.load(open('$journal/progress.json'))['state'] != 'journaled')" 2>/dev/null; do
  sleep 20
done
set -a; . "$HOME/.config/nightswatch/the-legacy.env"; set +a
cd "$legacy"
rm -rf "$rpc"
"$legacy/target/release/shadow" seal --source rpc --detached \
  --from 14745600 --to 14753791 --chain-id 1 \
  --endpoint https://rpc.graphops.xyz/v1/evm/1 --profile profiles/graphops.toml \
  --journal "$journal" --out "$rpc" --budget-requests 100 \
  --total-difficulty-base "$base" > "$run/seal-1800-rpc.txt" 2>&1
"$legacy/target/release/solo" clean --files "$era1/manifest.json" > "$run/clean-1800-era1.txt" 2>&1 || true
"$legacy/target/release/solo" clean --files "$rpc/manifest.json" > "$run/clean-1800-rpc.txt" 2>&1 || true

python3 - "$era1" "$rpc" "$run" "$base" <<'EOF' > "$run/oracle-1800.json"
import json, sys
era1, rpc, run, base = sys.argv[1:]
a = {f["table"]: f for f in json.load(open(f"{era1}/manifest.json"))["files"]}
b = {f["table"]: f for f in json.load(open(f"{rpc}/manifest.json"))["files"]}
tables = []
for t in ["headers", "transactions", "receipts", "logs", "withdrawals"]:
    if t not in a and t not in b:
        continue
    ea, rb = a.get(t), b.get(t)
    tables.append({
        "table": t,
        "era1_content_hash": ea and ea["content_hash"],
        "rpc_content_hash": rb and rb["content_hash"],
        "era1_rows": ea and ea["row_count"],
        "rpc_rows": rb and rb["row_count"],
        "equal": bool(ea and rb and ea["content_hash"] == rb["content_hash"]),
    })
print(json.dumps({
    "relic": 1800,
    "block_range": {"start": 14745600, "end": 14753791},
    "total_difficulty_base": base,
    "total_difficulty_base_source": "era1 relic 1800 first header: total_difficulty minus difficulty",
    "tables": tables,
    "all_equal": all(t["equal"] for t in tables),
    "clean_era1": open(f"{run}/clean-1800-era1.txt").read().rstrip().splitlines(),
    "clean_rpc": open(f"{run}/clean-1800-rpc.txt").read().rstrip().splitlines(),
    "seal_rpc": open(f"{run}/seal-1800-rpc.txt").read().rstrip().splitlines(),
}, indent=1))
EOF
bash "$HOME/the-legacy-demo/jimmy/publish.sh"
