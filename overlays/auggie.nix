{
  systemFlakes,
  ...
}:
(
  final: prev:
  let
    pname = "auggie";
    version = "0.31.0";
    src = prev.fetchurl {
      url = "https://registry.npmjs.org/@augmentcode/auggie/-/auggie-${version}.tgz";
      hash = "sha256-JDzUu6gyomHbqJNtSfgys0P9827WZGLCpnEQVeidOzo=";
    };
    pnpm = prev.pnpm_10;
    nodejs = prev.nodejs_22;
  in
  {
    auggie = prev.stdenv.mkDerivation (finalAttrs: {
      inherit pname version src;

      nativeBuildInputs = [
        nodejs
        pnpm
      ];

      buildInputs = [
        nodejs
      ];

      installPhase = ''
        runHook preInstall

        rm -rf node_modules
        pnpm install --force --offline --production --ignore-scripts
        ls -alhort

        mkdir -p $out/lib/node_modules/auggie/bin
        mkdir $out/bin
        cp augment.mjs $out/lib/node_modules/auggie/bin/
        cp -r node_modules package.json $out/lib/node_modules/auggie

        find $out

        ln -s $out/lib/node_modules/auggie/bin/augment.mjs $out/bin/auggie
        chmod +x $out/bin/auggie
        patchShebangs $out/bin/auggie

        runHook postInstall
      '';

      passthru.updateScript = prev.nix-update-script { };
      passthru.tests.version = prev.testers.testVersion {
        package = finalAttrs.finalPackage;
      };

      meta = {
        description = "An AI agent that brings Augment Code's power to the terminal";
        homepage = "https://www.augmentcode.com/";
        license = final.lib.licenses.mit;
        mainProgram = "auggie";
        maintainers = [
          systemFlakes.maintainers.tarc
        ];
      };
    });
  }
)
