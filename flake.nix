{
  description = "NixOS/nix-darwin/home-manager configuration using Nix Flakes.";

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.ez-configs.flakeModule
        inputs.treefmt-nix.flakeModule
      ];

      ezConfigs = {
        root = ./.;
        globalArgs = { inherit inputs; };
        nixos.hosts.poita.userHomeModules = [ "tarci" ];
      };

      systems = import inputs.systems;

      perSystem =
        {
          pkgs,
          lib,
          config,
          ...
        }:
        {
          treefmt.config = {
            projectRootFile = "README.md";
            programs = {
              clang-format.enable = true;
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
            };
          };
          devShells.default = pkgs.mkShell {
            inputsFrom = [
              config.treefmt.build.devShell
            ];
            packages = with pkgs; [
              just
              nil
            ];
            TREEFMT_CONFIG_FILE = config.treefmt.build.configFile;
            shellHook = ''
              echo
              echo "🍎🍎 Run 'just <recipe>' to get started"
              just
            '';
          };
        };
    };

  inputs = {
    ### -- nixpkgs
    # nixos-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # nixos-unstable-lib.url = "github:NixOS/nixpkgs/nixos-unstable?dir=lib";
    # nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    # nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";
    # nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-24.11-darwin";
    # nixpkgs-darwin-lib.url = "github:NixOS/nixpkgs/nixpkgs-24.11-darwin?dir=lib";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-unstable-lib.url = "github:NixOS/nixpkgs/nixpkgs-unstable?dir=lib";

    # Inputs
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    flake-parts.url = "github:hercules-ci/flake-parts";
    ez-configs.url = "github:ehllie/ez-configs";
    home-manager.url = "github:nix-community/home-manager";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    systems.url = "github:nix-systems/default";
    agenix.url = "github:ryantm/agenix";

    # Non flake inputs
    secrets.url = "git+ssh://git@github.com/tarc/nix-secrets.git";
    secrets.flake = false;

    # Default nixpkgs
    nixpkgs.follows = "nixpkgs-unstable";
    nixpkgs-lib.follows = "nixpkgs-unstable-lib";

    # Minimize duplicate instances of inputs
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs-lib";
    ez-configs.inputs.nixpkgs.follows = "nixpkgs";
    ez-configs.inputs.flake-parts.follows = "flake-parts";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    agenix.inputs.darwin.follows = "nix-darwin";
    agenix.inputs.home-manager.follows = "home-manager";
    agenix.inputs.systems.follows = "systems";
  };
}
