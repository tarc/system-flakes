# Nix fetcher hash recipes

Whenever a Nix fetcher call's *identity* attribute changes (`rev`, `url`, or the `version` driving either), any co-located content hash (`hash`, `narHash`, `cargoHash`, `cargoSha256`, `npmDepsHash`, `vendorHash`, ...) is now stale and must be recomputed. It's a fixed-output-derivation (FOD) commitment, not a cache key that self-invalidates.

A stale hash doesn't always fail loudly: Nix's FOD caching is keyed by the *declared hash string*, not by the transitive inputs that produced it. If the hash string happens to be unchanged, Nix may silently substitute an unrelated previously-built store path instead of erroring immediately — see the `cargoHash` section below for a case where this actually happened.

This file is imported by `CLAUDE.md`, so it's loaded into context before any custom command in `devenv.nix` runs. The commands reference it instead of re-explaining this mechanism inline each time.

## `fetchFromGitHub` — `rev` → `hash`

```
nix flake metadata "github:<owner>/<repo>/<rev>" --json | jq -r '.locked.narHash'
```

Used by: `update-devenv-version`, `update-devenv-nix`, `rebase-devenv-branch` (via `packages/devenv/package.nix`'s `src`/`devenvNixSrc`), the `mdsh` overlay.

Querying a bare `github:<owner>/<repo>` (no `/<rev>`) instead resolves to the repo's **default branch HEAD at the time of the query** — useful when intentionally tracking a rolling branch rather than pinning to a specific commit (e.g. `update-devenv-version`'s and `update-devenv-nix`'s cachix/devenv main-branch tracking), but it's a moving target: two separate invocations, even seconds apart, can resolve to different commits if upstream gets a new commit in between.

## `fetchurl` — `url` (or the `version` inside it) → `hash`

```
wget -O /tmp/<name>   '<url>'   # -O forces overwrite; plain wget appends .1/.2 to a stale file instead
nix hash file /tmp/<name>
rm -f /tmp/<name>
```

Used by: `update-boost` (`packages/jfrog-boost/package.nix`).

The explicit-overwrite step matters: hashing a stale leftover download from a previous run (instead of the just-fetched one) produces a hash for the *wrong* content, and nothing reliably catches it at hash-compute time — the build will fail later with a hash mismatch, or worse, quietly succeed if the stale file happens to be a still-valid-but-outdated release (this happened for real: jfrog-boost v0.12.5, fixed forward in commit `ea27548`).

## `rustPlatform.buildRustPackage` — `src` → `cargoHash`

Whenever `src` changes for a Rust package pinned via `cargoHash` (or `cargoSha256`, or a `fetchCargoVendor`-computed hash like the `mdsh` overlay's `versionCargoHash`), the vendored-dependencies hash is very likely stale too, since it's derived from `src`'s `Cargo.lock` content:

```
cargoHash = "";   # temporarily
just switch        # or whatever triggers the build
```

The resulting failure reports the correct hash in one of two shapes:

- **Classic FOD mismatch**: `hash mismatch in fixed-output derivation ...: specified: sha256-... / got: sha256-...` — copy the `got:` value directly.
- **rustPlatform's own consistency check**: `ERROR: cargoHash or cargoSha256 is out of date` / `Cargo.lock is not the same in .../vendor` — this does **not** hand you a ready value; you still have to go through the empty-`cargoHash`-then-rebuild cycle above to get one. This shape can appear even when `cargoHash` was already a real (but stale) value, precisely because of the FOD-caching-by-hash-string behavior noted at the top of this file — Nix reused a cached vendor derivation from a previous `src` instead of re-fetching and immediately catching the mismatch.

Used by: `update-devenv` (`packages/devenv/package.nix`'s `cargoHash`), the `mdsh` overlay's `versionCargoHash`.
