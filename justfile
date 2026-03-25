flags := "--show-trace --accept-flake-config"
override := "--override-input conan-flake ../.."

default:
    @just --list

# Rebuild the system
rebuild:
    sudo nixos-rebuild switch --flake .#poita --show-trace

# Rebuild the system
update:
    nix flake update --flake .

# Auto-format the project tree
fmt:
    treefmt
