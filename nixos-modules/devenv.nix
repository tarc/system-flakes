{
  inputs,
  pkgs,
  ...
}:
{
  environment = {
    systemPackages = [
      pkgs.devenv
    ];
  };
}
