#!/usr/bin/env bash
# Runs a repository's GitHub Actions CI jobs locally, from its own workflow
# file, before a push.
#
#   ci-local.sh [--fast | --full | --jobs a,b] [--list] [--workflow FILE]
#
#   --fast       (default) the lint-only jobs: jobs whose commands are all
#                cargo fmt/clippy/check/machete, typos, or just recipes for
#                them (fmt-check, clippy, msrv-check, ...). They run here on
#                Linux even when CI runs them on macOS or Windows.
#   --full       every job this machine can run: Linux jobs here, Windows
#                jobs natively through the wsl-windows-rust skill, macOS
#                lint-only jobs on Linux; other macOS jobs are skipped. A
#                matrix job runs its Linux entry.
#   --jobs a,b   just these jobs
#   --list       print the jobs, where they'd run, and their commands
#
# Each job runs the workflow's own one-line `run:` steps that call `just`,
# `cargo` or `typos` (a leading `devenv shell -- ` is dropped, since the
# script already runs in the repo's dev shell), replays `rustup` setup steps,
# and runs `typos` for the crate-ci/typos action. Multi-line scripts (apt-get,
# CI plumbing) and `cargo install` steps are skipped. Toolchain: the
# setup-rust-toolchain `toolchain:` input, or the current stable version,
# installed side by side so the user's `stable` is not touched. Jobs using
# that action get its default RUSTFLAGS="-D warnings" unless `rustflags:`
# overrides it. Jobs whose commands already ran in this pass are skipped.
#
# Env: CI_LOCAL_LOGS    log directory (default ~/.cache/ci-local/<repo>)
#      CI_LOCAL_TARGET  build directory (default <repo>/target/ci-local); point
#                       worktrees of one repo at a shared one to reuse the cache
set -uo pipefail

mode=fast only='' list=no workflow=.github/workflows/ci.yml
while [ $# -gt 0 ]; do
    case $1 in
        --fast) mode=fast; shift ;;
        --full) mode=full; shift ;;
        --jobs) mode=jobs; only=",$2,"; shift 2 ;;
        --list) list=yes; shift ;;
        --workflow) workflow=$2; shift 2 ;;
        *) sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
    esac
done

repo=$(git rev-parse --show-toplevel) || exit 2
cd "$repo"
[ -f "$workflow" ] || { echo "ci-local: no $workflow in $repo" >&2; exit 2; }
name=$(basename "$repo")
logs=${CI_LOCAL_LOGS:-$HOME/.cache/ci-local/$name}
win_run=$HOME/.claude/skills/wsl-windows-rust/scripts/win-run.sh
export CARGO_TARGET_DIR=${CI_LOCAL_TARGET:-$repo/target/ci-local}

# Everything below runs inside the repo's dev shell: the one the workflow
# itself uses (devenv when its steps call `devenv shell`), else the flake's.
if [ -z "${CI_LOCAL_IN_SHELL:-}" ]; then
    export CI_LOCAL_IN_SHELL=1
    args=(--workflow "$workflow")
    [ "$list" = yes ] && args+=(--list)
    case $mode in
        fast) args+=(--fast) ;;
        full) args+=(--full) ;;
        jobs) args+=(--jobs "${only:1:${#only}-2}") ;;
    esac
    if [ -f devenv.nix ] && grep -q 'devenv shell' "$workflow"; then
        exec devenv shell -- bash "$(realpath "$0")" "${args[@]}"
    elif [ -f flake.nix ]; then
        exec nix develop "$repo" --command bash "$(realpath "$0")" "${args[@]}"
    elif [ -f devenv.nix ]; then
        exec devenv shell -- bash "$(realpath "$0")" "${args[@]}"
    fi
fi

