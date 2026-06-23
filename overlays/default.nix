{
  systemFlakes,
  ...
}:
{
  nixpkgs = {
    overlays = [
      # inputs.rust-overlay.overlays.default
      # (import ./devenv.nix { inherit systemFlakes; })
      # (import ./devenv-package.nix { inherit systemFlakes; })
      # (import ./devenv-override-input.nix { inherit systemFlakes; })
      (import ./weechat.nix { inherit systemFlakes; })
      (import ./auggie.nix { inherit systemFlakes; })
    ];
  };
}
