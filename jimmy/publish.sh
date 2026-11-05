#!/usr/bin/env bash
# Push status.json to the `status` branch as a single commit, replaced each time, so the branch
# never grows and the site reads it from raw.githubusercontent.com without a redeploy.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$HOME/legacy-run/status-repo"
if [ ! -d "$repo/.git" ]; then
  git clone -q https://github.com/nuthatch-org/the-legacy-demo.git "$repo"
fi
cd "$repo"
git checkout -q --orphan next
git rm -rq --cached . 2>/dev/null || true
find . -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
python3 "$here/status.py" status.json
git add status.json
git -c user.name="jimmy" -c user.email="jimmy@localhost" commit -qm "status"
git push -qf origin next:status
git checkout -q --detach
git branch -qD next
