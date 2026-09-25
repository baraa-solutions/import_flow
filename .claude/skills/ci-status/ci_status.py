"""
Show GitHub Actions status for this repository without a token.

The repository is public, so the GitHub REST API answers unauthenticated
requests (60 per hour per IP). The repo slug is read from `git remote get-url origin`.

Usage:
  python .claude/skills/ci-status/ci_status.py            # last 10 runs on main
  python .claude/skills/ci-status/ci_status.py --branch X # runs on another branch
  python .claude/skills/ci-status/ci_status.py --limit 5
"""
import argparse
import json
import re
import subprocess
import sys
import urllib.error
import urllib.request

API_ROOT = "https://api.github.com/repos"


def resolve_repo_slug() -> str:
    remote_url = subprocess.run(
        ["git", "remote", "get-url", "origin"], capture_output=True, text=True, check=True
    ).stdout.strip()
    match = re.search(r"github\.com[:/](.+?/.+?)(?:\.git)?$", remote_url)
    if not match:
        sys.exit(f"origin is not a GitHub remote: {remote_url}")
    return match.group(1)


def fetch_json(url: str) -> dict:
    request = urllib.request.Request(url, headers={"Accept": "application/vnd.github+json", "User-Agent": "importflow-ci-status"})
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return json.load(response)
    except urllib.error.HTTPError as error:
        if error.code == 403:
            sys.exit("GitHub API rate limit reached (60 unauthenticated requests/hour). Try again later.")
        if error.code == 404:
            sys.exit("Repository not found or not public - the unauthenticated API cannot read it.")
        raise


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--branch", default="main")
    parser.add_argument("--limit", type=int, default=10)
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8")

    repo = resolve_repo_slug()
    runs = fetch_json(f"{API_ROOT}/{repo}/actions/runs?branch={args.branch}&per_page={args.limit}")["workflow_runs"]
    if not runs:
        print(f"No workflow runs on branch {args.branch}.")
        return 0

    print(f"Repository: {repo} | branch: {args.branch}\n")
    for run in runs:
        result = run["conclusion"] or run["status"]
        print(f"{run['created_at'][:16].replace('T', ' ')}  {result:<11}  {run['head_sha'][:7]}  {run['display_title'][:70]}")

    latest = runs[0]
    print(f"\nLatest run: {latest['html_url']}")
    if latest["conclusion"] not in ("failure", "cancelled", "timed_out"):
        return 0

    jobs = fetch_json(f"{API_ROOT}/{repo}/actions/runs/{latest['id']}/jobs")["jobs"]
    for job in jobs:
        failed_steps = [s for s in job["steps"] if s["conclusion"] in ("failure", "cancelled", "timed_out")]
        for step in failed_steps:
            print(f"Failed: job '{job['name']}' -> step {step['number']} '{step['name']}'")
    print("Full logs need a signed-in browser: open the run URL above.")

    last_green = next((r for r in runs if r["conclusion"] == "success"), None)
    print(f"Last green run in this window: {last_green['created_at'][:10] + ' ' + last_green['head_sha'][:7] if last_green else 'none'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
