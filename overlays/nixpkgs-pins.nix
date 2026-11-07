# Packages taken from an older nixpkgs revision, as listed in
# nixpkgs-pins.json (see "Pinning packages to an older nixpkgs" in
# CLAUDE.md). Without that file this overlay changes nothing.
{ ... }:
_final: prev:
let
  inherit (prev) lib;
  file = ../nixpkgs-pins.json;
in
lib.optionalAttrs (builtins.pathExists file) (
  let
    pins = lib.importJSON file;
    src = builtins.fetchTree {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      inherit (pins) rev narHash;
    };
    pinned = import src { inherit (prev.stdenv.hostPlatform) system; };
  in
  lib.mapAttrs (name: _: pinned.${name}) pins.packages
)
