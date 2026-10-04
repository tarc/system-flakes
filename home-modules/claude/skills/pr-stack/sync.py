#!/usr/bin/env python3
"""Builds the PR Stack dashboard's documents.

    sync.py OUT_DIR

Reads stack.json beside this file, the local branches (git) and, for PRs
that exist, GitHub (REST, $GITHUB_TOKEN). Writes OUT_DIR/prs/<key>.json and
OUT_DIR/meta/sync.json, ready for one ArtifactData batch.
"""
import json
import os
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
config = json.load(open(os.path.join(HERE, "stack.json")))
out = sys.argv[1]
checkout = config["checkout"]
repo = config["repo"]
token = os.environ.get("GITHUB_TOKEN", "")


def git(*args):
    return subprocess.run(["git", "-C", checkout, *args], capture_output=True, text=True, check=True).stdout.strip()


def api(path):
    request = urllib.request.Request(
        "https://api.github.com/" + path,
        headers={"Authorization": "Bearer " + token, "Accept": "application/vnd.github+json",
                 "X-GitHub-Api-Version": "2022-11-28"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def remote_head(branch):
    line = git("ls-remote", "origin", "refs/heads/" + branch)
    return line.split()[0] if line else None


def local_facts(entry):
    branch, on = entry["branch"], entry["on"]
    try:
        head = git("rev-parse", branch)
    except subprocess.CalledProcessError:
        return {"exists": False}
    commits = int(git("rev-list", "--count", f"{on}..{branch}"))
    stat = git("diff", "--no-ext-diff", "--shortstat", on, branch)
    add = dele = files = 0
    for part in stat.split(","):
        part = part.strip()
        number = int(part.split()[0]) if part else 0
        if "file" in part:
            files = number
        elif "insertion" in part:
            add = number
        elif "deletion" in part:
            dele = number
    subjects = git("log", "--reverse", "--format=%h\t%s", f"{on}..{branch}").splitlines()
    return {
        "exists": True, "head": head[:12], "commits": commits, "files": files, "add": add, "del": dele,
        "log": [dict(zip(("sha", "subject"), line.split("\t", 1))) for line in subjects][:60],
        "pushed": remote_head(branch) == head,
    }


def github_facts(number):
    pr = api(f"repos/{repo}/pulls/{number}")
    reviews = api(f"repos/{repo}/pulls/{number}/reviews?per_page=100")
    latest = {}
    for review in reviews:
        if review["state"] in ("APPROVED", "CHANGES_REQUESTED"):
            latest[review["user"]["login"]] = review["state"]
    decision = "CHANGES_REQUESTED" if "CHANGES_REQUESTED" in latest.values() else (
        "APPROVED" if latest else None)
    sha = pr["head"]["sha"]
    runs = api(f"repos/{repo}/actions/runs?head_sha={sha}&per_page=50").get("workflow_runs", [])
    checks = api(f"repos/{repo}/commits/{sha}/check-runs?per_page=100").get("check_runs", [])
    tally = {"total": len(checks), "pass": 0, "fail": 0, "pending": 0, "skipped": 0}
    for check in checks:
        if check["status"] != "completed":
            tally["pending"] += 1
        elif check["conclusion"] in ("success", "neutral"):
            tally["pass"] += 1
        elif check["conclusion"] == "skipped":
            tally["skipped"] += 1
        else:
            tally["fail"] += 1
    state = "MERGED" if pr.get("merged_at") else ("CLOSED" if pr["state"] == "closed" else (
        "DRAFT" if pr["draft"] else "OPEN"))
    return {
        "state": state, "url": pr["html_url"], "github_title": pr["title"],
        "comments": pr["comments"] + pr["review_comments"], "review": decision,
        "reviewers": sorted(latest), "mergeable": pr.get("mergeable_state"),
        "ci": tally, "ci_awaiting_approval": any(r.get("conclusion") == "action_required" for r in runs),
        "created": pr["created_at"], "updated": pr["updated_at"], "closed": pr.get("closed_at"),
        "head_sha": sha[:12],
    }


os.makedirs(os.path.join(out, "prs"), exist_ok=True)
os.makedirs(os.path.join(out, "meta"), exist_ok=True)
for entry in config["prs"]:
    doc = {key: entry.get(key) for key in ("key", "lane", "order", "number", "branch", "on", "title", "note", "draft")}
    doc.update(local_facts(entry))
    doc["checks"] = config.get("checks", {}).get(entry["key"], [])
    if entry.get("number"):
        try:
            doc.update(github_facts(entry["number"]))
        except urllib.error.HTTPError as error:
            doc["github_error"] = f"HTTP {error.code}"
    else:
        doc["state"] = "LOCAL"
    json.dump(doc, open(os.path.join(out, "prs", entry["key"] + ".json"), "w"), indent=1)

upstream = api(f"repos/{repo}/commits/main")
meta = {
    "synced": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    "base": config["base"],
    "upstream_main": upstream["sha"][:12],
    "upstream_moved": not upstream["sha"].startswith(config["base"]),
    "repo": repo, "fork": config["fork"],
}
json.dump(meta, open(os.path.join(out, "meta", "sync.json"), "w"), indent=1)
print(f"wrote {len(config['prs'])} prs and meta/sync to {out}")
