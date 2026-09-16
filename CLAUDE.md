# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A single Nix flake providing NixOS + Home Manager configuration for the host `poita` (a NixOS-WSL instance), built on [`flake-parts`] with [`ez-configs`] wiring up the NixOS/home-manager modules, and Cachix for binary caching.

## Commands

- `just switch` — rebuild and activate the NixOS system (`sudo nixos-rebuild switch --flake .#poita`). Requires sudo.
- `just boot` — same, but only takes effect on next boot.
- `just update` — `nix flake update --flake .` (updates `flake.lock`).
- `just fmt` / `nix fmt` — run `treefmt` (nixfmt, deadnix, mdformat, just, mdsh) over the tree. **Warning:** `mdsh` executes shell commands embedded in `README.md` and rewrites their output in place — running `nix fmt` can trigger real commands (e.g. `nix-collect-garbage`).
- `just` (no args) — lists all recipes.
- `flake-archive | cachix-cache push` — push the current flake inputs' closure to the Cachix cache.

There is no test suite; correctness is checked by `just switch` actually building/activating.

Both `just switch` and `nix fmt` routinely take well over 2 minutes (building `devenv`/other packages from source, or fetching treefmt tooling) — run them in the background from the start rather than waiting on a foreground timeout to force the conversion.

## Architecture

- **`flake.nix`** — the only flake output definition. Delegates host/module wiring to `ez-configs` (`config.ezConfigs`), which auto-discovers configs under `nixos-configurations/`, `home-configurations/`, `nixos-modules/`, `home-modules/`, and `overlays/` by directory convention — new files in those directories are picked up without touching `flake.nix`. Also defines the `treefmt` formatter used by `nix fmt`.
- **`nixos-configurations/poita.nix`** — the one NixOS host. WSL-specific (via `nixos-wsl`), defines the `tarci` user, secrets via `agenix`, and system packages (includes `jfrog-boost`, `claude-code`, `opencode`, etc.).
- **`nixos-modules/`** — shared NixOS modules, auto-imported by `ez-configs`. `default.nix` sets nix settings (substituters, gc, trusted users) and pulls in `ezModules.cache` (custom module in `nixos-modules/cache.nix`) plus repo `overlays/`.
- **`home-configurations/tarci.nix`** — the one home-manager profile. Wires up git, ssh, secrets (`age.secrets`, decrypted from the private `nix-secrets` flake input), shell env vars pulled from agenix-decrypted files at activation time.
- **`home-modules/`** — shared home-manager modules (bat, clipboard, direnv, weechat, zsh, etc.), auto-imported.
- **`overlays/`** — package overrides/additions, applied both to the system (`overlays/default.nix`) and, redundantly, inside `flake.nix`'s `perSystem.pkgs` for `mdsh`. Notable: `jfrog-boost` and `devenv` are packaged from `packages/` and exposed as overlay outputs; `mdsh` is overridden to a fork (`tarc/mdsh`) pinned by rev. Standalone files under `overlays/` ignore the extra `inputs`/`systemFlakes` args ez-configs passes in (`{ ... }:`) unless they actually need them — see `overlays/default.nix` for an example that does (`systemFlakes`).
- **`packages/`** — custom package derivations not in nixpkgs: `jfrog-boost` (fetches a prebuilt release binary — version/hash must be bumped manually, see below), `devpod`/`devpod-desktop` (patched via files in that dir), `devenv`.
- **`lib/`** — small shared helpers exposed as `systemFlakes` (`flake.lib.systemFlakes`), threaded into all modules via `ezConfigs.globalArgs`. `lib/constants.nix` holds cross-cutting constants; `maintainers/maintainer-list.nix` holds the nixpkgs-style maintainer entries referenced from package `meta.maintainers`.
- **`devenv.nix`** — devenv-based dev shell for *this repo* (not the built system). Defines the Claude Code slash commands `/update-boost` and `/upgrade-system` (symlinked into `.claude/commands/` and `.opencode/commands/` at shell entry) and Claude Code's own permission rules for this repo — edit the command bodies here, not in `.claude/commands/`, which are generated symlinks.

## Recomputing fetcher hashes

@NIX-HASH-RECIPES.md documents the recipe for recomputing a fetcher's content hash (`hash`, `cargoHash`, ...) whenever its identity attribute (`rev`, `url`, `version`) changes — used by the `update-boost`, `update-devenv-version`, `update-devenv-nix`, `update-devenv`, and `rebase-devenv-branch` custom commands defined in `devenv.nix`.

## Updating `jfrog-boost`

`packages/jfrog-boost/package.nix` fetches a prebuilt GitHub release tarball, so version bumps aren't automatic:

1. Check the latest release: `curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/jfrog/boost/releases/latest" | sed 's#.*/tag/##'`.
1. If newer than `version` in the package, `wget` the matching `boost-<os>-<arch>.tar.gz` asset and hash it with `nix hash file`.
1. Update `version` and `hash` in the derivation.

This is exactly what the `/update-boost` slash command automates, and `/upgrade-system` chains it with `just update` → `just switch` → (`boost init` if boost was bumped) → `nix fmt` on `README.md` → commit.

## `libghostty-vt` version tracking (historical)

`packages/devenv/package.nix` builds `devenv`'s native VT library, `libghostty-vt`, via Cargo's `pkg-config` feature rather than from source — so the actual library linked in is whatever `pkgs.libghostty-vt` resolves to. For a while nixpkgs' own `libghostty-vt` lagged devenv's `Cargo.lock` badly enough (the library is pre-1.0, no ABI stability) that a mismatched revision would build successfully but crash devenv's interactive shell at runtime (`Shell session error / terminal error: invalid value`) instead of failing to compile — there was no automatic signal that the versions had drifted.

`overlays/default.nix` used to work around this by overriding `libghostty-vt` to build from a pinned `ghostty` flake input instead of nixpkgs. That override was removed once nixpkgs' `libghostty-vt` caught back up (verified via both `just switch` and an actual `devenv shell` smoke test, not just a successful build — see above for why the build alone doesn't prove it). If this class of crash reappears after a future `update-devenv-version` bump, the fix is to reintroduce the same kind of override, pinned to the exact commit devenv's current `Cargo.lock` requires — see the `libghostty-rs` repo's `GHOSTTY_COMMIT` constant in `crates/libghostty-vt-sys/build.rs`, or devenv's own `flake.nix`, which pins a `ghostty` input for the same reason.

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
