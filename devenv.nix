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
      inherit (config.claude.code.commands) update-boost upgrade-system;
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
        In @devenv/package.nix bump the version, and update the hash in the `src = fetchFromGitHub` call if necessary.

        1. Run `curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/cachix/devenv/releases/latest" | sed 's#.*/tag/v##'` to get the latest released version to know if there was a new main release since the last update
        2. Update the version in @devenv/package.nix (it's in the let binding, the `version` variable) to the latest released version, if necessary
        3. Run `nix flake metadata github:cachix/devenv --json | jq '.locked | .rev, .narHash'` to get, respectivelly, devenv's latest commit hash and NAR hash
        4. Use these values to update devenv's rev and hash in the `src = fetchFromGitHub` call of @devenv/package.nix, if necessary
        5. Commit the changes if the version or hash was updated
      '';

      update-boost = ''
        In @jfrog-boost/package.nix bump the version, and update the hash in the fetchurl call if necessary.

        1. Run `curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/jfrog/boost/releases/latest" | sed 's#.*/tag/##'` to get the latest version and decide if it needs to be updated
        2. If the latest version is different from the current version, run `wget https://github.com/jfrog/boost/releases/download/v<version>/boost-<os>-<arch'>.tar.gz`, substituing variables according to @jfrog-boost/package.nix, dont't extract the compressed file
        3. Compute the hash with `nix hash file boost-<os>-<arch'>.tar.gz`
        4. Update the version and hash in @jfrog-boost/package.nix
        5. Commit the changes if the version or hash was updated
      '';

      upgrade-system = ''
        Update jfrog-boost, update flake.lock, format README.md, switch, fix boost if needed and commit.

        1. Run the custom command `/update-boost` to update @jfrog-boost/package.nix
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
          allow = [ "packages/jfrog-boost/package.nix" ];
        };
        Bash = {
          allow = [
            "nix search:*"
            "nix-instantiate:*"
            "git:*"
            "sudo:nixos-rebuild"
            "rm -f:/tmp/boost-linux-amd64.tar.gz"
            "rm -rf:/tmp/boost-linux-amd64.tar.gz /tmp/boost-extract"
            "boost:*"
            "boost init:*"
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
