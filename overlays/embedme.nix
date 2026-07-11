{ systemFlakes, ... }:
(
  final: prev:
  let
    pname = "embedme";
    version = "1.18.0";

    src = prev.fetchFromGitHub {
      owner = "tarc";
      repo = "embedme";
      rev = "77a1513815f08e810706e26403ead67be658eac8";
      hash = "sha256-2vh5m7QoW4WNGY5S8ZtK6IFOuxi6mGhbl/VdrTjEViI=";
    };

    nodejs = prev.nodejs;
    yarnInstallHook = prev.yarnInstallHook;
    yarnConfigHook = prev.yarnConfigHook;
  in
  {
    embedme = prev.stdenv.mkDerivation (finalAttrs: {
      inherit pname version src;

      yarnOfflineCache = prev.fetchYarnDeps {
        yarnLock = "${finalAttrs.src}/yarn.lock";
        hash = "sha256-GQgx9iZ4uAp7+CJKYuClkbHjgY1zQ6fGr3jvWTZ2/vY=";
      };

      nativeBuildInputs = [
        yarnConfigHook
        yarnInstallHook
        nodejs
      ];

      doCheck = true;

      nativeCheckInputs = [ prev.git ];

      checkPhase = ''
        runHook preCheck
        yarn --offline run test -i -g 'compileTemplate'
        runHook postCheck
      '';

      passthru = {
        updateScript = prev.nix-update-script { };
      };

      meta = {
        description = "Utility for embedding code snippets into markdown documents";
        homepage = "https://github.com/tarc/embedme";
        license = prev.lib.licenses.mit;
        mainProgram = "embedme";
        maintainers = [ systemFlakes.maintainers.tarc ];
      };
    });
  }
)
