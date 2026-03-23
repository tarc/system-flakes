final: prev:
let
  name = "devenv";
  version = "2.0.6"; # "2.0.5";
  versionHash = "sha256-i1G6n/7Z5fO9RhplzXQSTiLyh1Cs0GhoCoEStFLARtA="; # "sha256-8tO3NLG9Lc/NUee0Owcf/z63TNTrUcx7eVRxSb294rk=";
  versionCargoHash = "sha256-p5kI7HlG6RVxCCEb/J0L2gh36jkm/atAV98ny3h4vqo="; # "sha256-ecntFSPDWblllDtS/D086UKtQJG9La4TGEBhP3q0CfY=";
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
