# AGENTS.md

NixOS + Home Manager flake for a single host, `poita` (NixOS-WSL), built on flake-parts + ez-configs. `CLAUDE.md` has full operational detail (jfrog-boost bump procedure, upgrade workflow) — this file is the short version.

## Commands

- `just switch` — rebuild and activate (`sudo nixos-rebuild switch --flake .#poita`).
- `just update` — update `flake.lock`.
- `just fmt` / `nix fmt` — treefmt (nixfmt, deadnix, mdformat, just, mdsh).
- No test suite; verification is a successful build/switch.

## Structure

- ez-configs auto-discovers `nixos-configurations/`, `home-configurations/`, `nixos-modules/`, `home-modules/`, `overlays/` — new files there need no wiring; reference shared modules as `ezModules.<name>`.
- `packages/` — custom derivations, exposed through `overlays/default.nix`.
- `lib/` — shared helpers exposed as `systemFlakes`, threaded into all modules via `ezConfigs.globalArgs`.

## Gotchas

- **`nix fmt` has side effects**: `mdsh` executes shell blocks embedded in `README.md` (e.g. `nix-collect-garbage --delete-old`) and rewrites their output in place. Don't run it casually.
- **sudo PATH issue**: if `sudo` fails with "must be owned by uid 0 and have the setuid bit set", PATH resolved the non-setuid `/run/current-system/sw/bin/sudo`. Call `/run/wrappers/bin/sudo` directly instead — never chmod the store copy.
- **`.claude/commands/` and `.opencode/commands/` are Nix-store symlinks** generated from `devenv.nix` (`claude.code.commands`). Edit command bodies in `devenv.nix`; editing the symlinks edits the Nix store.
- **`packages/jfrog-boost/package.nix`** fetches a prebuilt release binary — bumping requires manually updating `version` and `hash` (procedure in `CLAUDE.md`; automated by the `/update-boost` slash command).
- **Evaluating the flake needs the private `nix-secrets` input** (`git+ssh://git@github.com/tarc/nix-secrets.git`). Without SSH access to it, builds/evals fail — don't try to inline or stub secrets.
- Nix style: formatter is `nixfmt` (alejandra disabled); deadnix runs with `no-lambda-arg` and `no-lambda-pattern-names`, so `nix fmt` strips unused lambda args/pattern names.
