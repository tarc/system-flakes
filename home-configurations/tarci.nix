{ inputs
, pkgs
, ezModules
, config
, ...
}:
let
  homeDir = config.home.homeDirectory;
in
{
  imports = [
    ezModules.agenix
    ezModules.git
    ezModules.omci
    ezModules.ssh
    ezModules.zsh-shell
  ];

  config =
    let
      githubToken = "$(${pkgs.coreutils-full}/bin/cat ${config.age.secrets.GITHUB_TOKEN.path})";
    in
    {
      home = {
        stateVersion = "22.05";
        homeDirectory = if pkgs.stdenv.isDarwin then "/Users/tarci" else "/home/tarci";
        username = "tarci";
        sessionVariables = {
          GITHUB_TOKEN = githubToken;
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

      programs.git.settings = {
        user.email = "tarcisio.genaro@gmail.com";
        user.name = "tarc";
      };

      direnv.enable = true;
      xdg.enable = true;

      age.identityPaths = [ "${homeDir}/.ssh/id_ed25519" ];

      age.secrets = {
        "GITHUB_TOKEN".file = "${inputs.secrets}/nixpkgs-review-github-pat.age";

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
