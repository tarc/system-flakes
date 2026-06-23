{ ... }@args:
{
  systemFlakes =
    let
      lib = import ./. {
        inherit (args) inputs;
        inherit lib;
      };
    in
    lib;
}
