flags := "--show-trace --accept-flake-config"

# Recipes record their outcome with this while a run report is open (see "Run reports" in CLAUDE.md)
record := "node scripts/run-report.mjs add --if-open"

default:
    @just --list

# Run `nixos-rebuild` with generic argument, leaving out unreachable substituters
[group('rebuild')]
nixos-rebuild COMMAND:
    #!/usr/bin/env bash
    set -uo pipefail
    live=""
    dead=""
    { read -r live; read -r dead; } < <(just live-substituters)
    opts=()
    skipped=""
    if [ -n "$live" ]; then
      opts=(--option substituters "$live")
      skipped=", leaving out unreachable $dead"
    fi
    log=$(mktemp)
    trap 'rm -f "$log"' EXIT
    before=$(readlink /run/current-system)
    start=$SECONDS
    sudo nixos-rebuild {{ COMMAND }} --flake .#poita --show-trace "${opts[@]}" 2>&1 | tee "$log"
    rc=${PIPESTATUS[0]}
    took=$((SECONDS - start))
    after=$(readlink /run/current-system)
    if [ "$rc" -eq 0 ]; then
      same=""
      if [ "{{ COMMAND }}" = switch ] && [ "$after" = "$before" ]; then same=", with the system path unchanged"; fi
      {{ record }} step "\`just {{ COMMAND }}\` succeeded in ${took}s$same$skipped" || true
      if [ "{{ COMMAND }}" = switch ]; then
        {{ record }} result "The system is on \`$(basename "$after" | cut -c1-7)…\` ($(basename "$after" | cut -d- -f2-))" || true
      fi
    else
      err=$(grep -m1 'error:' "$log" | cut -c1-240)
      {{ record }} step "\`just {{ COMMAND }}\` failed after ${took}s$skipped: ${err:-exit $rc}" || true
    fi
    exit "$rc"

# Rebuild-switch the system
[group('rebuild')]
switch: (nixos-rebuild 'switch')

# Rebuild-boot the system
[group('rebuild')]
boot: (nixos-rebuild 'boot')

