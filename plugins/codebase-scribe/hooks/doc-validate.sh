#!/bin/bash
# PostToolUse hook: validates docs/*.md structure. Mature topics need a
# positional, fence-aware TL;DR blockquote; stub topics need the 5-section
# skeleton as well. Advisory only: it always exits 0, never writes to stderr,
# and stays silent on anything it cannot parse or resolve.
input=$(cat)

extract_file_path_jq() {
  printf '%s' "$1" | jq -r '.tool_input.file_path // empty' 2>/dev/null
}

python_words=""
if [ "${SCRIBE_NO_PYTHON:-}" != "1" ]; then
  for cand in python3 python py; do
    if command -v "$cand" >/dev/null 2>&1; then
      if [ "$cand" = "py" ]; then python_words="$cand -3"; else python_words="$cand"; fi
      break
    fi
  done
fi
extract_file_path_python() {
  # The value goes out as UTF-8 bytes, not text: on a cp1252 console the text
  # layer raises UnicodeEncodeError on the non-ASCII paths this rung exists for.
  printf '%s' "$1" | $python_words -c '
import json, sys
try:
    payload = json.loads(sys.stdin.buffer.read().decode("utf-8"))
except Exception:
    raise SystemExit(0)
tool_input = payload.get("tool_input") if isinstance(payload, dict) else None
value = tool_input.get("file_path") if isinstance(tool_input, dict) else None
if isinstance(value, str) and value:
    sys.stdout.buffer.write(value.encode("utf-8"))
' 2>/dev/null
}

normalize_path() {
  local p="$1"
  if printf '%s' "$p" | grep -qE '^[A-Za-z]:[\\/]|^\\\\'; then
    printf '%s' "$p" | sed 's/\\/\//g'
  else
    printf '%s' "$p"
  fi
}

# Only the ABSENCE of a parser falls through; a parser that ran and found no
# .tool_input.file_path has answered the question with its empty result.
if [ "${SCRIBE_NO_JQ:-}" != "1" ] && command -v jq >/dev/null 2>&1; then
  file_path="$(extract_file_path_jq "$input")"
elif [ -n "$python_words" ]; then
  file_path="$(extract_file_path_python "$input")"
else
  exit 0
fi

[ -n "$file_path" ] || exit 0
file_path="$(normalize_path "$file_path")"
[ -f "$file_path" ] || exit 0

case "$file_path" in
  */STATUS.md) exit 0 ;;
esac

scribe_yml=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && [ -f "$CLAUDE_PROJECT_DIR/.scribe.yml" ]; then
  scribe_yml="$CLAUDE_PROJECT_DIR/.scribe.yml"
elif [ -f "./.scribe.yml" ]; then
  scribe_yml="./.scribe.yml"
fi

