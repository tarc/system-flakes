# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A single Nix flake providing NixOS + Home Manager configuration for the host `poita` (a NixOS-WSL instance), built on [`flake-parts`] with [`ez-configs`] wiring up the NixOS/home-manager modules, and Cachix for binary caching.

## Commands

- `just switch` — rebuild and activate the NixOS system (`sudo nixos-rebuild switch --flake .#poita`). Requires sudo.
- `just boot` — same, but only takes effect on next boot.
- `just update` — `nix flake update --flake .` (updates `flake.lock`).
- `just update-held`, `just hold-status` — update everything but nixpkgs, and check a nixpkgs hold (see "Holding nixpkgs" below).
- `just boost-status` — `current` or `stale`: whether the boost integrations match the packaged version.
- `just devenv-pins` — compares the devenv, nix and Ghostty pins with upstream, ending with `status: current` or `status: stale`. `/update-devenv` uses it to skip its sub-commands when nothing moved.
- `just fmt` / `nix fmt` — run `treefmt` (nixfmt, deadnix, mdformat, just, mdsh) over the tree. **Warning:** `mdsh` executes shell commands embedded in `README.md` and rewrites their output in place — running `nix fmt` can trigger real commands (e.g. `nix-collect-garbage`).
- `just` (no args) — lists all recipes.
- `flake-archive | cachix-cache push` — push the current flake inputs' closure to the Cachix cache.

There is no test suite; correctness is checked by `just switch` actually building/activating.

`just` comes from this repo's devenv shell (`devenv.nix`), not the system profile. An interactive shell gets it from the devenv zsh hook, and Claude Code started from such a terminal in the repo inherits that environment (`DEVENV_ROOT` set, `just` on `PATH`), so its Bash tool can run `just switch` directly. If `command -v just` finds nothing (Claude Code started elsewhere, e.g. from another directory or an IDE), run `devenv shell -- just switch` from the repo root instead.

`just switch`, `nix fmt` and `devenv gc --no-tui` routinely take well over 2 minutes (building `devenv`/other packages from source, fetching treefmt tooling, or scanning the store; `devenv gc` has passed the 10-minute foreground limit) — run them in the background from the start rather than waiting on a foreground timeout to force the conversion.

## Architecture

