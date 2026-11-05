#!/usr/bin/env bash
# Commit status.json to the `status` branch when it changed, and push. Ordinary commits, never a
# rewrite: the branch grows by a kilobyte or so per update, which a run of hours can afford.
# The site reads it from raw.githubusercontent.com, so no redeploy is involved.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$HOME/legacy-run/status-repo"
if [ ! -d "$repo/.git" ]; then
  git clone -q https://github.com/nuthatch-org/the-legacy-demo.git "$repo"
  cd "$repo"
  if git ls-remote --exit-code --heads origin status >/dev/null; then
    git checkout -q -b status --track origin/status
  else
    git checkout -q --orphan status
    git rm -rq --cached . >/dev/null
    git clean -fdq
  fi
fi
cd "$repo"
git pull -q --ff-only origin status 2>/dev/null || true
python3 "$here/status.py" status.json
git add status.json
# generated_unix changes every run, so compare everything else.
if git diff --cached --quiet -- status.json; then exit 0; fi
if git rev-parse -q --verify HEAD >/dev/null && [ "$(git show HEAD:status.json 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); d.pop("generated_unix"); print(json.dumps(d,sort_keys=True))')" = "$(python3 -c 'import json; d=json.load(open("status.json")); d.pop("generated_unix"); print(json.dumps(d,sort_keys=True))')" ]; then
  # Only the timestamp moved; refresh it at most every ten minutes so the page can tell stale from quiet.
  last=$(git log -1 --format=%ct)
  if [ $(( $(date +%s) - last )) -lt 600 ]; then git reset -q; git checkout -q -- status.json; exit 0; fi
fi
git -c user.name="jimmy" -c user.email="jimmy@localhost" commit -qm "status"
git push -q origin status
