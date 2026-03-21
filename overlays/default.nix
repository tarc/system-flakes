{ inputs
, pkgs
, ...
}:
{
  nixpkgs.overlays = [
    (import ./devenv.nix)
  ];
}
