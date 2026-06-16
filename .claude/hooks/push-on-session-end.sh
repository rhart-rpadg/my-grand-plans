#!/usr/bin/env bash
# SessionEnd hook: commit and push any updates to GitHub, tagging the commit
# with the Claude Code session_id.
#
# Claude Code passes a JSON payload on stdin that includes "session_id" and
# "cwd". We read those, stage everything, and push to the current branch.
set -euo pipefail

payload="$(cat)"

# Extract session_id and cwd from the hook payload (jq if available, else sed).
if command -v jq >/dev/null 2>&1; then
  session_id="$(printf '%s' "$payload" | jq -r '.session_id // empty')"
  cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty')"
else
  session_id="$(printf '%s' "$payload" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  cwd="$(printf '%s' "$payload" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
fi

[ -n "${cwd:-}" ] && cd "$cwd"

# Nothing to do if there are no changes.
if [ -z "$(git status --porcelain)" ]; then
  echo "session-end hook: no changes to push"
  exit 0
fi

git add -A
git commit -m "Update docs (session ${session_id:-unknown})"
git push origin HEAD

echo "session-end hook: pushed updates for session ${session_id:-unknown}"
