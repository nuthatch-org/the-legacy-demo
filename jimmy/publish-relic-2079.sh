#!/usr/bin/env bash
# Publish relic 2079 to R2 under the RFC-0001 §9.1 layout, registry last (RFC-0004 §10), then fetch
# every file back over the public URL and check it against the manifest. Credentials go to curl
# through a 0600 config file, never argv.
set -euo pipefail
relic="$HOME/legacy-run/relics/1/002079"
bucket="nestsss"
public="https://pub-bc282d5016f242a783a6c28cbcd4401a.r2.dev"
prefix="legacy/v1/1/relics/002079"
registry_key="legacy/v1/1/registry.json"
b3="$HOME/.cargo/bin/b3sum"

set -a; . "$HOME/.config/nightswatch/mirror-r2.env"; set +a
cfg="$(mktemp)"; chmod 600 "$cfg"; trap 'rm -f "$cfg"' EXIT
printf 'user = "%s:%s"\naws-sigv4 = "aws:amz:auto:s3"\n' "$AWS_ACCESS_KEY_ID" "$AWS_SECRET_ACCESS_KEY" > "$cfg"
endpoint="${AWS_ENDPOINT_URL%/}"

put() { # key, file, content-type
  curl -sS --fail-with-body -K "$cfg" -X PUT -H "content-type: $3" --upload-file "$2" "$endpoint/$bucket/$1" -o /dev/null
  echo "put $1 ($(stat -c %s "$2") bytes)"
}

python3 - "$relic" "$public" > "$HOME/legacy-run/registry.json" <<'EOF'
import json, sys
relic, public = sys.argv[1], sys.argv[2]
m = json.load(open(f"{relic}/manifest.json"))
reg = {
    "chain_id": m["chain_id"],
    "spec_version": m["spec_version"],
    "head_pact_root": m["pact_root"],
    "head_block": m["block_range"]["end"],
    "relics": [{
        "index": m["block_range"]["start"] >> 13,
        "block_range": m["block_range"],
        "manifest_url": f"{public}/legacy/v1/1/relics/002079/manifest.json",
        "pact_root": m["pact_root"],
    }],
    "mirrors": [{"name": "r2", "base_url": f"{public}/legacy/v1/1", "transport": "https"}],
}
# JCS for this document: sorted keys, no whitespace, ASCII strings, integers only.
sys.stdout.write(json.dumps(reg, sort_keys=True, separators=(",", ":"), ensure_ascii=False))
EOF

for f in headers transactions receipts logs withdrawals; do
  put "$prefix/$f.parquet" "$relic/$f.parquet" application/vnd.apache.parquet
done
put "$prefix/manifest.json" "$relic/manifest.json" application/json
put "$registry_key" "$HOME/legacy-run/registry.json" application/json

# Read back over the public URL, as a stranger would.
check="$(mktemp -d)"; trap 'rm -rf "$check" "$cfg"' EXIT
curl -sS --fail "$public/$prefix/manifest.json" -o "$check/manifest.json"
cmp "$check/manifest.json" "$relic/manifest.json" && echo "manifest.json: identical, b3 $("$b3" --no-names "$check/manifest.json")"
python3 - "$check/manifest.json" <<'EOF' | while read -r name want; do
import json, sys
for f in json.load(open(sys.argv[1]))["files"]:
    print(f["name"], f["blake3"])
EOF
  curl -sS --fail "$public/$prefix/$name" -o "$check/$name"
  got="$("$b3" --no-names "$check/$name")"
  [ "$got" = "$want" ] && echo "$name: blake3 matches the manifest" || { echo "$name: MISMATCH $got"; exit 1; }
done
curl -sS --fail "$public/$registry_key" | cmp - "$HOME/legacy-run/registry.json" && echo "registry.json: identical"
