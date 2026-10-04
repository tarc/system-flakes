#!/usr/bin/env bash
# Runs ci-local --fast on PR heads in temporary worktrees; prints a summary.
set -u
D=$HOME/.cache/ci-local
CI=$HOME/.claude/skills/ci-local/ci-local.sh
summary=$D/run-prs-summary.txt; : > "$summary"
run() { # repo-dir upstream-https-url pr
    local dir=$1 url=$2 pr=$3 name; name=$(basename "$dir")
    local wt=$D/wt/$name-$pr ref=refs/ci-local/pr-$pr
    GH_TOKEN=$GITHUB_TOKEN GIT_TERMINAL_PROMPT=0 git -C "$dir" -c credential.helper= -c 'credential.helper=!gh auth git-credential' \
        fetch -q "$url" "+pull/$pr/head:$ref" || { echo "$name#$pr FETCH-FAILED" >> "$summary"; return; }
    local sha; sha=$(git -C "$dir" rev-parse --short "$ref")
    git -C "$dir" worktree add -q --detach "$wt" "$ref"
    echo "##### $name#$pr ($sha)" >> "$summary"
    ( cd "$wt" && CI_LOCAL_TARGET=$dir/target/ci-local CI_LOCAL_LOGS=$D/$name-pr$pr "$CI" --fast 2>&1 ) |
        sed -n '/^JOB /,/^logs:/p' >> "$summary"
    git -C "$dir" worktree remove --force "$wt"
}
run ~/projects/gpui-ce https://github.com/gpui-ce/gpui-ce.git 288
run ~/projects/gpui-ce https://github.com/gpui-ce/gpui-ce.git 290
run ~/projects/gpui-component https://github.com/gpui-ce/gpui-component.git 5
for pr in 40 41 42 43 44 45 46 47 48 49; do run ~/projects/factorseal https://github.com/cachix/factorseal.git $pr; done
echo "ALL DONE" >> "$summary"
