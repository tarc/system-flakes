{ config
, inputs
, pkgs
, ezModules
, ...
}:
{
  imports = [
    inputs.nixos-wsl.nixosModules.default
  ];

  system.stateVersion = "24.05";

  wsl = {
    enable = true;
    defaultUser = "tarci";
    startMenuLaunchers = true;
    wslConf.automount.root = "/mnt";
    docker-desktop.enable = true;
    useWindowsDriver = true;
  };

  users.users.tarci = {
    isNormalUser = true;
    home = "/home/tarci";
    description = "Tarcisio Genaro Rodrigues";
    shell = pkgs.zsh;
    extraGroups = [ "wheel" ];
  };

  nixpkgs = {
    hostPlatform = "x86_64-linux";
    config.allowUnfree = true;
    config.allowUnsupportedSystem = false;
    config.cudaSupport = true;
  };

  home-manager.useGlobalPkgs = true;

  programs.nix-ld.enable = true;
  programs.zsh.enable = true;
}
