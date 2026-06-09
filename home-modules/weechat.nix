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

  weechatSubmodule = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = false;
      };
      package = mkOption {
        type = types.package;
        default = pkgs.weechat;
      };
    };
  };

  cfg = config.weechat;
in
{
  options = {
    weechat = mkOption {
      type = weechatSubmodule;
      default = { };
    };
  };

  config = {
    # ircs://irc.libera.chat/#felinebuildservices
    home = {
      packages = lib.optionalAttrs cfg.enable [
        pkgs.weechat
      ];
    };
  };
}
