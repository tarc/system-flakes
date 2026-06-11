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

  clipboardSubmodule = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };
      package = mkOption {
        type = types.package;
        default = pkgs.wl-clipboard;
      };
    };
  };

  cfg = config.clipboard;
in
{
  options = {
    clipboard = mkOption {
      type = clipboardSubmodule;
      default = { };
    };
  };

  config = {
    home = {
      packages = lib.optionalAttrs cfg.enable [
        cfg.package
      ];
    };
  };
}
