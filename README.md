# the-legacy-demo

A live status page for The Legacy's archive-RPC Shadow, sealing mainnet relic 2079 on Jimmy.

- `index.html` is the whole site: static, no build, fonts self-hosted.
- It reads `status.json` from the `status` branch, which Jimmy force-pushes as a single commit.
- `jimmy/gate.py` runs the RFC-0004 M1 fixture gate and records its transcripts verbatim.
- `jimmy/status.py` composes `status.json` from the journal's `progress.json` and `provenance.json`.
- `jimmy/publish.sh` pushes it.

`node check-nav.mjs` checks the sidebar and the mobile nav list the same sections.
