#!/bin/bash
#
# Generate user-facing release notes using the Claude CLI.
#
# Usage: ./scripts/generate-release-notes.sh <version> [--from <tag>]
# Example: ./scripts/generate-release-notes.sh 1.2.0
#          ./scripts/generate-release-notes.sh 1.2.0 --from v1.1.0
#
# Output: docs/release-notes/<version>.md (used by both Sparkle and GitHub releases)
#
# Prerequisites:
#   - claude CLI installed and authenticated
#   - Git repository with tags for previous releases

set -euo pipefail

VERSION="${1:?Usage: ./scripts/generate-release-notes.sh <version> [--from <tag>]}"
shift

# Determine the base tag (previous release)
FROM_TAG=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --from) FROM_TAG="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [ -z "$FROM_TAG" ]; then
    FROM_TAG=$(git describe --tags --abbrev=0 HEAD 2>/dev/null || true)
    if [ -z "$FROM_TAG" ]; then
        echo "Error: No previous tag found. Use --from <tag> to specify." >&2
        exit 1
    fi
fi

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$PROJECT_DIR/docs/release-notes"
OUTPUT_FILE="$OUTPUT_DIR/$VERSION.md"

echo "==> Generating release notes for v$VERSION (changes since $FROM_TAG)..."

# Collect the commit log
COMMITS=$(git log "$FROM_TAG"..HEAD --format="- %s" --no-merges)

if [ -z "$COMMITS" ]; then
    echo "Error: No commits found between $FROM_TAG and HEAD." >&2
    exit 1
fi

echo "    Found $(echo "$COMMITS" | wc -l | tr -d ' ') commits since $FROM_TAG"

# Generate release notes via Claude CLI
PROMPT="You are writing release notes for Atelier, a native macOS app for conversations with Claude.

Given these git commits since the last release, write concise, user-facing release notes.

Rules:
- Group changes under: ## New, ## Improved, ## Fixed (omit empty sections)
- Write for end users, not developers — no jargon, no file names, no technical internals
- Each item should be one short sentence as a markdown list item
- If none of the commits contain user-facing changes (e.g. only chore, docs, ci, build, refactor, test commits), output exactly: Bug fixes and performance improvements.
- Output ONLY markdown, no code fences, no preamble, no explanation

Commits:
$COMMITS"

mkdir -p "$OUTPUT_DIR"

NOTES=$(echo "$PROMPT" | claude -p \
    --model haiku \
    --no-session-persistence \
    --tools "" 2>/dev/null)

if [ -z "$NOTES" ]; then
    echo "Error: Claude CLI returned empty output." >&2
    exit 1
fi

echo "$NOTES" > "$OUTPUT_FILE"

echo "    Release notes written to $OUTPUT_FILE"
echo ""
echo "$NOTES"
