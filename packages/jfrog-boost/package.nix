{
  lib,
  autoPatchelfHook,
  fetchurl,
  glibc,
  stdenv,
  zlib,
  systemFlakes,
}:
let
  pname = "jfrog-boost";
  version = "0.13.7";
  system = stdenv.hostPlatform.system;
  systemSplit = lib.strings.splitString "-" system;
  arch = builtins.head systemSplit;
  os = builtins.head (builtins.tail systemSplit);
  arch' =
    if arch == "x86_64" then
      "amd64"
    else if arch == "aarch64" then
      "arm64"
    else
      arch;
in
stdenv.mkDerivation (finalAttrs: {
  inherit pname version;

  src = fetchurl {
    url = "https://github.com/jfrog/boost/releases/download/v${version}/boost-${os}-${arch'}.tar.gz";
    hash = "sha256-L16L+180EIaDfal91xIapVO5Ane4m2PRGwsz4ahXh+U=";
  };

  sourceRoot = ".";

  buildInputs = [
    stdenv.cc.cc.lib # Common C++ standard library
    zlib
    glibc
  ];

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    cp boost $out/bin/
    cp boost-ci $out/bin/

    chmod +x $out/bin/boost
    chmod +x $out/bin/boost-ci

    runHook postInstall
  '';

  meta = {
    homepage = "https://github.com/jfrog/boost";
    description = "Save tokens. Maximize context, Safely";
    changelog = "https://github.com/jfrog/boost/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "boost";
    maintainers = with systemFlakes.maintainers; [
      tarc
    ];
  };
})
