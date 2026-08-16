{
  config,
  ...
}:
# let
#   claudeAgents = config.claude.code.agents;
#   openCodeModel = "opencode/kimi-k3";
#   claudeCodeModel = "opus";
# in
{
  name = "cetacea";

  languages = {
    deno.enable = true;

    javascript = {
      enable = true;
      npm.enable = true;
      pnpm.enable = true;
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
      update-boost = ''
        In @jfrog-boost/package.nix bump the version, and update the hash in the fetchurl call.

        1. Run `curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/jfrog/boost/releases/latest" | sed 's#.*/tag/##'` to get the latest version and decide if it needs to be updated
        2. If the latest version is different from the current version, run `wget https://github.com/jfrog/boost/releases/download/v<version>/boost-<os>-<arch'>.tar.gz`, substituing variables according to @jfrog-boost/package.nix, dont't extract the compressed file
        3. Compute the hash with `nix hash file boost-<os>-<arch'>.tar.gz`
        4. Update the version and hash in @jfrog-boost/package.nix
        5. Commit the changes
      '';
    };
    permissions = {
      WebFetch = {
        allow = [
          "domain:github.com"
          "domain:docs.anthropic.com"
        ];
      };
      Bash = {
        allow = [
          "nix search:*"
          "nix-instantiate:*"
          "git:*"
        ];
      };
    };
  };

  treefmt = {
    enable = true;
    config = ./treefmt.nix;
  };
}
