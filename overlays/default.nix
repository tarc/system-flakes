{
  systemFlakes,
  pkgs,
  inputs,
  ...
}:
let
  inherit (pkgs) callPackage;
  inherit (callPackage ../packages/devpod { }) devpod devpod-desktop;
  devenv = callPackage ../packages/devenv/package.nix { };
  jfrog-boost = callPackage ../packages/jfrog-boost/package.nix { inherit systemFlakes; };
in
{
  nixpkgs = {
    overlays = [
      # inputs.rust-overlay.overlays.default
      # (import ./devenv.nix { inherit systemFlakes; })
      (final: prev: {
        inherit devenv;
        inherit devpod devpod-desktop;
        inherit jfrog-boost;
        # nixpkgs' own libghostty-vt lags devenv's Cargo.lock (which bumps
        # the native library often, pre-1.0 with no ABI stability). Build
        # from the exact commit pinned by the `ghostty` input instead of
        # letting it drift and crash devenv at runtime with e.g. "terminal
        # error: invalid value" — see the `ghostty` input's comment in
        # flake.nix for how to keep this in sync.
        libghostty-vt = final.callPackage "${inputs.ghostty}/nix/libghostty-vt.nix" {
          optimize = "ReleaseSafe";
        };
      })
      # (import ./devenv-override-input.nix { inherit systemFlakes; })
      (import ./weechat.nix { inherit systemFlakes; })
      # (import ./auggie.nix { inherit systemFlakes; })
      (import ./embedme.nix { inherit systemFlakes; })
      (import ./mdsh.nix { inherit systemFlakes; })
    ];
  };
}
