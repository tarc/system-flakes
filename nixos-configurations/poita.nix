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

  environment.systemPackages = with pkgs; [
    age
    # auggie
    claude-agent-acp
    claude-code
    embedme
    jfrog-boost
    gh
    lshw
    mesa-demos
    nixd
    nil
    opencode
    opencode-claude-auth
    pciutils
    seahorse
    vulkan-tools
    rocmPackages.rocminfo
    zed-editor
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

  services.netbird.enable = true;
}
