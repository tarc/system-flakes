---
name: pr-stack
description: Refresh or update the "WSL2 PR Stack" dashboard (claude.ai artifact) that tracks the stacked pull requests split out of factorseal's feature/wsl2-interop-broker branch into cachix/factorseal. Use when the user asks to refresh/update/sync that dashboard, records a PR number for a stacked branch, or when local check results for the stack change.
---

# WSL2 PR Stack dashboard

- Artifact: https://claude.ai/artifact/STZTQMiJoKeCMPEvPcFqWa. Read-only page that renders its `db`: collection `prs` (one doc per PR, keyed `umbrella`, `1`-`8`, `spikes`) and doc `meta/sync`. Everyone with access reads; only `admin` (the owner) writes, so all writes come from Claude. The page can't reach GitHub (CSP).
- Config: `stack.json` next to this file: each PR's branch, the branch it is stacked on (`on`), title, note, `number` (null until opened), and `checks` (`{"<key>": [{"name", "result": "pass|fail|pending", "detail", "at"}]}`) for local test results the API doesn't know. Keep notes and checks current before syncing.

## Refresh

1. `python3 ~/.claude/skills/pr-stack/sync.py <out-dir>` (out-dir in the scratchpad). Needs `$GITHUB_TOKEN`. Reads the local branches in the factorseal checkout (git only, no checkout switching) and, for PRs with a number, the GitHub REST API. Writes `<out>/prs/<key>.json` and `<out>/meta/sync.json`.
2. One `ArtifactData` `batch`: `set` each file with `file_path`, plus `meta/sync`. Delete docs for keys removed from `stack.json`.
3. Tell the user what changed: PR states, reviews, CI, whether upstream main moved (the page warns when it has, since the stack then needs a rebase).

Runs no devenv shell, so it leaves no Nix GC root.
