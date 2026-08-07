{
  systemFlakes,
  pkgs,
  ...
}:
let
  devenv = pkgs.callPackage ../packages/devenv/package.nix { };
  jfrog-boost = pkgs.callPackage ../packages/jfrog-boost/package.nix { inherit systemFlakes; };
in
{
  nixpkgs = {
    overlays = [
      # inputs.rust-overlay.overlays.default
      # (import ./devenv.nix { inherit systemFlakes; })
      (final: prev: {
        inherit devenv;
        inherit jfrog-boost;
      })
      # (import ./devenv-override-input.nix { inherit systemFlakes; })
      (import ./weechat.nix { inherit systemFlakes; })
      # (import ./auggie.nix { inherit systemFlakes; })
      (import ./embedme.nix { inherit systemFlakes; })
      (import ./mdsh.nix { inherit systemFlakes; })
    ];
  };
}
