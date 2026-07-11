{
  description = "NixOS/nix-darwin/home-manager configuration using Nix Flakes.";

  outputs =
    { flake-parts, ... }@inputs:
    let
      lib = import ./lib/system-flakes.nix { inherit inputs; };
    in
    flake-parts.lib.mkFlake { inherit inputs; } (
      { flake-parts-lib, ... }: {

        imports = [
          inputs.ez-configs.flakeModule
        ];

        options = {
          perSystem = flake-parts-lib.mkPerSystemOption (
            {
              config,
              pkgs,
              lib,
              ...
            }:
            {
              options.treefmt = lib.mkOption {
                type = inputs.treefmt-nix.lib.submoduleWith lib {
                  modules = [
                    {
                      options.pkgs = lib.mkOption {
                        default = pkgs;
                      };
                      options.flakeFormatter = lib.mkOption {
                        type = lib.types.bool;
                        default = true;
                      };
                      config.projectRootFile = lib.mkDefault "flake.nix";
                    }
                  ];
                };
                default = { };
              };
              config = {
                formatter = lib.mkIf config.treefmt.flakeFormatter (lib.mkDefault config.treefmt.build.wrapper);
              };
            }
          );
        };

        config = {
          debug = true;

          ezConfigs = {
            root = ./.;
            globalArgs = {
              inherit inputs;
              inherit (lib) systemFlakes;
            };
            nixos.hosts.poita.userHomeModules = [ "tarci" ];
          };

          flake = {
            lib = {
              inherit (lib) systemFlakes;
            };
          };

          systems = import inputs.systems;

          perSystem =
            {
              pkgs,
              system,
              ...
            }:
            {
              treefmt.config = {
                projectRootFile = "README.md";
                programs = {
                  # clang-format.enable = true;
                  cmake-format.enable = true;
                  alejandra.enable = false;
                  nixfmt.enable = true;
                  deadnix = {
                    enable = true;
                    no-lambda-pattern-names = true;
                    no-lambda-arg = true;
                  };
                  mdformat.enable = true;
                  just.enable = true;
                  mdsh.enable = true;
                };
              };

              _module.args.pkgs = import inputs.nixpkgs {
                inherit system;
                overlays = [
                  (
                    _: prev:
                    let
                      name = "mdsh";
                      version = "0.9.3";
                      versionHash = "sha256-W9znh93RokghlqIjRRjIUJmkXxUAtLZtpZfGceTPK14=";
                      versionCargoHash = "sha256-JbmHwAn3oXUUXsiQgCcZSBBS9o9Kam66MWHnbo25Fxg=";
                      src = prev.fetchFromGitHub {
                        owner = "tarc";
                        repo = name;
                        # tag = "v${version}";
                        rev = "cd7d2374b551fbe5bf02367398cf6d6b140fca38";
                        hash = versionHash;
                      };
                    in
                    {
                      mdsh = prev.mdsh.overrideAttrs (_: rec {
                        inherit version src;
                        cargoDeps = prev.rustPlatform.fetchCargoVendor {
                          inherit src;
                          name = "${name}-${version}-vendor";
                          hash = versionCargoHash;
                        };
                      });
                    }
                  )
                ];
                config = { };
              };

              devShells.default = pkgs.mkShell {
                packages = with pkgs; [
                  just
                ];
                shellHook = ''
                  echo
                  echo "🍎🍎 Run 'just <recipe>' to get started"
                  just
                '';
                env = {
                  LD_LIBRARY_PATH = "/usr/lib/wsl/lib";
                  MESA_D3D12_DEFAULT_ADAPTER_NAME = "NVIDIA";
                  GALLIUM_DRIVER = "d3d12";
                };
              };
            };
        };
      }
    );

  inputs = {
    ### -- nixpkgs
    # nixos-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # nixos-unstable-lib.url = "github:NixOS/nixpkgs/nixos-unstable?dir=lib";
    # nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    # nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";
    # nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-24.11-darwin";
    # nixpkgs-darwin-lib.url = "github:NixOS/nixpkgs/nixpkgs-24.11-darwin?dir=lib";
    # nixos-26-05.url = "github:NixOS/nixpkgs/nixos-26.05";
    # nixos-26-05-lib.url = "github:NixOS/nixpkgs/nixos-26.05?dir=lib";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-unstable-lib.url = "github:NixOS/nixpkgs/nixpkgs-unstable?dir=lib";

    # Inputs
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    flake-parts.url = "github:hercules-ci/flake-parts";
    ez-configs.url = "github:ehllie/ez-configs";
    # home-manager-pinned.url = "github:nix-community/home-manager?rev=f09af49406ffad37acb6538d3207189a1a1e0b7e";
    home-manager-master.url = "github:nix-community/home-manager";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    systems.url = "github:nix-systems/default";
    agenix.url = "github:ryantm/agenix";
    rust-overlay.url = "github:oxalica/rust-overlay";

    # Non flake inputs
    secrets.url = "git+ssh://git@github.com/tarc/nix-secrets.git";
    secrets.flake = false;

    # Select defaults
    nixpkgs.follows = "nixpkgs-unstable";
    nixpkgs-lib.follows = "nixpkgs-unstable-lib";
    home-manager.follows = "home-manager-master";

    # Minimize duplicate instances of inputs
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs-lib";
    ez-configs.inputs.nixpkgs.follows = "nixpkgs";
    ez-configs.inputs.flake-parts.follows = "flake-parts";
    # home-manager-pinned.inputs.nixpkgs.follows = "nixpkgs";
    home-manager-master.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.darwin.follows = "nix-darwin";
    agenix.inputs.home-manager.follows = "home-manager";
    agenix.inputs.systems.follows = "systems";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };
}
