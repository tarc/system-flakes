#!/usr/bin/env bash
# Collects the GitHub PRs and issues involving a user in the tracked repos and
# writes one JSON document per item, ready for the dashboard artifact's db
# (ArtifactData batch with file_path entries).
#
#   sync.sh [OUT_DIR]        default OUT_DIR: ./gh-tracker-out
#
# Config, next to this script:
#   repos.txt   one owner/repo per line (# comments allowed)
#   notes.json  {"owner/repo#N": {"note": "...", "related": ["owner/repo#M"]}}
#               plus optional "local" entries for branches without a PR yet:
#               {"local": [{"id": "...", "repo": "...", "title": "...", "branch": "...", "note": "..."}]}
# Env: GITHUB_TOKEN (classic token), TRACK_USER (default tarc),
#      TRACK_SINCE (default: 60 days ago, YYYY-MM-DD).
set -euo pipefail

# node does the JSON merging; borrow it from nixpkgs when absent. `nix shell`
# leaves no GC root and needs no runtime directory (an ad-hoc devenv shell
# did both, and fails where /run/user is not writable).
if ! command -v node >/dev/null; then
    exec nix shell nixpkgs#nodejs --command bash "$(realpath "$0")" "$(realpath -m "${1:-./gh-tracker-out}")"
fi

here=$(cd "$(dirname "$0")" && pwd)
out=${1:-./gh-tracker-out}
user=${TRACK_USER:-tarc}
since=${TRACK_SINCE:-$(date -u -d '60 days ago' +%F)}
export GH_TOKEN=${GITHUB_TOKEN:?GITHUB_TOKEN must be set}
now=$(date -u +%FT%TZ)

rm -rf "$out"
mkdir -p "$out/items" "$out/meta"

