#!/usr/bin/env bash
# Reports what changed in the upstream skills repo we learn from since the last review.
# Read-only by default. `--mark` records the current upstream HEAD as reviewed.
set -euo pipefail

UPSTREAM="mattpocock/skills"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATE="$ROOT/docs/upstream-watch.md"
gh_() { env -u GITHUB_TOKEN gh "$@"; }

last=${SINCE:-$(grep -E "^last_reviewed_sha:" "$STATE" | awk '{print $2}')}
head_sha=$(gh_ api "repos/$UPSTREAM/commits/HEAD" --jq .sha)
head_date=$(gh_ api "repos/$UPSTREAM/commits/HEAD" --jq .commit.committer.date)

if [ "${1:-}" = "--mark" ]; then
  tmp=$(mktemp)
  sed -E "s/^last_reviewed_sha:.*/last_reviewed_sha: $head_sha/; s/^last_reviewed_date:.*/last_reviewed_date: ${head_date%%T*}/" "$STATE" > "$tmp"
  mv "$tmp" "$STATE"
  echo "Marked $head_sha ($head_date) as reviewed in docs/upstream-watch.md"
  exit 0
fi

echo "Upstream: $UPSTREAM"
echo "Last reviewed: ${last:0:7}   Current HEAD: ${head_sha:0:7} ($head_date)"
echo "Latest release: $(gh_ api "repos/$UPSTREAM/releases/latest" --jq '.tag_name+" ("+.published_at[0:10]+")"' 2>/dev/null || echo n/a)"

if [ "$last" = "$head_sha" ]; then
  echo "Nothing new since the last review."
  exit 0
fi

echo
echo "Commits since last review:"
gh_ api "repos/$UPSTREAM/compare/$last...$head_sha" \
  --jq '"  "+(.ahead_by|tostring)+" commit(s)", (.commits[]|"  - "+.sha[0:7]+" "+(.commit.message|split("\n")[0]))' | head -60

echo
echo "Skill and doc files changed (A=added M=modified D=removed):"
gh_ api "repos/$UPSTREAM/compare/$last...$head_sha" --paginate \
  --jq '.files[]|select(.filename|test("^(skills|docs|\\.agents)/"))|"  "+(if .status=="added" then "A" elif .status=="removed" then "D" else "M" end)+" "+.filename' | sort -k2 | head -80

echo
echo "Review what matters, port it to our skills, then run: scripts/check-upstream.sh --mark"
