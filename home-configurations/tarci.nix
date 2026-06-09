{
  inputs,
  pkgs,
  ezModules,
  config,
  ...
}:
let
  homeDir = config.home.homeDirectory;
in
{
  imports = [
    ezModules.agenix
    ezModules.git
    ezModules.ssh
    ezModules.zsh-shell
  ];

  config =
    let
      githubToken = "$(${pkgs.coreutils-full}/bin/cat ${config.age.secrets.GITHUB_TOKEN.path})";
      codebergToken = "$(${pkgs.coreutils-full}/bin/cat ${config.age.secrets.CODEBERG_TOKEN.path})";
      cachixAuthToken = "$(${pkgs.coreutils-full}/bin/cat ${config.age.secrets.CACHIX_AUTH_TOKEN.path})";
      tarcDevenvNixpkgsRollingGenericToken = "$(${pkgs.coreutils-full}/bin/cat ${config.age.secrets.TARC_DEVENV_NIXPKGS_ROLLING_GENERIC_TOKEN.path})";
      tarcDevenvNixpkgsRollingPlayConanToken = "$(${pkgs.coreutils-full}/bin/cat ${config.age.secrets.TARC_DEVENV_NIXPKGS_ROLLING_PLAY_CONAN_TOKEN.path})";
    in
    {
      home = {
        stateVersion = "22.05";
        homeDirectory = if pkgs.stdenv.isDarwin then "/Users/tarci" else "/home/tarci";
        username = "tarci";
        sessionVariables = {
          GITHUB_TOKEN = githubToken;
          CODEBERG_TOKEN = codebergToken;
          CACHIX_AUTH_TOKEN = cachixAuthToken;
          TARC_DEVENV_NIXPKGS_ROLLING_GENERIC_TOKEN = tarcDevenvNixpkgsRollingGenericToken;
          TARC_DEVENV_NIXPKGS_ROLLING_PLAY_CONAN_TOKEN = tarcDevenvNixpkgsRollingPlayConanToken;
          EDITOR = "vim";
          VISUAL = "vim";
          LANG = "en_US.UTF-8";
        };
        file = {
          ssh = {
            text = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDBwQowLdWXXjnlk9JZDREjZZM86SkWDApEQtz9fbxAw tarcisio.genaro@gmail.com";
            target = ".ssh/id_github.pub";
          };
        };
      };

      weechat.enable = true;

      programs.git.settings = {
        user = {
          email = "tarcisio.genaro@gmail.com";
          name = "tarcisio";
        };

        credential = {
          helper = "manager";
          credentialStore = "cache";
          "https://github.com".username = "tarc";
          "https://codeberg.org".username = "tarcisio";
          "https://codeberg.org".provider = "generic";
        };
      };

      direnv.enable = true;
      xdg.enable = true;

      age.identityPaths = [ "${homeDir}/.ssh/id_ed25519" ];

      age.secrets = {
        "GITHUB_TOKEN".file = "${inputs.secrets}/nixpkgs-review-github-pat.age";

        "CODEBERG_TOKEN".file = "${inputs.secrets}/codeberg-pat.age";

        "CACHIX_AUTH_TOKEN".file = "${inputs.secrets}/tarcisio-system-flakes-auth-token.age";

        "TARC_DEVENV_NIXPKGS_ROLLING_GENERIC_TOKEN".file =
          "${inputs.secrets}/tarc-devenv-nixpkgs-rolling-generic-auth-token.age";

        "TARC_DEVENV_NIXPKGS_ROLLING_PLAY_CONAN_TOKEN".file =
          "${inputs.secrets}/tarc-devenv-nixpkgs-rolling-play-conan-auth-token.age";

        "codeberg-ssh-key" = {
          symlink = true;
          path = "${homeDir}/.ssh/id_ed25519_codeberg";
          file = "${inputs.secrets}/codeberg-ssh-key.age";
          mode = "600";
        };

        "github-ssh-key" = {
          symlink = true;
          path = "${homeDir}/.ssh/id_github";
          file = "${inputs.secrets}/github-ssh-key.age";
          mode = "600";
        };

        "github-recovery-codes" = {
          symlink = true;
          path = "${homeDir}/.ssh/github-recovery-codes.txt";
          file = "${inputs.secrets}/github-recovery-codes.age";
          mode = "600";
        };

        "up-leg-certificate" = {
          symlink = true;
          path = "${homeDir}/.ssh/up-leg-certificate.pem";
          file = "${inputs.secrets}/up-leg-certificate.age";
          mode = "600";
        };

        "up-leg-certificate-pfx" = {
          symlink = true;
          path = "${homeDir}/.ssh/up-leg-certificate.pfx";
          file = "${inputs.secrets}/up-leg-certificate.pfx.age";
          mode = "600";
        };

        "nixconf" = {
          symlink = true;
          path = "${config.xdg.configHome}/nix/nix.conf";
          file = "${inputs.secrets}/nix.age";
          mode = "600";
        };

        "google-api-key" = {
          symlink = true;
          path = "${config.xdg.dataHome}/google-api/key";
          file = "${inputs.secrets}/google-api-key.age";
          mode = "600";
        };
      };
    };
}