- **`flake.nix`** — the only flake output definition. Delegates host/module wiring to `ez-configs` (`config.ezConfigs`), which auto-discovers configs under `nixos-configurations/`, `home-configurations/`, `nixos-modules/`, `home-modules/`, and `overlays/` by directory convention — new files in those directories are picked up without touching `flake.nix`. Also defines the `treefmt` formatter used by `nix fmt`.
- **`nixos-configurations/poita.nix`** — the one NixOS host. WSL-specific (via `nixos-wsl`), defines the `tarci` user, secrets via `agenix`, and system packages (includes `jfrog-boost`, `claude-code`, `opencode`, etc.).
- **`nixos-modules/`** — shared NixOS modules, auto-imported by `ez-configs`. `default.nix` sets nix settings (substituters, gc, trusted users) and pulls in `ezModules.cache` (custom module in `nixos-modules/cache.nix`) plus repo `overlays/`.
- **`home-configurations/tarci.nix`** — the one home-manager profile. Wires up git, ssh, secrets (`age.secrets`, decrypted from the private `nix-secrets` flake input), shell env vars pulled from agenix-decrypted files at activation time.
- **`home-modules/claude-code.nix`** + **`home-modules/claude/`** — the user's global `~/.claude/CLAUDE.md` and their own skills (`ci-local`, `gh-tracker`, `pr-stack`, `wsl-keep-awake`, `wsl-windows-rust`). Linked with `config.lib.file.mkOutOfStoreSymlink` into *this working copy*, not the store, because they are edited at runtime (`notes.json`, `stack.json`, `CLAUDE.md`): edits land as uncommitted changes here, links break if the checkout moves from `~/projects/system-flakes`, and a NixOS rollback does not restore their content (git does). Deliberately unmanaged: `settings.json` (Claude Code writes it), `rules/` (`boost init` writes it), `scripts/`, `gsd-core/` and `gsd-*` skills (GSD installer), `synced/`, and runtime state. `programs.claude-code` is not used, to avoid a second `claude-code` package and a read-only `settings.json`. `home-modules/claude/**` is excluded from `treefmt` in `flake.nix`: `mdformat` rewrites `SKILL.md` YAML frontmatter into thematic breaks, which breaks the live skills immediately.
- **`home-modules/`** — shared home-manager modules (bat, clipboard, direnv, weechat, zsh, etc.), auto-imported.
- **`overlays/`** — package overrides/additions, applied both to the system (`overlays/default.nix`) and, redundantly, inside `flake.nix`'s `perSystem.pkgs` for `mdsh`. Notable: `jfrog-boost` and `devenv` are packaged from `packages/` and exposed as overlay outputs; `mdsh` is overridden to a fork (`tarc/mdsh`) pinned by rev; `libghostty-vt` is overridden to build from the `ghostty` flake input (see below) instead of nixpkgs. `overlays/default.nix` receives `inputs` (in addition to `pkgs`/`systemFlakes`) via `ezConfigs.globalArgs`, so an overlay there can reference flake inputs directly — most standalone files under `overlays/` ignore it (`{ ... }:`) since they don't need it.
- **`packages/`** — custom package derivations not in nixpkgs: `jfrog-boost` (fetches a prebuilt release binary — version/hash must be bumped manually, see below), `devpod`/`devpod-desktop` (patched via files in that dir), `devenv`.
- **`lib/`** — small shared helpers exposed as `systemFlakes` (`flake.lib.systemFlakes`), threaded into all modules via `ezConfigs.globalArgs`. `lib/constants.nix` holds cross-cutting constants; `maintainers/maintainer-list.nix` holds the nixpkgs-style maintainer entries referenced from package `meta.maintainers`.
- **`devenv.nix`** — devenv-based dev shell for *this repo* (not the built system). Defines the custom slash commands (`/upgrade-all-then-push`, `/upgrade-system`, `/update-devenv`, `/update-boost`, ...; `opencode.commands` reuses `claude.code.commands` whole, so a new command reaches both runtimes, symlinked into `.claude/commands/` and `.opencode/commands/` at shell entry) and Claude Code's own permission rules for this repo — edit the command bodies here, not in `.claude/commands/`, which are generated symlinks.

## Recomputing fetcher hashes

@NIX-HASH-RECIPES.md documents the recipe for recomputing a fetcher's content hash (`hash`, `cargoHash`, ...) whenever its identity attribute (`rev`, `url`, `version`) changes — used by the `update-boost`, `update-devenv-version`, `update-devenv-nix`, `update-devenv`, and `rebase-devenv-branch` custom commands defined in `devenv.nix`.

## Updating `jfrog-boost`

`packages/jfrog-boost/package.nix` fetches a prebuilt GitHub release tarball, so version bumps aren't automatic:

1. Check the latest release: `curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/jfrog/boost/releases/latest" | sed 's#.*/tag/##'`.
1. If newer than `version` in the package, `wget` the matching `boost-<os>-<arch>.tar.gz` asset and hash it with `nix hash file`.
1. Update `version` and `hash` in the derivation.

This is exactly what the `/update-boost` slash command automates, and `/upgrade-system` chains it with `just update` → `just switch` → (`boost init` if `just boost-status` prints `stale`) → `/gc` (`devenv gc`, then `nix fmt` on `README.md`) → commit. `/upgrade-all-then-push` runs `/update-devenv`, then `/upgrade-system`, then pushes.

## Holding nixpkgs

A nixpkgs channel sometimes ships a package with a stale fixed-output hash, which fails `just switch` on something this repo doesn't own. `/upgrade-system` handles that on its own, in both directions:

- **Hold:** when a switch fails with a hash mismatch whose `specified:` hash isn't in this repo, it keeps nixpkgs at the revision committed in `flake.lock`, updates every other input (`just update-held`), writes `nixpkgs-hold.json` and carries on. Any other failure still stops the run.
- **Release:** every run still starts with a full `just update`. `just hold-status` evaluates the hold's `attr` under the new lock, without building anything. It prints `held` while the hash is still `stale`. Once it prints `released`, the run tries the new nixpkgs, and removes the file if the switch succeeds. If a different stale hash fails that switch, the hold is rewritten and keeps its `since`.

Each run reports a new, continuing or released hold at the end, and records it in the commit body. `git log -- nixpkgs-hold.json` is the full history.

