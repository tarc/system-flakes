{
  ezModules,
  inputs,
  lib,
  modulesPath,
  pkgs,
  ...
}:
{
  imports = [
    ezModules.cache
    # ezModules.devenv
    ../overlays
  ];

  environment.systemPackages = with pkgs; [
    file
    wget
    vim
    home-manager
    nssTools
    openssl
    kdePackages.okular
    kdePackages.dolphin
    google-chrome
  ];

  cache = {
    enable = true;
    name = "tarcisio-system-flakes";
    publicKey = "0aH1vqCStSra4G5ndJGn81naNM5RSugt9yhxQsoYlNA=";
  };

  nix = {
    extraOptions = "experimental-features = nix-command flakes ca-derivations";

    settings = {
      trusted-users = [
        "tarci"
        "root"
        "@wheel"
      ];
      trusted-substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://devenv.cachix.org"
        "https://cache.iog.io"
        "https://cache.nixos.asia/oss"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
        "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
        "oss:KO872wNJkCDgmGN3xy9dT89WAhvv13EiKncTtHDItVU="
      ];
      auto-optimise-store = false;
    };

    optimise = {
      automatic = true;
    };

    gc = {
      automatic = true;
      options = "--delete-older-than 3d";
    };
  };
}
