#!/usr/bin/env bash
# PreToolUse(Bash) guard: any command that publishes to GitHub needs an explicit
# user confirmation showing the literal command. Reads the hook JSON on stdin.
set -u
python3 -c '
import json, re, sys
try:
    cmd = json.load(sys.stdin).get("tool_input", {}).get("command", "") or ""
except Exception:
    sys.exit(0)
publish = [
    r"\bgh\s+pr\s+(create|comment|edit|close|reopen|review|merge|ready)\b",
    r"\bgh\s+issue\s+(comment|edit|close)\b",
    r"\bgh\s+api\b.*(/replies\b|resolveReviewThread|unresolveReviewThread|mutation\b)",
    r"\bgh\s+api\b.*(-X|--method)[ =]+(POST|PUT|PATCH|DELETE)\b",
    r"\bgh\s+stack\s+(submit|sync|merge)\b",
]
if not any(re.search(p, cmd, re.S) for p in publish):
    sys.exit(0)
print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason":
        "This publishes to GitHub (visible to others). Confirm the EXACT text below was "
        "the one you approved:\n" + cmd[:1500],
}}))
'
