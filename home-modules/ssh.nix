{
  config,
  lib,
  ...
}:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {

      "*" = {
        addKeysToAgent = "yes";
      };

      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "${config.home.homeDirectory}/.ssh/id_github";
        identitiesOnly = true;
      };

      "codeberg.org" = {
        hostname = "codeberg.org";
        user = "git";
        identityFile = "${config.home.homeDirectory}/.ssh/id_ed25519_codeberg";
      };

      "hostinger" = {
        hostname = "179.198.127.235";
        user = "tarcisio";
        identityFile = "${config.home.homeDirectory}/.ssh/id_ed25519_hostinger";
      };

    };
  };
}
