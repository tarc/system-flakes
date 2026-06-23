{
  lib,
  ...
}:
{
  maintainers = import ../maintainers/maintainer-list.nix;
  constants = import ./constants.nix { inherit lib; };
}
