{
  config,
  pkgs,
  ...
}:
let
  # claudeAgents = config.claude.code.agents;
  # openCodeModel = "opencode/kimi-k3";
  # claudeCodeModel = "opus";

  # Shared by the command bodies and the permission rules below.
  devenvPackage = "packages/devenv/package.nix";
  boostPackage = "packages/jfrog-boost/package.nix";
  devenvFork = "git@github.com:tarc/devenv.git";
  devenvRebaseDir = "/tmp/devenv-rebase";
in
{
  name = "system-flakes";

  languages = {
    deno.enable = true;

    javascript = {
      enable = true;
      npm.enable = true;
      pnpm.enable = true;
    };
  };

  packages = with pkgs; [
    jq
    just
  ];

  opencode = {
    enable = true;
    inherit (config.claude.code) commands;
  };

  claude.code = {
    enable = true;
    mcpServers = {
      # Local devenv MCP server
      devenv = {
        type = "stdio";
        command = "devenv";
        args = [ "mcp" ];
        env = {
          DEVENV_ROOT = config.devenv.root;
        };
      };
    };
    commands = {
      update-devenv-version = ''
        In @${devenvPackage} bump the version, and update the hash in the `src = fetchFromGitHub` call if necessary.

        1. Check whether `src = fetchFromGitHub` in @${devenvPackage} has `owner = "tarc"` and `repo = "devenv"` — this is an overridden scenario (a fork branch pinned in place of upstream cachix/devenv, typically with a comment above `src` linking to a cachix/devenv PR, and a comment on the `rev` line naming the branch). If it's not overridden (owner/repo are anything else), skip straight to step 7.
        2. In the overridden scenario, look for the branch in ${devenvFork} that `src`'s `rev` belongs to: run `git ls-remote ${devenvFork} | grep <rev>` to find a live branch whose tip is exactly that commit.
        3. If step 2 finds nothing (e.g. the branch was deleted after merging), fall back to the PR referenced in the comment above `src` (e.g. `https://github.com/cachix/devenv/pull/<number>`): run `curl -fsSL "https://api.github.com/repos/cachix/devenv/pulls/<number>" | jq -r '.head.ref, .merged'` to recover the branch name and merge status directly, even though the PR may already be closed.
        4. Decide, based on steps 2-3: the override is FINISHED if the PR is merged (or the branch is gone and the PR shows merged) — go to step 5. Otherwise it's still PENDING — go to step 6.
        5. [FINISHED] Revert the override: set `owner = "cachix"` in @${devenvPackage} and remove the comment block above `src`. Do not commit yet and do not stop — continue to step 7, so the normal flow below still runs this same pass and actually advances `rev`/`hash` to upstream's current HEAD (don't leave `rev` stale at whatever commit the override happened to be pinned to).
        6. [PENDING] Run the custom command `/rebase-devenv-branch <branch>` (the branch name from step 2 or 3) to rebase it onto cachix/devenv's main, then run `git ls-remote ${devenvFork} "refs/heads/<branch-or-its-rebase-devenv-branch--temp-variant>"` to get the new HEAD commit and `nix flake metadata "github:tarc/devenv/<new-rev>" --json | jq '.locked.narHash'` to get its hash. Update `rev`/`hash` in @${devenvPackage} to these new values (`owner`/`repo` stay "tarc"/"devenv"; update the branch-name comment on `rev` too if `rebase-devenv-branch` created a new branch). Commit, then STOP — steps 7-12 below only apply to the non-overridden case and must not run this pass.
        7. Remove any stale `-temp` branches left on ${devenvFork}: run `git ls-remote --heads ${devenvFork} '*-temp'` and delete each match with `git push ${devenvFork} --delete refs/heads/<branch>`. These are always disposable rebase-devenv-branch working copies, so it's safe to remove all of them here — this step only runs in the non-overridden tail (step 1 skipped here, or step 5's revert fell through to here), never during step 6's pending path, so it never touches a branch that's still actively pinned as `src`. This covers both a `-temp` branch left over from the override just reverted in step 5, and any that accumulated during ordinary (never-overridden) runs.
        8. Run `curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/cachix/devenv/releases/latest" | sed 's#.*/tag/v##'` to get the latest released version, used only as a human-readable version label (this does NOT pin `src` — see step 10)
        9. Update the version in @${devenvPackage} (it's in the let binding, the `version` variable) to the latest released version, if necessary
        10. Run `nix flake metadata github:cachix/devenv --json | jq '.locked | .rev, .narHash'` to get, respectively, the latest commit and NAR hash of devenv's default branch — `src` intentionally tracks the rolling main branch, not the release tag from step 8
        11. Use these values to update devenv's rev and hash in the `src = fetchFromGitHub` call of @${devenvPackage}, if necessary
        12. Commit the changes if the version or hash was updated (this includes any revert from step 5)
      '';

      update-devenv-nix = ''
        In @${devenvPackage} update `devenvNixVersion`, `devenvNixRev`, and update the hash in the `devenvNixSrc = fetchFromGitHub` call if necessary.

        1. Run the custom command `/resolve-devenv-ref upstream` to get the reference of the devenv flake to read the pin from. While `src` tracks cachix/devenv, that's the exact commit `src` builds, so a commit pushed upstream after update-devenv-version ran can't leave this pin ahead of `src`. While `src` has a fork override (owner = "tarc"), it's cachix/devenv's main branch: the nix-input pin is intentionally decoupled from the devenv source override, so don't substitute the fork here
        2. Run `nix flake metadata "<ref>" --json | jq '.locks.nodes.nix | .original.ref, .locked.rev, .locked.narHash' | sed 's/devenv-//'` to get, respectively, devenvNixVersion, devenvNixRev and the NAR hash pinned by that devenv commit
        3. Use these values to update `devenvNixVersion` and `devenvNixRev` in @${devenvPackage} (they are let bindings), and the hash in the `devenvNixSrc = fetchFromGitHub` call of @${devenvPackage}, if necessary
        4. Commit the changes if devenvNixVersion, devenvNixRev, or the hash were updated
      '';

      resolve-devenv-ref = ''
        Report the flake reference of the devenv commit that @${devenvPackage} builds. Mode: $0

        1. If no mode was given above, use `src`; if it is neither `src` nor `upstream`, stop and report the error
        2. Read `owner`, `repo` and `rev` from the `src = fetchFromGitHub` call in @${devenvPackage}
        3. Mode `src`: the reference is `github:<owner>/<repo>/<rev>`, the exact commit `src` builds, which is a commit of the fork when `src` is overridden (owner = "tarc", see update-devenv-version). Use it for pins that must match the code being built
        4. Mode `upstream`: when `owner` is `cachix`, the reference is `github:cachix/devenv/<rev>`, the same commit as mode `src`. When `src` is overridden, it is `github:cachix/devenv`, cachix/devenv's main branch at query time, for pins that are intentionally decoupled from a fork override
        5. Report the reference; change nothing and commit nothing
      '';

      sync-devenv-ghostty = ''
        Keep the `ghostty` input in @flake.nix on the Ghostty revision that the devenv commit built by @${devenvPackage} requires (see "Keeping `libghostty-vt` in sync with devenv" in @CLAUDE.md).

        1. Check that `git status --short flake.nix flake.lock` prints nothing; otherwise stop and report, so the commit below holds only the Ghostty pin
        2. Run the custom command `/resolve-devenv-ref src` to get the reference of the exact devenv commit `src` builds. Don't fall back to upstream when `src` is overridden: the fork's Cargo.lock decides which libghostty-vt gets linked
        3. Run `nix flake metadata "<ref>" --json | jq -r '.locks.nodes.ghostty.locked.rev'` to get the Ghostty revision that devenv commit pins. If it prints `null` (that commit has no `ghostty` input), stop and report it instead of guessing a revision
        4. Run `jq -r '.nodes.ghostty.locked.rev' flake.lock` to get the revision this repo pins. If both revisions match, report it and stop
        5. Otherwise set `ghostty.url` in @flake.nix to `github:ghostty-org/ghostty/<revision from step 3>`, run `nix flake update ghostty` to relock only that input, and check that step 4's command now prints the step 3 revision
        6. Commit `flake.nix` and `flake.lock`, staged by explicit path
        7. Report that the Ghostty pin moved, and that after the next switch an interactive devenv shell must be opened in a real terminal: a mismatched revision builds fine and only crashes there, and a non-interactive `devenv shell -- <cmd>` doesn't reproduce it
      '';

      update-devenv = ''
        Update @${devenvPackage} (both version and nix) and try to switch the system. If the switch fails, update `cargoHash` and try again.

        1. Run the custom command `/update-devenv-version` to update @${devenvPackage}
        2. Run the custom command `/update-devenv-nix` to update the nix source in @${devenvPackage}
        3. Run the custom command `/sync-devenv-ghostty` to keep the `ghostty` input of @flake.nix on the revision this devenv commit requires
        4. Run `just switch` to switch to the updated configuration — always run this, even if steps 1-3 made no changes: whether a previous @${devenvPackage} update was ever actually switched isn't reliably knowable, and `just switch` is cheap (Nix reuses already-built store paths) when nothing changed
        5. If the switch fails on a cargoHash staleness issue (see the two failure shapes documented in @NIX-HASH-RECIPES.md — one of them reports no ready-to-use hash), update `cargoHash` in @${devenvPackage} setting it to the empty string: `cargoHash = "";`, but only if the failure hasn't already reported a ready `got: sha256-...` value, in which case skip the next step and use that value directly in the step after
        6. Run `just switch` again to get the right cargo hash. It will be automatically computed and reported in the logs
        7. Use this hash to update `cargoHash` in @${devenvPackage}
        8. Run `just switch` again to switch to the updated configuration
        9. Commit the changes if the switch succeeds and the cargo hash is updated
      '';

      rebase-devenv-branch = ''
        Branch to rebase in ${devenvFork}: $0

        1. Note: authentication for ${devenvFork} uses the `$DEVENV_GITHUB_TOKEN` env var, scoped specifically for this repo — not `$GITHUB_TOKEN`, which is a generic token used for unrelated purposes (e.g. nixpkgs-review)
        2. If no branch name was given above, stop and report the error
        3. Run `git ls-remote --exit-code ${devenvFork} "refs/heads/$0"` to verify the branch exists on the fork; fail if it doesn't (non-zero exit code)
        4. Determine the working branch: if `$0` already ends with `-temp`, the working branch is `$0` itself; otherwise the working branch is `$0-temp`, created from `$0`
        5. Clone `${devenvFork}` into `${devenvRebaseDir}` (first remove it with `rm -rf ${devenvRebaseDir}` if a previous run left it behind) and check out the working branch there: `git checkout -b <working-branch> "origin/$0"` if it needs to be created, or `git checkout <working-branch>` if it already exists
        6. Fetch cachix/devenv's main branch: `git fetch https://github.com/cachix/devenv.git main`
        7. Rebase the working branch onto it: `git rebase FETCH_HEAD`
        8. Force-push the rebased working branch back to the fork: `git push --force-with-lease origin HEAD:refs/heads/<working-branch>`
        9. Remove the clone: `rm -rf ${devenvRebaseDir}`
      '';

      update-boost = ''
        In @${boostPackage} bump the version, and update the hash in the fetchurl call if necessary.

        1. Run `curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/jfrog/boost/releases/latest" | sed 's#.*/tag/##'` to get the latest version and decide if it needs to be updated
        2. If the latest version is different from the current version, download it per the fetchurl recipe in @NIX-HASH-RECIPES.md: `wget -O /tmp/boost-<os>-<arch'>.tar.gz https://github.com/jfrog/boost/releases/download/v<version>/boost-<os>-<arch'>.tar.gz`, substituting variables according to @${boostPackage}, don't extract the compressed file
        3. Compute the hash with `nix hash file /tmp/boost-<os>-<arch'>.tar.gz`
        4. Update the version and hash in @${boostPackage}
        5. Remove the downloaded tarball: `rm -f /tmp/boost-<os>-<arch'>.tar.gz`
        6. Commit the changes if the version or hash was updated
      '';

      upgrade-system = ''
        Update jfrog-boost, update flake.lock, format README.md, switch, fix boost if needed and commit.

        1. Run the custom command `/update-boost` to update @${boostPackage}
        2. Run `just update` to update flake.lock. If there's no change to the flake.lock file and no committed changes in the previous step, finish
        3. Run `just switch` to switch
        4. If there was a successful switch and the first step (update-boost) committed a new version, run `boost init` to fix jfrog-boost installation
        5. Run the custom command `/gc` to format README.md and garbage-collect the devenv store
        6. Commit only the changes made by the previous steps (`flake.lock`, `${dirOf boostPackage}/`, `README.md`); stage them by explicit path (never `git add -A`, `git add .` or `git commit -a`) and leave pending edits under `home-modules/claude/` for a separate commit
      '';

      upgrade-all-then-push = ''
        Update devenv, then upgrade the rest of the system, then push everything.

        1. Run the custom command `/update-devenv` and let it finish completely: its last `just switch` has succeeded and any `cargoHash` fix is committed. If it fails, stop and report, without running the next steps or pushing
        2. Run the custom command `/upgrade-system`. If it finishes early because nothing changed, still go on to step 3, so the commits from step 1 get pushed. If it fails, stop and report without pushing
        3. If `git status -sb` shows `main` ahead of `origin/main`, run `git push origin main` on its own, never piped through `tail`, `head` or `grep` (the pipe's exit status would hide a failed push), and check its exit code. Then confirm that `git ls-remote origin main` matches `git rev-parse HEAD`
        4. Report the commits each step made and the pushed head, and pass on any interactive-shell check that `/sync-devenv-ghostty` asked for. Pending edits under `home-modules/claude/` stay uncommitted, as `/upgrade-system` leaves them; mention any that `git status` shows
      '';

      gc = ''
        Format README.md and garbage-collect the devenv store.

        1. Run `touch README.md` and `nix fmt` to format README.md
        2. Run `devenv gc --no-tui` to garbage-collect the devenv store
      '';
    };
    permissions = {
      rules = {
        WebFetch = {
          allow = [
            "domain:github.com"
            "domain:docs.anthropic.com"
          ];
        };
        Edit = {
          allow = [
            boostPackage
            devenvPackage
            "flake.nix"
          ];
        };
        Bash = {
          allow = [
            "nix search:*"
            "nix-instantiate:*"
            "git:*"
            "sudo:nixos-rebuild"
            "/run/wrappers/bin/sudo:nixos-rebuild"
            "rm -f:/tmp/boost-linux-amd64.tar.gz"
            "rm -rf:${devenvRebaseDir}"
            "boost:*"
            "curl -fsSLI:*"
            "curl -fsSL:*"
            "nix flake metadata:*"
            "nix flake update ghostty"
            "jq:*"
          ];
        };
      };
    };
  };

  overlays = [
    (
      _: prev:
      let
        name = "mdsh";
        version = "0.9.3";
        versionHash = "sha256-W9znh93RokghlqIjRRjIUJmkXxUAtLZtpZfGceTPK14=";
        versionCargoHash = "sha256-JbmHwAn3oXUUXsiQgCcZSBBS9o9Kam66MWHnbo25Fxg=";
        src = prev.fetchFromGitHub {
          owner = "tarc";
          repo = name;
          # tag = "v${version}";
          rev = "cd7d2374b551fbe5bf02367398cf6d6b140fca38";
          hash = versionHash;
        };
      in
      {
        mdsh = prev.mdsh.overrideAttrs (_: rec {
          inherit version src;
          cargoDeps = prev.rustPlatform.fetchCargoVendor {
            inherit src;
            name = "${name}-${version}-vendor";
            hash = versionCargoHash;
          };
        });
      }
    )
  ];

  treefmt = {
    enable = false;
    config = ./treefmt.nix;
  };
}