count=0
while read -r repo; do
    case $repo in '' | \#*) continue ;; esac
    gh search issues --include-prs --repo "$repo" --involves "$user" \
        --updated ">=$since" --limit 100 --json number,isPullRequest \
        --jq '.[] | "\(.number) \(.isPullRequest)"' |
    while read -r number is_pr; do
        id="${repo//\//__}__$number"
        key="$repo#$number"
        if [ "$is_pr" = true ]; then
            gh pr view "$number" -R "$repo" --json number,title,url,state,isDraft,author,createdAt,updatedAt,mergedAt,closedAt,reviewDecision,mergeable,additions,deletions,headRefName,baseRefName,reviewRequests,closingIssuesReferences,statusCheckRollup,comments,reviews,headRefOid --jq '
              def ev: [ (.comments[] | {by: .author.login, at: .createdAt, kind: "comment", text: .body}),
                        (.reviews[] | {by: .author.login, at: .submittedAt, kind: ("review " + (.state|ascii_downcase)), text: .body}) ]
                      | sort_by(.at);
              def checks: [.statusCheckRollup[] | (.conclusion // .status // .state // "UNKNOWN") | ascii_upcase];
              {
                kind: "pr", number, title, url, head: .headRefOid,
                state: (if .state == "OPEN" and .isDraft then "DRAFT" else .state end),
                author: .author.login, created: .createdAt, updated: .updatedAt,
                closed: (.mergedAt // .closedAt),
                review: (.reviewDecision // ""),
                mergeable: (.mergeable // ""),
                size: {add: .additions, del: .deletions},
                branch: .headRefName, base: .baseRefName,
                requested: [.reviewRequests[] | (.login // .name // .slug)],
                closes: [.closingIssuesReferences[] | "\(.repository.owner.login)/\(.repository.name)#\(.number)"],
                checks: (checks | {
                  total: length,
                  pass: map(select(. == "SUCCESS" or . == "NEUTRAL")) | length,
                  fail: map(select(. == "FAILURE" or . == "TIMED_OUT" or . == "CANCELLED" or . == "ACTION_REQUIRED" or . == "ERROR")) | length,
                  pending: map(select(. == "PENDING" or . == "QUEUED" or . == "IN_PROGRESS" or . == "EXPECTED" or . == "WAITING")) | length,
                  skipped: map(select(. == "SKIPPED")) | length }),
                comments: (ev | length),
                activity: (ev | map(select((.text // "") != "" or (.kind | startswith("review")))) | .[-4:] | map(.text = ((.text // "") | gsub("\r"; "") | gsub("[ \t]+"; " ") | gsub(" ?\n[ \n]*"; "\n") | .[0:300])))
              }' > "$out/items/$id.json.tmp"
        else
            gh issue view "$number" -R "$repo" --json number,title,url,state,author,createdAt,updatedAt,closedAt,comments,labels --jq '
              def ev: [ .comments[] | {by: .author.login, at: .createdAt, kind: "comment", text: .body} ] | sort_by(.at);
              {
                kind: "issue", number, title, url, state, author: .author.login,
                created: .createdAt, updated: .updatedAt, closed: (.closedAt // null),
                labels: [.labels[].name],
                comments: (ev | length),
                activity: (ev | .[-4:] | map(.text = ((.text // "") | gsub("\r"; "") | gsub("[ \t]+"; " ") | gsub(" ?\n[ \n]*"; "\n") | .[0:300])))
              }' > "$out/items/$id.json.tmp"
        fi
        # Workflow runs on fork PRs wait for a maintainer to approve them;
        # GitHub reports those as conclusion "action_required".
        awaiting=0
        if [ "$is_pr" = true ]; then
            head=$(sed -n 's/.*"head":"\([0-9a-f]*\)".*/\1/p' "$out/items/$id.json.tmp")
            [ -z "$head" ] || awaiting=$(gh api "repos/$repo/actions/runs?head_sha=$head" \
                --jq '[.workflow_runs[] | select(.conclusion == "action_required")] | length')
        fi
        # Add repo, key, notes and the derived "waiting on" field.
        GH_CI_AWAITING="$awaiting" GH_REPO_KEY="$key" GH_REPO="$repo" GH_USER="$user" GH_NOW="$now" \
            node -e '
              const fs = require("fs");
              const [tmp, dst, notesPath] = process.argv.slice(1);
              const it = JSON.parse(fs.readFileSync(tmp, "utf8"));
              const notes = fs.existsSync(notesPath) ? JSON.parse(fs.readFileSync(notesPath, "utf8")) : {};
              const key = process.env.GH_REPO_KEY, me = process.env.GH_USER;
              it.repo = process.env.GH_REPO; it.key = key; it.synced = process.env.GH_NOW;
              if (it.kind === "pr") it.ci_awaiting_approval = Number(process.env.GH_CI_AWAITING || 0) > 0;
              const n = notes[key] || {};
              it.note = n.note || ""; it.related = [...new Set([...(n.related || []), ...(it.closes || [])])];
              const open = it.state === "OPEN" || it.state === "DRAFT";
              const last = (it.activity || []).filter(e => e.by && !/\[bot\]$/.test(e.by)).at(-1);
              if (!open) it.waiting = "done";
              else if (it.kind === "pr" && it.checks && it.checks.fail > 0 && it.author === me) it.waiting = "you";
              else if (last && last.by !== me && (it.author === me || (it.activity || []).some(e => e.by === me))) it.waiting = "you";
              else it.waiting = "them";
              fs.writeFileSync(dst, JSON.stringify(it));
              fs.unlinkSync(tmp);
            ' "$out/items/$id.json.tmp" "$out/items/$id.json" "$here/notes.json"
        echo "$key"
    done
done < "$here/repos.txt"

# Local branches with no PR yet, from notes.json "local".
if [ -f "$here/notes.json" ]; then
    GH_NOW="$now" node -e '
      const fs = require("fs");
      const [notesPath, dir] = process.argv.slice(1);
      const notes = JSON.parse(fs.readFileSync(notesPath, "utf8"));
      for (const l of notes.local || []) {
        const it = { kind: "branch", state: "LOCAL", number: null, url: "", author: "", comments: 0,
          activity: [], related: l.related || [], waiting: "you", synced: process.env.GH_NOW,
          updated: l.updated || process.env.GH_NOW, ...l, key: l.repo + ":" + l.branch };
        fs.writeFileSync(`${dir}/${l.id}.json`, JSON.stringify(it));
        console.log(it.key);
      }
    ' "$here/notes.json" "$out/items"
fi

printf '{"synced":"%s","user":"%s","since":"%s","repos":%s}\n' "$now" "$user" "$since" \
    "$(node -e 'console.log(JSON.stringify(require("fs").readFileSync(process.argv[1],"utf8").split("\n").map(s=>s.trim()).filter(s=>s&&!s.startsWith("#"))))' "$here/repos.txt")" \
    > "$out/meta/sync.json"
echo "wrote $(ls "$out/items" | wc -l) items to $out"
