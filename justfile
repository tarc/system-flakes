flags := "--show-trace --accept-flake-config"

default:
    @just --list

# Run `nixos-rebuild` with generic argument
[group('rebuild')]
nixos-rebuild COMMAND:
    sudo nixos-rebuild {{ COMMAND }} --flake .#poita --show-trace

# Rebuild-switch the system
[group('rebuild')]
switch: (nixos-rebuild 'switch')

# Rebuild-boot the system
[group('rebuild')]
boot: (nixos-rebuild 'boot')

# Rebuild the system
update:
    nix flake update --flake .

# Auto-format the project tree
fmt:
    treefmt
