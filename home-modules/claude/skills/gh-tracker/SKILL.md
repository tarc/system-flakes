---
name: gh-tracker
description: Refresh or extend the "Upstream Watch" dashboard (claude.ai artifact) that tracks the user's GitHub PRs, issues and unpushed branches across gpui-ce, gpui-component and factorseal. Use when the user asks to refresh/update/sync the dashboard, add a repo, add a note to an item, or track a local branch.
---

# Upstream Watch dashboard

- Artifact: https://claude.ai/artifact/TcA11ww1mXhqBMyEg6LRwG. The page source lives in the artifact itself; read it with `Artifact` `action: "read"` before republishing.
- The page is read-only. It renders the artifact's `db`: collection `items` (one doc per PR, issue or branch) and doc `meta/sync`. Access rules: everyone with access reads, only `admin` (the owner) writes, so all writes come from Claude.
- The page can't reach GitHub itself (CSP), so data only changes when this skill runs.

## Refresh

1. Run `~/.claude/skills/gh-tracker/sync.sh <out-dir>`, with the out-dir in the scratchpad (or `~/.cache/gh-tracker/out`). It needs a non-empty `$GITHUB_TOKEN` (if it's empty, stop and tell the user rather than syncing stale data) and borrows `node` via `nix shell`. It searches every repo in `repos.txt` for items involving `TRACK_USER` (default `tarc`) updated in the last 60 days (`TRACK_SINCE` overrides). It writes `<out>/items/<id>.json` and `<out>/meta/sync.json`.
2. `ArtifactData` `list` on `items` to get the current doc ids and versions.
3. One `ArtifactData` `batch` (max 50 writes; split if needed): `set` each generated item with `file_path`, `set` `meta/sync`, and `delete` docs whose id is no longer generated (an item that aged out of the window, or a local branch removed from notes.json).
4. Tell the user what changed: new items, state changes (merged or closed), and which items are now "your move".

## Config (next to this file)

- `repos.txt`: tracked repos.
- `notes.json`: `"owner/repo#N": {"note", "related": [...]}` adds context the API lacks. `"local": [...]` lists branches without a PR (`id`, `repo`, `branch`, `title`, `note`, `related`, `updated`). When such a branch gets its PR, remove the local entry. The next sync then deletes its doc.
- Keep notes current: when an item's situation changes (a reviewer asks for something, a dependency merges), update its note before syncing.

## Derived fields

- `waiting`: `done` (merged or closed), `you` (the last human comment or review on an open item is someone else's, on an item you authored or took part in, or CI fails on your PR), otherwise `them`.
- `ci_awaiting_approval`: true when a workflow run on the PR's head commit has conclusion `action_required` (fork PRs wait for a maintainer to approve them). The page shows "CI awaiting approval".

## Footprint

`sync.sh` borrows `node` with `nix shell nixpkgs#nodejs`, which leaves no GC root. (It used an ad-hoc devenv shell until 2026-10-02; that failed where `/run/user` was not writable.) Its output goes to `~/.cache/gh-tracker/out` when no scratchpad is available.

## Schedule

Automatic refresh is a session-only Claude Code cron job: weekdays at 09:04 UTC, created with CronCreate. It's set in the session that created it, lasts at most 7 days, and is gone when that session exits. The page footer says this. Re-arm it with CronCreate (`4 9 * * 1-5`) in a new long-running session if the user wants it. A cloud routine was considered and rejected: the script, the notes, `$GITHUB_TOKEN` and ArtifactData are all local.
