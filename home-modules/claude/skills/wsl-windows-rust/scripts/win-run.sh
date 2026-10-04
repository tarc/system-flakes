#!/usr/bin/env bash
# Mirrors a WSL checkout to a Windows-local copy and runs a command there
# through PowerShell, with the Windows Rust (MSVC) toolchain.
#
#   win-run.sh [options] -- <powershell command...>
#
#   --src DIR       WSL directory to mirror (default: git root of $PWD)
#   --tree DIR      Windows copy, as a WSL path
#                   (default: %USERPROFILE%\Projects\<basename of --src>)
#   --exclude-dir D extra directory to skip when mirroring (repeatable)
#   --no-mirror     run in the existing copy without mirroring first
#   --print-tree    print the Windows copy's WSL and Windows paths and exit
#
# Examples:
#   win-run.sh -- cargo check --workspace
#   win-run.sh -- cargo test -p mycrate --lib
#   win-run.sh --no-mirror -- 'Get-ChildItem target\debug'
#
# The command's exit code is returned. Windows locks running .exe files, so
# stop any binary the command rebuilds first.
set -euo pipefail

src='' tree='' mirror=yes print_tree=no
excludes=(.git target .claude .devenv .direnv node_modules result)
while [ $# -gt 0 ]; do
    case $1 in
        --src) src=$2; shift 2 ;;
        --tree) tree=$2; shift 2 ;;
        --exclude-dir) excludes+=("$2"); shift 2 ;;
        --no-mirror) mirror=no; shift ;;
        --print-tree) print_tree=yes; shift ;;
        --) shift; break ;;
        *) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
    esac
done

src=${src:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}
src=$(cd "$src" && pwd)
if [ -z "$tree" ]; then
    profile=$(wslpath "$(cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')")
    tree=$profile/Projects/$(basename "$src")
fi
if [ "$print_tree" = yes ]; then
    echo "$tree"
    wslpath -w "$tree"
    exit 0
fi
[ $# -gt 0 ] || { echo "win-run.sh: no command given (use -- <command>)" >&2; exit 2; }

if [ "$mirror" = yes ]; then
    mkdir -p "$tree"
    echo "win-run: mirroring $src -> $(wslpath -w "$tree")" >&2
    # Windows can't follow WSL symlinks (robocopy fails on them with error 3),
    # so robocopy skips them (/XJF /XJD) and file links are copied
    # dereferenced afterwards.
    prune=()
    for d in "${excludes[@]}"; do prune+=(-name "$d" -o); done
    mapfile -t links < <(cd "$src" && find . \( "${prune[@]}" -false \) -prune -o -type l -print | sed 's|^\./||')
    set +e
    # /R:1 /W:1: never let one unreadable file stall robocopy (its default is
    # a million retries).
    /mnt/c/Windows/System32/robocopy.exe "$(wslpath -w "$src")" "$(wslpath -w "$tree")" \
        /MIR /XD "${excludes[@]}" /XF .mcp.json /XJF /XJD /R:1 /W:1 \
        /NJH /NJS /NDL /NP /NFL >/dev/null
    copied=$?
    set -e
    # Robocopy exit codes below 8 mean success.
    [ "$copied" -lt 8 ] || { echo "win-run: robocopy failed ($copied)" >&2; exit 1; }
    for l in "${links[@]}"; do
        if [ -f "$src/$l" ]; then
            mkdir -p "$tree/$(dirname "$l")" && cp -L --preserve=timestamps "$src/$l" "$tree/$l"
        elif [ -e "$src/$l" ]; then
            echo "win-run: skipped symlinked directory $l" >&2
        fi # dangling links (e.g. into a missing /nix/store path) are dropped
    done
fi

# Native stderr arrives in PowerShell as ErrorRecords; print their text only.
powershell.exe -NoProfile -Command "
    Set-Location '$(wslpath -w "$tree")'
    $* 2>&1 | ForEach-Object {
        if (\$_ -is [System.Management.Automation.ErrorRecord]) { \$_.Exception.Message } else { \$_ }
    }
    exit \$LASTEXITCODE" | tr -d '\r'
exit "${PIPESTATUS[0]}"
