{
  lib,
  stdenv,
  fetchFromGitHub,
  gitMinimal,
  makeBinaryWrapper,
  installShellFiles,
  rustPlatform,
  testers,
  cachix,
  nixVersions,
  openssl,
  dbus,
  protobuf,
  sqlite,
  pkg-config,
  cmake,
  glibcLocalesUtf8,
  boehmgc,
  libghostty-vt,
  llvmPackages,
  nixd,
  bash,
  devenv, # required to run version test
}:

let
  version = "2.4.0";
  devenvNixVersion = "2.35";
  devenvNixRev = "bd10d7f563420c6034b9d1dc75c4168fc01e5afc";

  devenvNixSrc = fetchFromGitHub {
    name = "devenv-nix-${devenvNixVersion}-source";
    owner = "cachix";
    repo = "nix";
    rev = devenvNixRev;
    hash = "sha256-acP7QvsB+dHghUeL9AwSSZ3qS//skpqjv484aveg1EQ=";
  };

  nix_components = (nixVersions.nixComponents_git.overrideSource devenvNixSrc).overrideScope (
    finalScope: prevScope: {
      version = devenvNixVersion;
    }
  );
in
rustPlatform.buildRustPackage {
  pname = "devenv";
  inherit version;

  src = fetchFromGitHub {
    owner = "cachix";
    repo = "devenv";
    rev = "37be4a21c35e3baa56abb00d1721c2e87e6e93d1";
    hash = "sha256-HiuRv/FmNJ6V1A2QhqA5ruV8E5rh0f/vRGMHCWXcWO8=";
  };

  cargoHash = "sha256-n6/rFSm9wAf8h9r8Id5eOkF3IDKn3aX+nl1w+GBYwxw=";

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
    installShellFiles
    makeBinaryWrapper
    pkg-config
    protobuf
    cmake
    rustPlatform.bindgenHook
  ];

  buildInputs = [
    openssl
    sqlite
    dbus
    libghostty-vt
    llvmPackages.clang-unwrapped
    nix_components.nix-expr-c
    nix_components.nix-store-c
    nix_components.nix-util-c
    nix_components.nix-flake-c
    nix_components.nix-cmd-c
    nix_components.nix-fetchers-c
    nix_components.nix-main-c
  ];

  nativeCheckInputs = [
    gitMinimal
    bash
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
      setDefaultLocaleArchive = lib.optionalString (glibcLocalesUtf8 != null) ''
        --set-default LOCALE_ARCHIVE ${glibcLocalesUtf8}/lib/locale/locale-archive
      '';
    in
    ''
      wrapProgram $out/bin/devenv \
        --prefix PATH ":" "$out/bin:${lib.getBin cachix}/bin:${lib.getBin nixd}/bin" \
        ${setDefaultLocaleArchive}

      wrapProgram $out/bin/devenv-run-tests \
        --prefix PATH ":" "$out/bin:${lib.getBin cachix}/bin:${lib.getBin nixd}/bin" \
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
    version = testers.testVersion {
      package = devenv;
      command = "export XDG_DATA_HOME=$PWD; devenv version";
    };
  };

  meta = {
    changelog = "https://github.com/cachix/devenv/releases";
    description = "Fast, Declarative, Reproducible, and Composable Developer Environments";
    homepage = "https://github.com/cachix/devenv";
    license = lib.licenses.asl20;
    mainProgram = "devenv";
    maintainers = with lib.maintainers; [
      domenkozar
      sandydoo
    ];
  };
}
