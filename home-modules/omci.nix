{ inputs
, pkgs
, ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) system;
in
{
  home = {
    packages = [
      inputs.omnix.packages.${system}.default
    ];
  };
}
