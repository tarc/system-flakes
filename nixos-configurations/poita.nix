{
  inputs,
  config,
  pkgs,
  ...
}:
let
  cfg = config.wsl;
  defaultUser = cfg.defaultUser;
  home = config.users.users.${defaultUser}.home;
in
{
  imports = [
    inputs.nixos-wsl.nixosModules.default
    inputs.agenix.nixosModules.default
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

  age.identityPaths = [ "${home}/.ssh/id_ed25519" ];

  age.secrets.netbird-setupkey = {
    file = "${inputs.secrets}/poita-local-netbird-setup-key.age";
    # owner/mode default to root:root, 0400 — fine since netbird's
    # client daemon runs as root by default
  };

  # services.netbird.enable = true;
  services.netbird.clients.wt0 = {
    login = {
      enable = true;
      setupKeyFile = config.age.secrets.netbird-setupkey.path;
    };
    port = 51821;
    ui.enable = false; # no GUI needed in WSL
    openFirewall = true;
    openInternalFirewall = true;
  };

  networking.nameservers = [ ];
  services.resolved.enable = true;

  # stop WSL from overwriting resolv.conf out from under systemd-resolved
  wsl.wslConf.network.generateResolvConf = false;
}
