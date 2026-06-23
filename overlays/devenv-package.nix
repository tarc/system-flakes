{
  ...
}:
(
  final: prev:
  let
    version = "2.1.3";
    devenvNixVersion = "2.34";
    devenvNixRev = "42d4b7de21c15f28c568410f4383fa06a8458a40";

    devenvNixSrc = prev.fetchFromGitHub {
      name = "devenv-nix-${devenvNixVersion}-source";
      owner = "cachix";
      repo = "nix";
      rev = devenvNixRev;
      hash = "sha256-g2KEBuHpc3a56c+jPcg0+w6LSuIj6f+zzdztLCOyIhc=";
    };

    nix_components = (prev.nixVersions.nixComponents_git.overrideSource devenvNixSrc).overrideScope (
      finalScope: prevScope: {
        version = devenvNixVersion;
      }
    );
  in
  {
    devenv = prev.rustPlatform.buildRustPackage {
      pname = "devenv";
      inherit version;

      src = prev.fetchFromGitHub {
        owner = "tarc";
        repo = "devenv";
        rev = "feature/conan-flake";
        hash = "sha256-2ownxZ17zdfnk0E7Jh2teNKMi9wzO+pkvzn1wLB3YRU=";
      };

      cargoHash = "sha256-jX1g0bIEBTHw9TEzXXBASMpcokO9nii6MdmDJK61K3I=";

      env = {
        RUSTFLAGS = "--cfg tracing_unstable";
        LIBSQLITE3_SYS_USE_PKG_CONFIG = "1";
        DEVENV_IS_RELEASE = true;
      };

      cargoBuildFlags = [
        "-p"
        "devenv"
        "-p"
        "devenv-run-tests"
      ];

      nativeBuildInputs = [
        prev.installShellFiles
        prev.makeBinaryWrapper
        prev.pkg-config
        prev.protobuf
        prev.rustPlatform.bindgenHook
      ];

      buildInputs = [
        prev.openssl
        prev.sqlite
        prev.dbus
        prev.libghostty-vt
        prev.llvmPackages.clang-unwrapped
        nix_components.nix-expr-c
        nix_components.nix-store-c
        nix_components.nix-util-c
        nix_components.nix-flake-c
        nix_components.nix-cmd-c
        nix_components.nix-fetchers-c
        nix_components.nix-main-c
      ];

      nativeCheckInputs = [
        prev.gitMinimal
        prev.bash
      ];

      preCheck = ''
        # Initialize git repo for tests that use git-root-relative imports
        pushd $NIX_BUILD_TOP/source
        git init -b main
        git config user.email "test@example.com"
        git config user.name "Test User"
        git add -A
        popd
      '';

      useNextest = true;
      cargoTestFlags = [
        "-p"
        "devenv"
      ];

      postInstall =
        let
          setDefaultLocaleArchive = prev.lib.optionalString (prev.glibcLocalesUtf8 != null) ''
            --set-default LOCALE_ARCHIVE ${prev.glibcLocalesUtf8}/lib/locale/locale-archive
          '';
        in
        ''
          wrapProgram $out/bin/devenv \
            --prefix PATH ":" "$out/bin:${prev.lib.getBin prev.cachix}/bin:${prev.lib.getBin prev.nixd}/bin" \
            ${setDefaultLocaleArchive}

          wrapProgram $out/bin/devenv-run-tests \
            --prefix PATH ":" "$out/bin:${prev.lib.getBin prev.cachix}/bin:${prev.lib.getBin prev.nixd}/bin" \
            ${setDefaultLocaleArchive}

          # Generate manpages
          cargo xtask generate-manpages --out-dir man
          installManPage man/*

          # Generate shell completions (devenv must be in PATH)
          compdir=./completions
          export PATH="$out/bin:$PATH"
          for shell in bash fish zsh; do
            cargo xtask generate-shell-completion $shell --out-dir $compdir
          done

          installShellCompletion --cmd devenv \
            --bash $compdir/devenv.bash \
            --fish $compdir/devenv.fish \
            --zsh $compdir/_devenv
        '';

      passthru.tests = {
        version = prev.testers.testVersion {
          package = final.devenv;
          command = "export XDG_DATA_HOME=$PWD; devenv version";
        };
      };

      meta = {
        changelog = "https://github.com/cachix/devenv/releases";
        description = "Fast, Declarative, Reproducible, and Composable Developer Environments";
        homepage = "https://github.com/cachix/devenv";
        license = prev.lib.licenses.asl20;
        mainProgram = "devenv";
        maintainers = with prev.lib.maintainers; [
          domenkozar
          sandydoo
        ];
      };
    };
  }
)