# --- Parse the workflow: one line per step ----------------------------------
# yq-go's @tsv neither escapes newlines nor leaves quotes alone, so fields are
# sanitized by hand (tab -> space, newline -> literal \n) and joined.
yq() { if type -P yq >/dev/null; then command yq "$@"; else nix shell nixpkgs#yq-go --command yq "$@"; fi; }
steps=$(yq -r '
  .jobs | to_entries | .[] | .key as $job | (.value."runs-on" | tostring) as $os |
  .value.steps[] |
  [ ($job), ($os),
    ((.run // "") | tostring | sub("\t"; " ") | sub("\n"; "\\n")),
    ((.uses // "") | tostring),
    ((.with.toolchain // "") | tostring),
    ((.with.rustflags // "-") | tostring)
  ] | join("\t")' "$workflow") || { echo "ci-local: could not parse $workflow" >&2; exit 2; }
# Normalize to: job, os, kind (run|uses), value, toolchain, rustflags, where
# the last two are set only on actions-rust-lang/setup-rust-toolchain steps
# (its defaults: toolchain "stable", rustflags "-D warnings").
steps=$(printf '%s\n' "$steps" | awk -F'\t' -v OFS='\t' '
    { kind = ($3 != "") ? "run" : "uses"; value = ($3 != "") ? $3 : $4; tc = ""; rf = ""
      if ($4 ~ /setup-rust-toolchain/) { tc = ($5 != "") ? $5 : "stable"; rf = ($6 != "-") ? $6 : "-D warnings" }
      print $1, $2, kind, value, tc, rf }')

jobs=$(printf '%s\n' "$steps" | cut -f1 | awk '!seen[$0]++')

lint_re='^(cargo (\+[^ ]+ )?(fmt|clippy|check|machete)( |$)|typos( |$)|just (fmt-check|clippy|typos|machete|msrv-check|lint|check)( |$))'

stable_version() { # the current stable release, as CI's "stable" resolves
    curl -fsS https://static.rust-lang.org/dist/channel-rust-stable.toml 2>/dev/null |
        sed -n '/^\[pkg.rust\]/,/^\[/s/^version = "\([0-9]*\.[0-9]*\)\..*/\1/p' | head -1
}
resolve_toolchain() {
    case $1 in
        stable|'') v=$(stable_version); echo "${v:-stable}" ;;
        *) echo "$1" ;;
    esac
}
ensure_toolchain() { # $1 toolchain; installs it side by side with clippy and rustfmt
    if rustup toolchain list | grep -q "^$1"; then
        rustup component add --toolchain "$1" clippy rustfmt >&2
    else
        rustup toolchain install "$1" --profile minimal -c clippy -c rustfmt >&2
    fi
}

job_commands() { # $1 job -> lines "cmd|setup<TAB>value" for runnable steps
    printf '%s\n' "$steps" | J="$1" awk -F'\t' '$1 == ENVIRON["J"]' |
    while IFS=$'\t' read -r _ _ kind value _ _; do
        if [ "$kind" = uses ]; then
            case $value in crate-ci/typos*) printf 'cmd\ttypos\n' ;; esac
            continue
        fi
        case $value in *'\n'*) continue ;; esac # multi-line script: skipped
        value=${value#devenv shell -- }
        case $value in
            cargo\ install\ *) ;; # tool installs: the dev shell provides tools
            just\ *|cargo\ *|typos*) printf 'cmd\t%s\n' "$value" ;;
            rustup\ *) printf 'setup\t%s\n' "$value" ;;
        esac
    done
}
job_meta() { # $1 job -> "os<TAB>toolchain<TAB>rustflags"
    printf '%s\n' "$steps" | J="$1" awk -F'\t' '
        $1 == ENVIRON["J"] { os = $2; if ($5 != "") { tc = $5; rf = $6; set = 1 } }
        END { printf "%s\t%s\t%s\n", os, (set ? tc : ""), (set ? rf : "") }'
}
resolve_os() { # $1 job, $2 runs-on -> a concrete runner label
    if [[ $2 =~ matrix\.([A-Za-z0-9_-]+) ]]; then
        key=${BASH_REMATCH[1]}
        # yq-go has no `empty`: query the include list and the plain list apart.
        all=$( { J="$1" K="$key" yq -r '.jobs[strenv(J)].strategy.matrix.include[] | .[strenv(K)]' "$workflow"
                 J="$1" K="$key" yq -r '.jobs[strenv(J)].strategy.matrix[strenv(K)][]' "$workflow"; } 2>/dev/null |
               grep -v '^null$')
        pick=$(printf '%s\n' "$all" | grep -m1 ubuntu || printf '%s\n' "$all" | head -1)
        echo "${pick:-$2} (matrix)"
    else
        echo "$2"
    fi
}
lint_only() { # stdin: job_commands output -> 0 if every command is a lint
    local any=1
    while IFS=$'\t' read -r kind value; do
        [ "$kind" = cmd ] || continue
        any=0
        [[ $value =~ $lint_re ]] || return 1
    done
    return $any
}
# Where a job runs: linux, windows, or skip (with a reason).
placement() { # $1 os, $2 lint-only (0/1)
    case $mode in
        fast) [ "$2" = 0 ] && echo linux || echo skip ;;
        *)
            if [[ $1 == *windows* ]]; then echo windows
            elif [[ $1 == *macos* ]]; then [ "$2" = 0 ] && echo linux || echo skip
            else echo linux; fi ;;
    esac
}

declare -A plan_cmds plan_os plan_where plan_tc plan_rf
for job in $jobs; do
    cmds=$(job_commands "$job")
    [ -n "$cmds" ] || continue
    IFS=$'\t' read -r os tc rf <<<"$(job_meta "$job")"
    os=$(resolve_os "$job" "$os")
    printf '%s\n' "$cmds" | lint_only; lint=$?
    where=$(placement "$os" "$lint")
    # Commands that interpolate ${{ ... }} (matrix values, secrets) can't run here.
    case $cmds in *'${{'*) where=skip-expr ;; esac
    [ "$mode" = jobs ] && { [[ $only == *",$job,"* ]] || where=skip; [ "$where" = skip ] || [[ $os != *macos* ]] || [ "$lint" = 0 ] || where=skip; }
    plan_cmds[$job]=$cmds plan_os[$job]=$os plan_where[$job]=$where plan_tc[$job]=$tc plan_rf[$job]=$rf
done

if [ "$list" = yes ]; then
    for job in $jobs; do
        [ -n "${plan_cmds[$job]:-}" ] || continue
        cmds=$(printf '%s\n' "${plan_cmds[$job]}" | cut -f2 | paste -sd ';' -)
        printf '%-8s %-20s CI:%-24s toolchain=%-7s %s\n' "${plan_where[$job]}" "$job" "${plan_os[$job]}" "${plan_tc[$job]:--}" "$cmds"
    done
    echo "(first column: where this mode runs the job; skip = not in this mode or not runnable here)"
    exit 0
fi

mkdir -p "$logs"
results=() failed=0
declare -A done_sets
for job in $jobs; do
    [ -n "${plan_cmds[$job]:-}" ] || continue
    where=${plan_where[$job]} os=${plan_os[$job]} cmds=${plan_cmds[$job]}
    [ "$where" = skip-expr ] && { results+=("$job|skipped|0|its commands use \${{ }} expressions (matrix, secrets)"); continue; }
    [ "$where" = skip ] && { [[ $os == *macos* && $mode == full ]] && results+=("$job|skipped|0|macOS-only test job; CI runs it"); continue; }
    # No setup-rust-toolchain step: use whatever the dev shell provides, as
    # CI does with its preinstalled or devenv-provided Rust.
    toolchain=''
    [ -n "${plan_tc[$job]}" ] && toolchain=$(resolve_toolchain "${plan_tc[$job]}")
    rf=${plan_rf[$job]}
    key="$where|$toolchain|$rf|$cmds"
    if [ -n "${done_sets[$key]:-}" ]; then
        results+=("$job|same|0|same commands as ${done_sets[$key]}")
        continue
    fi
    done_sets[$key]=$job
    note=''
    [ "$where" = linux ] && [[ $os != *ubuntu* ]] && note="CI runs it on $os; checked on Linux"
    [[ $os == *"(matrix)"* ]] && note="matrix: ran the $os entry only"
    log=$logs/$job.log
    start=$(date +%s)
    echo "ci-local: $job ($where, toolchain ${toolchain:-dev shell}${rf:+, RUSTFLAGS=$rf})" >&2
    status=pass
    (
        if [ "$where" = windows ]; then
            # Expand just recipes here and run the cargo lines natively.
            winlines=()
            while IFS=$'\t' read -r kind value; do
                [ "$kind" = cmd ] || continue
                if [[ $value == just\ * ]]; then
                    mapfile -t -O "${#winlines[@]}" winlines < <(just --dry-run ${value#just } 2>&1 | grep -E '^(cargo|rustup) ')
                else
                    winlines+=("$value")
                fi
            done <<<"$cmds"
            ps="\$env:RUSTUP_TOOLCHAIN='$toolchain'; \$env:CARGO_TARGET_DIR='target\\ci-local';"
            [ -n "$rf" ] && ps+=" \$env:RUSTFLAGS='$rf';"
            ps+=" rustup toolchain install $toolchain --profile minimal -c clippy -c rustfmt 2>&1 | Out-Null;"
            for line in "${winlines[@]}"; do ps+=" $line; if (\$LASTEXITCODE -ne 0) { exit \$LASTEXITCODE };"; done
            "$win_run" -- "$ps"
        else
            if [ -n "$toolchain" ]; then ensure_toolchain "$toolchain"; export RUSTUP_TOOLCHAIN=$toolchain; else unset RUSTUP_TOOLCHAIN; fi
            if [ -n "$rf" ]; then export RUSTFLAGS=$rf; else unset RUSTFLAGS; fi
            while IFS=$'\t' read -r kind value; do
                [ -n "$value" ] || continue
                # rustup setup steps name their own toolchain (e.g. nightly); a
                # bare `rustup target add` applies to this job's toolchain.
                [ "$kind" = cmd ] && echo "+ $value"
                # A tool CI installs with an action (typos, cargo-machete, ...)
                # may be missing from the dev shell: borrow it from nixpkgs.
                need=''
                read -r w1 w2 _ <<<"$value"
                case $w1 in
                    cargo) case $w2 in fmt|clippy|check|build|test|run|doc|metadata|install|+*|-*|'') ;;
                               *) need=cargo-$w2 ;; esac ;;
                    just|rustup|bash|sh|echo) ;;
                    *) need=$w1 ;;
                esac
                if [ -n "$need" ] && ! type -P "$need" >/dev/null; then
                    echo "+ ($need not in the dev shell: running via nix shell nixpkgs#$need)"
                    nix shell "nixpkgs#$need" --command bash -c "$value" || exit 1
                else
                    bash -c "$value" || exit 1
                fi
            done <<<"$cmds"
        fi
    ) >"$log" 2>&1 || status=fail
    secs=$(( $(date +%s) - start ))
    if [ $status = fail ]; then
        failed=1
        why=$(sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -m3 -E '^(error|warning:|Diff in|FAILED|thread .* panicked)|could not compile|recipe .* failed' | tr '\n' ' ')
        results+=("$job|FAIL|$secs|${why:-see $log}${note:+ ($note)}")
    else
        results+=("$job|pass|$secs|$note")
    fi
done

echo
printf '%-22s %-7s %6s  %s\n' JOB RESULT TIME NOTE
for r in "${results[@]}"; do
    IFS='|' read -r job st secs note <<<"$r"
    printf '%-22s %-7s %5ss  %s\n' "$job" "$st" "$secs" "$note"
done
[ "$mode" = fast ] && echo "(fast mode: lint-only jobs; tests, builds, examples and Windows run with --full)"
echo "logs: $logs"
exit $failed