`nixpkgs-hold.json` exists only during a hold:

```json
{
  "rev": "<nixpkgs-unstable revision committed in HEAD's flake.lock, the one being held>",
  "since": "<date the hold started, YYYY-MM-DD>",
  "attr": "<attribute of the failing derivation under pkgs, such as opencode.node_modules>",
  "stale": "<the specified: hash from the failure>",
  "got": "<the got: hash from the failure>",
  "note": "<what failed, and the upstream fix if known>"
}
```

## Keeping `libghostty-vt` in sync with devenv

`packages/devenv/package.nix` builds `devenv` with Cargo's `pkg-config` feature for its native VT library, `libghostty-vt`, rather than building it from source. That means the actual native library linked in is whatever `pkgs.libghostty-vt` resolves to — and nixpkgs' own `libghostty-vt` package lags devenv's `Cargo.lock` badly (the library is pre-1.0 with no ABI stability, and devenv bumps it often).

A mismatched revision **builds successfully** but crashes devenv's interactive shell at runtime instead of failing to compile (observed: `Shell session error / terminal error during VT creation (WxH): invalid value`, with the terminal size itself perfectly valid) — there's no automatic signal that the versions have drifted, so this is easy to reintroduce.

**Verifying a fix/removal of this override requires an actual interactive shell session** (e.g. `cd` into a directory that auto-activates `devenv` via direnv, in a real terminal) — a non-interactive smoke test like `devenv shell -- echo ok` does **not** reproduce the crash, because it never allocates a real interactive VT the way an attached terminal does. This was tried once (removing the override on the theory nixpkgs had caught up, "verified" with `devenv shell -- echo ...`) and shipped a broken interactive shell to production before being caught and reverted — a clean `just switch` plus a non-interactive smoke test are both necessary but not sufficient here.

`overlays/default.nix` works around this by overriding `libghostty-vt` to build from the `ghostty` flake input instead of nixpkgs, pinned to the exact commit devenv's `Cargo.lock` requires. When bumping `packages/devenv/package.nix` to a newer devenv revision:

1. Check whether the required commit moved: either the `GHOSTTY_COMMIT` constant in `crates/libghostty-vt-sys/build.rs` of the `libghostty-rs` repo devenv vendors, or more directly devenv's own `flake.nix`, which pins the same `ghostty` input for the same reason (see its comment there: "Keep this in sync with the Ghostty revision pinned by libghostty-rs").
1. If it moved, update the `ghostty` input's URL in this repo's `flake.nix` to match, before running `just update`.

The `/sync-devenv-ghostty` command does both steps, reading the pin from the exact devenv commit `src` builds (the fork's commit when `src` is overridden), and `/update-devenv` runs it before switching whenever `just devenv-pins` reports that something moved. It still can't check the interactive shell for you.

## Known environment gotcha: sudo via PATH

`sudo` (e.g. via `just switch` → `nixos-rebuild switch`) can intermittently fail with:

```
sudo: /run/current-system/sw/bin/sudo must be owned by uid 0 and have the setuid bit set
```

This is not a broken system — it's a `PATH` ordering issue. NixOS ships two `sudo` binaries:

- `/run/current-system/sw/bin/sudo` — a plain, non-setuid copy (not runnable as-is)
- `/run/wrappers/bin/sudo` — the real one, setuid root, meant to actually be used

If `/run/current-system/sw/bin` comes before `/run/wrappers/bin` in `PATH`, plain `sudo` resolves to the non-setuid copy and refuses to run (sudo checks that its own binary is setuid root before doing anything). This ordering isn't stable across shell sessions — plain `just switch` sometimes succeeds outright — so try it as-is first rather than pre-emptively reaching for the workaround below.

Fix: call the wrapper directly instead of relying on `PATH`, e.g.:

```
/run/wrappers/bin/sudo nixos-rebuild switch --flake .#poita --show-trace
```

Do not attempt to fix this by changing permissions/ownership on `/run/current-system/sw/bin/sudo` or `/nix/store/*/bin/sudo` — that binary is intentionally non-setuid; the setuid wrapper is what to use instead.

[`ez-configs`]: https://github.com/ehllie/ez-configs
[`flake-parts`]: https://flake.parts