# Per YAML, an unquoted "#" opens a comment only at the start of the value or
# after whitespace; docs_dir counts only as a direct child of output:.
docs_dir="docs/agents"
if [ -n "$scribe_yml" ]; then
  raw="$(awk '
    function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
    function scalar(v,   i, n, c, q, out) {
      v = trim(v)
      if (v == "") return ""
      q = substr(v, 1, 1)
      if (q == "\"" || q == "\047") {
        n = length(v); out = ""
        for (i = 2; i <= n; i++) {
          c = substr(v, i, 1)
          if (q == "\"" && c == "\\" && i < n) { i++; out = out substr(v, i, 1); continue }
          if (c == q) return out
          out = out c
        }
        return out
      }
      n = length(v); out = ""
      for (i = 1; i <= n; i++) {
        c = substr(v, i, 1)
        if (c == "#" && (i == 1 || substr(v, i - 1, 1) ~ /[[:space:]]/)) break
        out = out c
      }
      return trim(out)
    }
    /^output:[[:space:]]*(#.*)?$/ { in_output = 1; next }
    in_output && /^[^[:space:]]/ { in_output = 0 }
    in_output && /^[[:space:]]+[^[:space:]#]/ {
      match($0, /^[[:space:]]+/)
      ind = RLENGTH
      if (!min_ind || ind < min_ind) min_ind = ind
      if ($0 ~ /^[[:space:]]+docs_dir:/ && (!have || ind < dd_ind)) {
        have = 1; dd_ind = ind
        line = $0; sub(/^[[:space:]]+docs_dir:/, "", line)
        dd = scalar(line)
      }
    }
    END { if (have && dd_ind == min_ind) print dd }
  ' "$scribe_yml" 2>/dev/null)"
  if [ -n "$raw" ]; then
    # Stripped so this hook and the orchestrator read the same value; leading
    # first, so "./" alone reduces to empty rather than to ".".
    raw="${raw#./}"
    raw="${raw%/}"
    [ -n "$raw" ] && docs_dir="$raw"
  fi
fi

docs_dir="$(normalize_path "$docs_dir")"

matched=0
case "$docs_dir" in
  /*|[A-Za-z]:/*)
    case "$file_path" in
      "$docs_dir"/*.md) matched=1 ;;
    esac
    ;;
  *)
    case "$file_path" in
      */"$docs_dir"/*.md) matched=1 ;;
      "$docs_dir"/*.md) matched=1 ;;
    esac
    ;;
esac
[ "$matched" -eq 1 ] || exit 0

result="$(awk -v s1="Key Entry Points" -v s2="Patterns & Conventions" -v s3="Gotchas" \
             -v s4="Dependencies & Context" -v s5="Links" '
  BEGIN {
    fence = 0; fm = 0
    body_nonblank = 0; marker = 0; heading_seen = 0
    tldr_ok = 0; awaiting_tldr = 0
    sec1 = 0; sec2 = 0; sec3 = 0; sec4 = 0; sec5 = 0
  }
  # The BOM escape is octal, not \xef\xbb\xbf: \x is a gawk extension, and under
  # `gawk --posix` the hex form silently fails to match.
  NR == 1 { sub(/^\357\273\277/, "") }
  # Every exact-match test below would fail on a trailing \r; GNU Awk on mingw
  # strips it, a POSIX awk does not.
  { sub(/\r$/, "") }
  NR == 1 && $0 == "---" { fm = 1; next }
  fm == 1 {
    if ($0 == "---") fm = 0
    next
  }
  # CommonMark: only the marker that opened a fence closes it, so a ``` line
  # quoted inside a ~~~ block must not reopen the body to structure detection.
  /^```/ || /^~~~/ {
    body_nonblank = 1
    if (awaiting_tldr) awaiting_tldr = 0
    mark = (substr($0, 1, 3) == "```" ? "`" : "~")
    if (fence == 0) { fence = 1; fence_mark = mark }
    else if (mark == fence_mark) { fence = 0 }
    next
  }
  fence == 1 {
    if ($0 !~ /^[[:space:]]*$/) body_nonblank = 1
    next
  }
  {
    line = $0
    is_blank = (line ~ /^[[:space:]]*$/)
    if (!is_blank) body_nonblank = 1

    if (line ~ /^\*Stub — will be populated/) marker = 1

    if (!heading_seen && line ~ /^# /) {
      heading_seen = 1
      awaiting_tldr = 1
      next
    }

    if (awaiting_tldr && !is_blank) {
      if (line ~ /^>/) tldr_ok = 1
      awaiting_tldr = 0
    }

    if (line == "## " s1) sec1 = 1
    if (line == "## " s2) sec2 = 1
    if (line == "## " s3) sec3 = 1
    if (line == "## " s4) sec4 = 1
    if (line == "## " s5) sec5 = 1
  }
  END {
    printf "%d %d %d %d %d %d %d %d\n", body_nonblank, marker, tldr_ok, sec1, sec2, sec3, sec4, sec5
  }
' "$file_path" 2>/dev/null)"

[ -n "$result" ] || exit 0

read -r body marker tldr sec1 sec2 sec3 sec4 sec5 <<<"$result"

missing=""
if [ "$body" -eq 0 ] || [ "$marker" -eq 1 ]; then
  [ "$sec1" -eq 1 ] || missing="$missing Key Entry Points,"
  [ "$sec2" -eq 1 ] || missing="$missing Patterns & Conventions,"
  [ "$sec3" -eq 1 ] || missing="$missing Gotchas,"
  [ "$sec4" -eq 1 ] || missing="$missing Dependencies & Context,"
  [ "$sec5" -eq 1 ] || missing="$missing Links,"
fi
[ "$tldr" -eq 1 ] || missing="$missing TL;DR blockquote,"

if [ -n "$missing" ]; then
  missing="${missing%,}"
  # Backslashes first, then quotes: the reverse order re-escapes the backslashes
  # this step just added.
  escaped_path="$(printf '%s' "$file_path" | sed 's/\\/\\\\/g; s/"/\\"/g')"
  echo "{\"systemMessage\": \"WARNING: $escaped_path is missing required elements:$missing.\"}"
fi
exit 0
