{ inputs
, lib
, modulesPath
, pkgs
, ...
}:
{
  environment.systemPackages = with pkgs; [
    file
    wget
    vim
    git
    home-manager
    nssTools
    openssl
    kdePackages.okular
    kdePackages.dolphin
    google-chrome
    anytype
  ];

  nix = {
    extraOptions = "experimental-features = nix-command flakes";

    settings = {
      trusted-users = [
        "tarci"
        "root"
        "@wheel"
      ];
      trusted-substituters = [
        "https://cache.nixos.org"
        "https://tarc.cachix.org"
        "https://nix-community.cachix.org"
        "https://devenv.cachix.org"
        "https://cache.iog.io"
        "https://om.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "tarc.cachix.org-1:wIYVNrWvfOFESyas4plhMmGv91TjiTBVWB0oqf1fHcE="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
        "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
        "om.cachix.org-1:ifal/RLZJKN4sbpScyPGqJ2+appCslzu7ZZF/C01f2Q="
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
