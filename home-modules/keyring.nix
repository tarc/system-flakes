{ pkgs, ... }:
{
  services.gnome-keyring.enable = true;
  home.packages = [ pkgs.gcr pkgs.seahorse ]; # Provides org.gnome.keyring.SystemPrompter
}
