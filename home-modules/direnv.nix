{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;

  direnvSubmodule = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
      };
    };
  };

  cfg = config.direnv;
in
{
  options = {
    direnv = mkOption {
      type = direnvSubmodule;
      default = { };
    };
  };

  config = {
    programs = lib.optionalAttrs cfg.enable {
      direnv = {
        enable = true;
        nix-direnv.enable = true;
        enableZshIntegration = true;
        stdlib = ''
          # Two things to know:
          # * `direnv_layour_dir` is called once for every {.direnvrc,.envrc} sourced
          # * The indicator for a different direnv file being sourced is a different $PWD value
          # This means we can hash $PWD to get a fully unique cache path for any given environment

          declare -A direnv_layout_dirs
          direnv_layout_dir() {
            echo "''${direnv_layout_dirs[$PWD]:=$(
              local hash="$(sha1sum - <<<"''${PWD}" | cut -c-7)"
              local path="''${PWD//[^a-zA-Z0-9]/-}"
              echo "${config.xdg.cacheHome}/direnv/layouts/''${hash}''${path}"
            )}"
          }
        '';
      };
    };

    home.packages = lib.optional cfg.enable pkgs.direnv;
  };
}
