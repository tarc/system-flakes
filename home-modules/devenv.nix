{
  inputs,
  pkgs,
  ...
}:
{
  home = {
    packages = [
      pkgs.devenv
    ];
  };
}
