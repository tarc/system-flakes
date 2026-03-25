{ config
, lib
, pkgs
, ...
}:
let
  inherit (lib)
    mkOption
    types
    ;

  cacheSubmodule = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };
      name = mkOption {
        type = types.str;
      };
      publicKey = mkOption {
        type = types.str;
      };
      cacheCommandName = mkOption {
        type = types.str;
        default = "cachix-cache";
      };
      dryRunCommandName = mkOption {
        type = types.str;
        default = "cachix-dry-run-cache";
      };
      flakeArchiveCommandName = mkOption {
        type = types.str;
        default = "flake-archive";
      };
    };
  };

  cfg = config.cache;

  cachixCacheCommandText = prefix: cachix: ''
    ${prefix}${cachix} "$@" ${cfg.name}
  '';

  cachixCacheScript = pkgs.writeShellApplication {
    name = cfg.cacheCommandName;
    runtimeInputs = [
      pkgs.cachix
      pkgs.jq
    ];
    text = (cachixCacheCommandText "" "cachix");
  };

  cachixDryRunScript = pkgs.writeShellApplication {
    name = cfg.dryRunCommandName;
    runtimeInputs = [
      pkgs.cachix
      pkgs.jq
    ];
    text = (cachixCacheCommandText "echo " "cachix");
  };

  flakeArchiveScript = pkgs.writeShellApplication {
    name = cfg.flakeArchiveCommandName;
    runtimeInputs = [
      pkgs.nix
      pkgs.jq
    ];
    text = ''
      nix flake archive --json \
      | jq -r '.path,(.inputs|to_entries[].value.path)'
    '';
  };
in
{
  options = {
    cache = mkOption {
      type = cacheSubmodule;
      default = { };
    };
  };

  config = {
    environment.systemPackages = lib.optionalAttrs cfg.enable [
      cachixCacheScript
      cachixDryRunScript
      flakeArchiveScript
    ];
    nix.settings.trusted-substituters = lib.optional cfg.enable "https://${cfg.name}.cachix.org";
    nix.settings.trusted-public-keys = lib.optional cfg.enable "${cfg.name}.cachix.org-1:${cfg.publicKey}";
  };
}
