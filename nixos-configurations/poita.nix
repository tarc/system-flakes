{
  inputs,
  config,
  pkgs,
  ...
}:
{
  imports = [
    inputs.nixos-wsl.nixosModules.default
  ];

  system.stateVersion = "24.05";

  environment.systemPackages = [
    pkgs.age
    # pkgs.auggie
    pkgs.claude-code
    # pkgs.devpod
    # pkgs.devpod-desktop
    pkgs.embedme
    pkgs.jfrog-boost
    pkgs.gh
    pkgs.lshw
    pkgs.mesa-demos
    pkgs.nixd
    pkgs.nil
    pkgs.pciutils
    pkgs.seahorse
    pkgs.vulkan-tools
    pkgs.rocmPackages.rocminfo
    pkgs.zed-editor
  ];

  wsl = {
    enable = true;
    defaultUser = "tarci";
    startMenuLaunchers = true;
    wslConf.automount.root = "/mnt";
    useWindowsDriver = true;
  };

  virtualisation.docker.enable = true;
  wsl.docker-desktop.enable = false;

  programs.nix-ld = {
    enable = true;
  };

  users.users.tarci = {
    isNormalUser = true;
    home = "/home/tarci";
    description = "Tarcisio Genaro Rodrigues";
    shell = pkgs.zsh;
    extraGroups = [
      "docker"
      "wheel"
    ];
  };

  nixpkgs = {
    hostPlatform = "x86_64-linux";
    config.allowUnfree = true;
    config.allowUnsupportedSystem = false;
    config.cudaForwardCompat = true;
    config.cudaSupport = true;
  };

  home-manager.useGlobalPkgs = true;

  programs.zsh.enable = true;

  services.gnome.gnome-keyring.enable = true;
}
