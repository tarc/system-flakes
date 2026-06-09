{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  nixpkgs.overlays = [
    # inputs.rust-overlay.overlays.default
    # (import ./devenv.nix)
    # (import ./devenv-package.nix)
    # (import ./devenv-override-input.nix)
    (import ./weechat.nix)
  ];
}
