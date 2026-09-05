{
  config,
  pkgs,
  ...
}:
# let
#   claudeAgents = config.claude.code.agents;
#   openCodeModel = "opencode/kimi-k3";
#   claudeCodeModel = "opus";
# in
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
    commands = {
      inherit (config.claude.code.commands)
        update-boost
        upgrade-system
        update-devenv-version
        update-devenv-nix
        update-devenv
        rebase-devenv-branch
        ;
    };
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
        In @packages/devenv/package.nix bump the version, and update the hash in the `src = fetchFromGitHub` call if necessary.

        1. Check whether `src = fetchFromGitHub` in @packages/devenv/package.nix has `owner = "tarc"` and `repo = "devenv"` — this is an overridden scenario (a fork branch pinned in place of upstream cachix/devenv, typically with a comment above `src` linking to a cachix/devenv PR, and a comment on the `rev` line naming the branch). If it's not overridden (owner/repo are anything else), skip straight to step 5.
        2. In the overridden scenario, look for the branch in git@github.com:tarc/devenv.git that `src`'s `rev` belongs to: run `git ls-remote git@github.com:tarc/devenv.git | grep <rev>` to find a live branch whose tip is exactly that commit.
        3. If step 2 finds nothing (e.g. the branch was deleted after merging), fall back to the PR referenced in the comment above `src` (e.g. `https://github.com/cachix/devenv/pull/<number>`): run `curl -fsSL "https://api.github.com/repos/cachix/devenv/pulls/<number>" | jq -r '.head.ref, .merged'` to recover the branch name and merge status directly, even though the PR may already be closed.
        4. Decide based on the above: if the PR is merged (or the branch is gone and the PR shows merged), the override is finished — revert it by setting `owner = "cachix"` in @packages/devenv/package.nix and removing the comment block above `src`, then continue to step 5 so the normal flow below fills in the correct upstream rev/hash. Otherwise the override is still pending — run the custom command `/rebase-devenv-branch <branch>` (the branch name from step 2 or 3) to rebase it onto cachix/devenv's main, then run `git ls-remote git@github.com:tarc/devenv.git "refs/heads/<branch-or-its-rebase-devenv-branch--temp-variant>"` to get the new HEAD commit and `nix flake metadata "github:tarc/devenv/<new-rev>" --json | jq '.locked.narHash'` to get its hash, and update `rev`/`hash` in @packages/devenv/package.nix to these new values (`owner`/`repo` stay "tarc"/"devenv"; update the branch-name comment on `rev` too if `rebase-devenv-branch` created a new branch). Commit, then stop — steps 5-9 below only apply to the non-overridden case.
        5. Run `curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/cachix/devenv/releases/latest" | sed 's#.*/tag/v##'` to get the latest released version, used only as a human-readable version label (this does NOT pin `src` — see step 7)
        6. Update the version in @packages/devenv/package.nix (it's in the let binding, the `version` variable) to the latest released version, if necessary
        7. Run `nix flake metadata github:cachix/devenv --json | jq '.locked | .rev, .narHash'` to get, respectively, the latest commit and NAR hash of devenv's default branch — `src` intentionally tracks the rolling main branch, not the release tag from step 5
        8. Use these values to update devenv's rev and hash in the `src = fetchFromGitHub` call of @packages/devenv/package.nix, if necessary
        9. Commit the changes if the version or hash was updated
      '';

      update-devenv-nix = ''
        In @packages/devenv/package.nix update `devenvNixVersion`, `devenvNixRev`, and update the hash in the `devenvNixSrc = fetchFromGitHub` call if necessary.

        1. Run `nix flake metadata github:cachix/devenv --json | jq '.locks.nodes.nix | .original.ref, .locked.rev, .locked.narHash' | sed 's/devenv-//'` to get, respectively, devenvNixVersion, devenvNixRev and the NAR hash pinned by devenv's default (rolling main) branch — kept in sync with `src` in update-devenv-version, which tracks the same branch. This always resolves from cachix/devenv's main branch, even when update-devenv-version has an active fork override in `src` (owner = "tarc") — the nix-input pin is intentionally decoupled from the devenv source override, so don't substitute the fork here
        2. Use these values to update `devenvNixVersion` and `devenvNixRev` in @packages/devenv/package.nix (they are let bindings), and the hash in the `devenvNixSrc = fetchFromGitHub` call of @packages/devenv/package.nix, if necessary
        3. Commit the changes if devenvNixVersion, devenvNixRev, or the hash were updated
      '';

      update-devenv = ''
        Update @packages/devenv/package.nix (both version and nix) and try to switch the system. If the switch fails, update `cargoHash` and try again.

        1. Run the custom command `/update-devenv-version` to update @packages/devenv/package.nix
        2. Run the custom command `/update-devenv-nix` to update the nix source in @packages/devenv/package.nix
        3. If update-devenv-version or update-devenv-nix committed a change (or if a previous update of @packages/devenv/package.nix was never switched on), run `just switch` to switch to the updated configuration
        4. If the switch fails, update `cargoHash` in @packages/devenv/package.nix setting it to the empty string: `cargoHash = "";`, but only if the failure hasn't already reported the correct hash (in which case, skip the next step and use this hash directly in the step after)
        5. Run `just switch` again to get the right cargo hash. It will be automatically computed and reported in the logs
        6. Use this hash to update `cargoHash` in @packages/devenv/package.nix
        7. Run `just switch` again to switch to the updated configuration
        8. Commit the changes if the switch succeeds and the cargo hash is updated
      '';

      rebase-devenv-branch = ''
        Branch to rebase in git@github.com:tarc/devenv.git: $1

        1. Note: authentication for git@github.com:tarc/devenv.git uses the `$DEVENV_GITHUB_TOKEN` env var, scoped specifically for this repo — not `$GITHUB_TOKEN`, which is a generic token used for unrelated purposes (e.g. nixpkgs-review)
        2. If no branch name was given above, stop and report the error
        3. Run `git ls-remote --exit-code git@github.com:tarc/devenv.git "refs/heads/$1"` to verify the branch exists on the fork; fail if it doesn't (non-zero exit code)
        4. Determine the working branch: if `$1` already ends with `-temp`, the working branch is `$1` itself; otherwise the working branch is `$1-temp`, created from `$1`
        5. Clone `git@github.com:tarc/devenv.git` into a fresh temporary directory and check out the working branch there: `git checkout -b <working-branch> "origin/$1"` if it needs to be created, or `git checkout <working-branch>` if it already exists
        6. Fetch cachix/devenv's main branch: `git fetch https://github.com/cachix/devenv.git main`
        7. Rebase the working branch onto it: `git rebase FETCH_HEAD`
        8. Force-push the rebased working branch back to the fork: `git push --force-with-lease origin HEAD:refs/heads/<working-branch>`
        9. Remove the temporary clone directory
      '';

      update-boost = ''
        In @packages/jfrog-boost/package.nix bump the version, and update the hash in the fetchurl call if necessary.

        1. Run `curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/jfrog/boost/releases/latest" | sed 's#.*/tag/##'` to get the latest version and decide if it needs to be updated
        2. If the latest version is different from the current version, run `wget -O /tmp/boost-<os>-<arch'>.tar.gz https://github.com/jfrog/boost/releases/download/v<version>/boost-<os>-<arch'>.tar.gz`, substituting variables according to @packages/jfrog-boost/package.nix (`-O` overwrites any stale download left over from a previous run — plain `wget` appends `.1`/`.2` instead of overwriting), don't extract the compressed file
        3. Compute the hash with `nix hash file /tmp/boost-<os>-<arch'>.tar.gz`
        4. Update the version and hash in @packages/jfrog-boost/package.nix
        5. Remove the downloaded tarball: `rm -f /tmp/boost-<os>-<arch'>.tar.gz`
        6. Commit the changes if the version or hash was updated
      '';

      upgrade-system = ''
        Update jfrog-boost, update flake.lock, format README.md, switch, fix boost if needed and commit.

        1. Run the custom command `/update-boost` to update @packages/jfrog-boost/package.nix
        2. Run `just update` to update flake.lock. If there's no change to the flake.lock file and no committed changes in the previous step, finish
        3. Run `just switch` to switch
        4. If there was a successful switch and the first step (update-boost) committed a new version, run `boost init` to fix jfrog-boost installation
        5. Run `touch README.md` and `nix fmt` to format README.md
        6. Commit the changes
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
            "packages/jfrog-boost/package.nix"
            "packages/devenv/package.nix"
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
            "rm -rf:/tmp/devenv-rebase"
            "boost:*"
            "curl -fsSLI:*"
            "curl -fsSL:*"
            "nix flake metadata:*"
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