# When a configured substituter doesn't answer: print the ones that do, then the ones that don't
live-substituters:
    #!/usr/bin/env bash
    set -uo pipefail
    live=()
    dead=()
    for s in $(nix config show substituters | tr ' ' '\n' | sed 's#/$##' | sort -u); do
      if curl -fsS -o /dev/null -m 5 "$s/nix-cache-info" 2>/dev/null; then live+=("$s"); else dead+=("$s"); fi
    done
    if [ ${#dead[@]} -gt 0 ]; then
      echo "leaving out unreachable substituters: ${dead[*]}" >&2
      echo "${live[*]}"
      echo "${dead[*]}"
    fi

# Update every flake input
update:
    #!/usr/bin/env bash
    set -uo pipefail
    out=$(nix flake update --flake . 2>&1)
    rc=$?
    printf '%s\n' "$out"
    moved=$(sed -n "s/.*Updated input '\([^']*\)'.*/\1/p" <<<"$out" | paste -sd, - | sed 's/,/, /g')
    if [ "$rc" -eq 0 ]; then
      {{ record }} step "\`just update\` moved: ${moved:-nothing}" || true
    else
      {{ record }} step "\`just update\` failed (exit $rc)" || true
    fi
    exit "$rc"

# Restore flake.lock, then update every input except nixpkgs
update-held:
    #!/usr/bin/env bash
    set -uo pipefail
    git restore flake.lock || exit
    inputs=$(jq -r '.nodes.root.inputs | to_entries[] | select(.value | type == "string") | .key | select(startswith("nixpkgs-unstable") | not)' flake.lock)
    # shellcheck disable=SC2086
    out=$(nix flake update --flake . $inputs 2>&1)
    rc=$?
    printf '%s\n' "$out"
    moved=$(sed -n "s/.*Updated input '\([^']*\)'.*/\1/p" <<<"$out" | paste -sd, - | sed 's/,/, /g')
    kept=$(jq -r '.nodes["nixpkgs-unstable"].locked.rev' flake.lock | cut -c1-7)
    if [ "$rc" -eq 0 ]; then
      {{ record }} step "\`just update-held\` kept nixpkgs at \`$kept\` and moved: ${moved:-nothing}" || true
    else
      {{ record }} step "\`just update-held\` failed (exit $rc)" || true
    fi
    exit "$rc"

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
    since=$(jq -r '.since // "?"' "$hold")
    note=$(jq -r '.note // empty' "$hold")
    fix=$(jq -r '.fix // empty' "$hold")
    locked=$(jq -er '.nodes["nixpkgs-unstable"].locked.rev' flake.lock)
    if [ "$locked" = "$rev" ]; then
      verdict=held
    else
      # A failed evaluation also counts as released: the switch then shows what is wrong.
      hash=$(nix eval --raw ".#nixosConfigurations.poita.pkgs.$attr.outputHash" || true)
      if [ "$hash" = "$stale" ]; then verdict=held; else verdict=released; fi
    fi
    echo "$verdict"
    far=""
    if [ -n "$fix" ] && [ "$locked" != "$rev" ]; then
      cmp=$(GH_TOKEN=${GITHUB_TOKEN:-} gh api "repos/NixOS/nixpkgs/compare/$locked...$fix" --jq '.status + " " + (.ahead_by|tostring)' 2>/dev/null || true)
      case "$cmp" in
        ahead*) far="; the fix \`${fix:0:7}\` is ${cmp#ahead } commits ahead of it" ;;
        behind* | identical*) far="; it contains the fix \`${fix:0:7}\`" ;;
      esac
    fi
    held_line="nixpkgs is held at \`${rev:0:7}\` since $since: \`$attr\` has a stale hash${note:+ ($note)}"
    if [ "$verdict" = held ]; then
      {{ record }} status:Nixpkgs 'hold still in effect' || true
      {{ record }} log:Nixpkgs "$held_line" || true
      if [ "$locked" = "$rev" ]; then
        {{ record }} log:Nixpkgs "nixpkgs-unstable hasn't moved past the held revision" || true
      else
        {{ record }} log:Nixpkgs "This run tried nixpkgs-unstable \`${locked:0:7}\`, which still has the stale hash$far" || true
      fi
    else
      {{ record }} log:Nixpkgs "This run tried nixpkgs-unstable \`${locked:0:7}\`: \`$attr\` no longer evaluates to the stale hash$far, so the switch tries it" || true
    fi

