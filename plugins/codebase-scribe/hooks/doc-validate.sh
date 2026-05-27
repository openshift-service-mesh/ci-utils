#!/bin/bash
input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Only validate docs/agents/ markdown files (not STATUS.md, not .claims.yml)
case "$file_path" in
  */docs/agents/*.md)
    case "$file_path" in
      */STATUS.md) exit 0 ;;
    esac
    ;;
  *) exit 0 ;;
esac

# Check required sections
missing=""
for section in "Key Entry Points" "Patterns & Conventions" "Gotchas" "Dependencies & Context" "Links"; do
  if ! grep -q "^## $section" "$file_path" 2>/dev/null; then
    missing="$missing $section,"
  fi
done

# Check TL;DR blockquote
if ! grep -q "^>" "$file_path" 2>/dev/null; then
  missing="$missing TL;DR blockquote,"
fi

if [ -n "$missing" ]; then
  echo "{\"systemMessage\": \"WARNING: $file_path is missing required elements:$missing. Fix before proceeding.\"}"
  exit 0
fi
exit 0
