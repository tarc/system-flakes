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
  devenvNixRev = "ab229d688f8402ef858ba69487e832075f7358e2";

  devenvNixSrc = fetchFromGitHub {
    name = "devenv-nix-${devenvNixVersion}-source";
    owner = "cachix";
    repo = "nix";
    rev = devenvNixRev;
    hash = "sha256-HBX0GszzUDIkPUL9dtNzhxeKBBJ2vyot3iIyyajEtmY=";
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
    rev = "6af962f65a11a6a0a785e3ec957cb4b75245e086";
    hash = "sha256-gq7TcA/Enyxw50ucuLZG8ocUWQro6sryMlAejEex0DY=";
  };

  cargoHash = "sha256-GZ8WB6x3MT9V7LpPXLuR8911kYtfBVdynXA3Yb02D2o=";

  # Link libghostty-vt dynamically: statically linking its Zig-built archive
  # fails with GCC 16 (`ld.bfd: .eh_frame_hdr refers to overlapping FDEs`).
  # Mirrors nixpkgs' devenv package.
  postPatch = ''
    substituteInPlace Cargo.toml \
      --replace-fail '"pkg-config",' '"pkg-config", "link-dynamic",'
  '';

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
