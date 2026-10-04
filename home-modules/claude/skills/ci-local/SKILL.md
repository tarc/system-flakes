---
name: ci-local
description: Run a repository's GitHub Actions CI jobs locally before pushing (lint-only jobs fast; tests, builds and Windows on request), and the pre-push hook that runs the fast ones automatically. Use before any push to a PR branch, when the user asks to "run CI locally" or to check a change "like CI would", when checking open PRs at their head commits, and when installing the hook in a repo.
---

# ci-local

`~/.claude/skills/ci-local/ci-local.sh` reads the repo's `.github/workflows/ci.yml` and runs each job's one-line `run:` steps that call `just`, `cargo` or `typos`. It drops a leading `devenv shell -- `, replays `rustup` setup steps, and runs `typos` for the `crate-ci/typos` action. It runs in the repo's dev shell: `devenv shell` when the workflow uses devenv and a `devenv.nix` exists, else `nix develop`.

```sh
ci-local.sh            # --fast: lint-only jobs (all commands are cargo fmt/clippy/check/machete, typos,
                       #   or just fmt-check/clippy/msrv-check/...), run on Linux even if CI uses macOS/Windows
ci-local.sh --full     # + tests/builds on Linux, Windows jobs natively (wsl-windows-rust), macOS lint jobs
                       #   on Linux, other macOS jobs skipped, matrix jobs' Linux entry only
ci-local.sh --jobs fmt,clippy,test-linux
ci-local.sh --list [--full]   # plan: where each job runs, CI runner, toolchain, commands
```

It matches CI where that matters:
- **Toolchain:** a job's `setup-rust-toolchain` `toolchain:` input, or "stable" resolved to the current stable version, installed side by side (`rustup toolchain install 1.99 …` plus clippy and rustfmt), never by updating the user's `stable`. Jobs without that action (devenv-provided Rust, as in factorseal) use the dev shell's toolchain.
- **RUSTFLAGS:** jobs using `actions-rust-lang/setup-rust-toolchain` get `RUSTFLAGS="-D warnings"`, that action's default.
- **Builds** go to `target/ci-local`, or `CI_LOCAL_TARGET` to share one cache across worktrees.
- **Missing tools** (`typos`, `cargo-<sub>`) are borrowed with `nix shell nixpkgs#<tool>`, which leaves no GC root.
- **Skipped steps:** multi-line `run:` scripts (apt-get, plumbing such as `$GITHUB_ENV` writers and custom check scripts), `cargo install` steps, and jobs whose commands use `${{ }}`. Jobs whose commands already ran in the same pass are reported as `same`.

Results print as a table, with logs in `~/.cache/ci-local/<repo>/<job>.log` (or `CI_LOCAL_LOGS`). The script exits non-zero if any job failed.

## Checking open PRs at their heads

`~/.claude/skills/ci-local/run-prs.sh` (edit its `run` lines) fetches `pull/N/head` into `refs/ci-local/pr-N`, makes a temporary worktree under `~/.cache/ci-local/wt/`, runs `--fast` with the repo's shared `target/ci-local`, and removes the worktree. The summary goes to `~/.cache/ci-local/run-prs-summary.txt`.

## pre-push hook

`~/.claude/skills/ci-local/pre-push`, installed as a copy into `<repo>/.git/hooks/pre-push`. It runs `--fast` on every push and refuses while tracked files have uncommitted changes. Skip it with `git push --no-verify` or `CI_LOCAL_SKIP=1`. Installed in `~/projects/gpui-ce` (2026-10-02). It was validated by running it against bc98cbf, the commit CI's fmt rejected: it fails the same way, on `profiler.rs:757`.

## Known local-vs-CI differences

- gpui-ce: the `gpui_ce_wgpu --lib` test binary segfaults (SIGSEGV, GPU driver stack) on this machine but passes in CI's test-linux. When the change doesn't touch `crates/gpui_wgpu`, treat it as local and run `just test-doc` separately, since the failure stops the recipe chain before doc tests.
- gpui-component: `lint` (macOS in CI) can't build the webview crate on Linux without WebKitGTK, which the flake shell lacks. `no-default-features` and `gpui-shell-core` reference packages renamed or removed in #4, so they fail in CI too (as of 2026-10-02). `cargo machete` flags `syntect` unused in crates/base on main.
- macOS can't run here. Say so.

## Footprint

`target/ci-local` inside each repo, `~/.cache/ci-local/` (logs, driver, temporary worktrees), `refs/ci-local/*` refs, and side-by-side rustup toolchains. Record new ones in `~/.claude/footprint.md`.