# For each package in nixpkgs-pins.json, print whether its pin can go: `<name> pinned` or `<name> releasable`
pin-status:
    #!/usr/bin/env bash
    set -euo pipefail
    pins=nixpkgs-pins.json
    if [ ! -e "$pins" ]; then
      echo none
      exit 0
    fi
    rev=$(jq -er .rev "$pins")
    since=$(jq -r '.since // "?"' "$pins")
    locked=$(jq -er '.nodes["nixpkgs-unstable"].locked.rev' flake.lock)
    system=$(nix eval --impure --raw --expr builtins.currentSystem)
    for name in $(jq -r '.packages | keys[]' "$pins"); do
      reason=$(jq -r --arg n "$name" '.packages[$n]' "$pins")
      if [ "$locked" = "$rev" ]; then
        # A lock at the pinned revision (a held nixpkgs) says nothing about newer ones.
        verdict=pinned
        why="the locked nixpkgs is the pinned revision itself, so there is nothing newer to check"
      else
        # The unpinned package of the locked nixpkgs, as cache.nixos.org builds it.
        out=$(nix eval --raw "github:NixOS/nixpkgs/$locked#legacyPackages.$system.$name.outPath" 2>/dev/null || true)
        if [ -z "$out" ]; then
          verdict=pinned
          why="it doesn't evaluate in nixpkgs \`${locked:0:7}\`"
        elif [ "$(curl -s -o /dev/null -w '%{http_code}' -m 20 "https://cache.nixos.org/$(basename "$out" | cut -d- -f1).narinfo")" = 200 ]; then
          verdict=releasable
          why="cache.nixos.org has \`$(basename "$out" | cut -d- -f2-)\` for nixpkgs \`${locked:0:7}\`"
        else
          verdict=pinned
          why="cache.nixos.org has no \`$(basename "$out" | cut -d- -f2-)\` for nixpkgs \`${locked:0:7}\` yet"
        fi
      fi
      echo "$name $verdict"
      if [ "$verdict" = pinned ]; then
        {{ record }} status:Pins 'pins still in effect' || true
        {{ record }} log:Pins "\`$name\` stays pinned to nixpkgs \`${rev:0:7}\` since $since ($reason): $why" || true
      else
        {{ record }} log:Pins "\`$name\` can leave its pin to nixpkgs \`${rev:0:7}\`: $why" || true
      fi
    done

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
    verdict=current
    moved=()
    check() {
      if [ "$2" = "$3" ]; then
        printf '%-14s %s\n' "$1" "$2"
      else
        printf '%-14s %s (want %s)\n' "$1" "$2" "$3"
        verdict=stale
        moved+=("$1")
      fi
    }
    nix_version=$(field devenvNixVersion <"$pkg")
    ghostty=$(jq -r '.nodes.ghostty.locked.rev' flake.lock)
    check owner "$owner" cachix
    check version "$(field version <"$pkg")" "${latest##*/tag/v}"
    check rev "$rev" "$main"
    check nix-version "$nix_version" "$(jq -r '.locks.nodes.nix.original.ref' <<<"$meta" | sed 's/devenv-//')"
    check nix-rev "$(field devenvNixRev <"$pkg")" "$(jq -r '.locks.nodes.nix.locked.rev' <<<"$meta")"
    check ghostty "$ghostty" "$(jq -r '.locks.nodes.ghostty.locked.rev' <<<"$meta")"
    check temp-branches "$temp" ""
    echo "status: $verdict"
    if [ "$verdict" = current ]; then
      {{ record }} step "\`just devenv-pins\`: devenv \`${rev:0:7}\`, its nix $nix_version and Ghostty \`${ghostty:0:7}\` are all current, so the sub-commands were skipped" || true
    else
      {{ record }} step "\`just devenv-pins\`: stale (${moved[*]}), so the sub-commands run" || true
    fi

# Garbage-collect the devenv store, then format the tree; the README's commands collect the system's garbage (see /gc)
gc:
    #!/usr/bin/env bash
    set -uo pipefail
    gcout=$(devenv gc --no-tui 2>&1)
    rc=$?
    printf '%s\n' "$gcout"
    if [ "$rc" -ne 0 ]; then
      {{ record }} step "\`devenv gc\` failed (exit $rc)" || true
      exit "$rc"
    fi
    summary=$(grep -a -m1 -oE 'Deleted [0-9]+ store paths, freed [^.]*' <<<"$gcout" | sed 's/^Deleted/deleted/' || true)
    live=""
    dead=""
    { read -r live; read -r dead; } < <(just live-substituters)
    touch README.md
    if [ -n "$live" ]; then NIX_CONFIG="substituters = $live" nix fmt; else nix fmt; fi
    rc=$?
    if [ "$rc" -ne 0 ]; then
      {{ record }} step "\`nix fmt\` failed (exit $rc)" || true
      exit "$rc"
    fi
    freed=$(grep -E 'store paths deleted' README.md | sed 's/ store paths deleted, / paths, /; s/ freed$//' | paste -sd ';' - | sed 's/;/; /g')
    {{ record }} step "\`just gc\`: \`devenv gc\` ${summary:-printed no summary}; the README's garbage collections (user, then root) freed ${freed:-nothing}" || true

# Keep a run report for a custom command: new, add, close, render or list (see CLAUDE.md)
[positional-arguments]
report *ARGS:
    @node scripts/run-report.mjs "$@"

# Auto-format the project tree
fmt:
    treefmt
