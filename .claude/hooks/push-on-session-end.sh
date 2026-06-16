#!/usr/bin/env bash
# SessionEnd hook: commit and push any updates to GitHub, tagging the commit
# with the Claude Code session_id.
#
# Claude Code passes a JSON payload on stdin that includes "session_id",
# "cwd", and "transcript_path". We read those, build a commit message that
# summarizes the conversation, stage everything, and push to the current
# branch.
set -euo pipefail

payload="$(cat)"

# Extract fields from the hook payload (jq if available, else sed).
if command -v jq >/dev/null 2>&1; then
  session_id="$(printf '%s' "$payload" | jq -r '.session_id // empty')"
  cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty')"
  transcript_path="$(printf '%s' "$payload" | jq -r '.transcript_path // empty')"
else
  session_id="$(printf '%s' "$payload" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  cwd="$(printf '%s' "$payload" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
  transcript_path="$(printf '%s' "$payload" | sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
fi

[ -n "${cwd:-}" ] && cd "$cwd"

# Nothing to do if there are no changes.
if [ -z "$(git status --porcelain)" ]; then
  echo "session-end hook: no changes to push"
  exit 0
fi

# Build a conversation summary from the transcript. The transcript is a JSONL
# file with one message object per line; we pull out the user's prompts (plain
# text, skipping tool results and meta/command messages) to form the summary.
summary=""
if [ -n "${transcript_path:-}" ] && [ -f "$transcript_path" ] && command -v jq >/dev/null 2>&1; then
  summary="$(jq -r '
    select(.type == "user")
    | .message.content
    | if type == "string" then .
      else (map(select(.type == "text") | .text) | join(" "))
      end
    | select(. != null and (. | ltrimstr(" ")) != "")
    | select(test("^[[:space:]]*<") | not)        # skip system/meta tags
    | gsub("\\s+"; " ")
    | "- " + (if length > 200 then .[0:197] + "..." else . end)
  ' "$transcript_path" 2>/dev/null || true)"
fi

# Compose the commit message: subject line + conversation summary body.
subject="Update docs (session ${session_id:-unknown})"
if [ -n "$summary" ]; then
  commit_msg="$(printf '%s\n\nConversation summary:\n%s\n' "$subject" "$summary")"
else
  commit_msg="$subject"
fi

git add -A
git commit -m "$commit_msg"
git push origin HEAD

echo "session-end hook: pushed updates for session ${session_id:-unknown}"
