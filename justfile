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

# Restore flake.lock, then update every input except nixpkgs
update-held:
    git restore flake.lock
    nix flake update --flake . $(jq -r '.nodes.root.inputs | to_entries[] | select(.value | type == "string") | .key | select(startswith("nixpkgs-unstable") | not)' flake.lock)

# Print whether nixpkgs-hold.json still blocks the locked nixpkgs: none, held or released
hold-status:
    #!/usr/bin/env bash
    set -euo pipefail
    hold=nixpkgs-hold.json
    if [ ! -e "$hold" ]; then
      echo none
      exit 0
    fi
    rev=$(jq -er .rev "$hold")
    attr=$(jq -er .attr "$hold")
    stale=$(jq -er .stale "$hold")
    locked=$(jq -er '.nodes["nixpkgs-unstable"].locked.rev' flake.lock)
    if [ "$locked" = "$rev" ]; then
      echo held
      exit 0
    fi
    # A failed evaluation also counts as released: the switch then shows what is wrong.
    hash=$(nix eval --raw ".#nixosConfigurations.poita.pkgs.$attr.outputHash" || true)
    if [ "$hash" = "$stale" ]; then
      echo held
    else
      echo released
    fi

# Print whether the boost integrations match the packaged version: current or stale
boost-status:
    #!/usr/bin/env bash
    set -euo pipefail
    installed=$(sed -n 's/^# boost-skill-version: v//p' ~/.claude/rules/boost-awareness.md)
    packaged=$(sed -n 's/^  version = "\(.*\)";$/\1/p' packages/jfrog-boost/package.nix)
    if [ "$installed" = "$packaged" ]; then
      echo current
    else
      echo stale
    fi

# Compare the devenv pins with upstream, ending with `status: current` or `status: stale`
devenv-pins:
    #!/usr/bin/env bash
    set -euo pipefail
    pkg=packages/devenv/package.nix
    field() { sed -n "s/^ *$1 = \"\(.*\)\";.*/\1/p"; }
    src=$(grep -A4 '^  src = fetchFromGitHub' "$pkg")
    owner=$(field owner <<<"$src")
    rev=$(field rev <<<"$src")
    latest=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/cachix/devenv/releases/latest)
    main=$(GIT_TERMINAL_PROMPT=0 git ls-remote https://github.com/cachix/devenv.git HEAD | cut -f1)
    meta=$(nix flake metadata "github:$owner/devenv/$rev" --json)
    temp=$(git ls-remote --heads git@github.com:tarc/devenv.git '*-temp')
    status=current
    check() {
      if [ "$2" = "$3" ]; then
        printf '%-14s %s\n' "$1" "$2"
      else
        printf '%-14s %s (want %s)\n' "$1" "$2" "$3"
        status=stale
      fi
    }
    check owner "$owner" cachix
    check version "$(field version <"$pkg")" "${latest##*/tag/v}"
    check rev "$rev" "$main"
    check nix-version "$(field devenvNixVersion <"$pkg")" "$(jq -r '.locks.nodes.nix.original.ref' <<<"$meta" | sed 's/devenv-//')"
    check nix-rev "$(field devenvNixRev <"$pkg")" "$(jq -r '.locks.nodes.nix.locked.rev' <<<"$meta")"
    check ghostty "$(jq -r '.nodes.ghostty.locked.rev' flake.lock)" "$(jq -r '.locks.nodes.ghostty.locked.rev' <<<"$meta")"
    check temp-branches "$temp" ""
    echo "status: $status"

# Auto-format the project tree
fmt:
    treefmt
