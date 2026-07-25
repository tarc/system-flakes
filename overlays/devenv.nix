{
  ...
}:
(
  final: prev:
  let
    name = "devenv";
    version = "2.1.2"; # "2.0.5";
    versionHash = "sha256-EQnZCy7r4VMO6KDoytxHBa0mFbM1D9g1kaDfs/s0YZA="; # "sha256-8tO3NLG9Lc/NUee0Owcf/z63TNTrUcx7eVRxSb294rk=";
    versionCargoHash = "sha256-uEwxqnLqCFpyV2NbnfuUyVqKrMeVeQzoGQmElaVeGU8="; # "sha256-ecntFSPDWblllDtS/D086UKtQJG9La4TGEBhP3q0CfY=";
    src = prev.fetchFromGitHub {
      owner = "cachix";
      repo = name;
      tag = "v${version}";
      hash = versionHash;
    };
  in
  {
    devenv = prev.devenv.overrideAttrs (old: rec {
      inherit version src;
      cargoDeps = prev.rustPlatform.fetchCargoVendor {
        inherit src;
        name = "${name}-${version}-vendor";
        hash = versionCargoHash;
      };
    });
  }
)
