#!/bin/bash
# Test harness for doc-validate.sh. Run from this directory: bash test-doc-validate.sh
set -u
HOOK="$(cd "$(dirname "$0")" && pwd)/doc-validate.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0

invoke() { # $1=file_path
  printf '{"tool_input":{"file_path":"%s"}}' "$1" | bash "$HOOK"
}
expect_warn() { # $1=name $2=path — asserts warning on stdout, clean stderr, exit 0
  out="$(invoke "$2" 2>"$TMP/err")"; rc=$?
  if [ $rc -eq 0 ] && [ ! -s "$TMP/err" ] && printf '%s' "$out" | grep -q '"systemMessage".*WARNING'; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL(want-warn)[$MODE]: $1 rc=$rc"; fi
}
expect_silent() { # $1=name $2=path — asserts empty stdout, clean stderr, exit 0
  out="$(invoke "$2" 2>"$TMP/err")"; rc=$?
  if [ $rc -eq 0 ] && [ -z "$out" ] && [ ! -s "$TMP/err" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL(want-silent)[$MODE]: $1 rc=$rc -> $out"; fi
}

run_cases() {
  D="$TMP/repo/docs/agents"; mkdir -p "$D"; cd "$TMP/repo"
  export CLAUDE_PROJECT_DIR="$TMP/repo"   # the relative-path case below re-runs with it unset

  # mature, domain headings, valid TL;DR -> silent
  printf -- '---\nscribe:\n  scan: "abc1234"\n---\n# Topic\n\n> TLDR here.\n\n## Graph Data Model\nbody\n' > "$D/good.md"
  expect_silent mature-good "$D/good.md"
  # blockquote only inside a later section -> warn
  printf -- '---\nx: 1\n---\n# Topic\n\nintro\n\n## Notes\n> not a tldr\n' > "$D/late-quote.md"
  expect_warn mature-late-quote "$D/late-quote.md"
  # no # heading at all -> warn
  printf -- '---\nx: 1\n---\nno heading\n' > "$D/no-heading.md"
  expect_warn no-heading "$D/no-heading.md"
  # fenced "# heading" before the real one must not anchor the check
  printf -- '---\nx: 1\n---\n```\n# fake\n```\n# Real\n\n> TLDR.\n\n## S\nbody\n' > "$D/fenced-heading.md"
  expect_silent fenced-heading "$D/fenced-heading.md"
  # stub with all 5 sections + TL;DR -> silent
  printf -- '---\nx: 1\n---\n# T\n\n> What this covers.\n\n## Key Entry Points\n*Stub — will be populated by the draft skill.*\n\n## Patterns & Conventions\n*Stub — will be populated by the draft skill.*\n\n## Gotchas\n*Stub — will be populated by the draft skill.*\n\n## Dependencies & Context\n*Stub — will be populated by the draft skill.*\n\n## Links\n*Stub — will be populated by the draft skill.*\n' > "$D/stub-good.md"
  expect_silent stub-good "$D/stub-good.md"
  # stub missing a section -> warn
  printf -- '---\nx: 1\n---\n# T\n\n> TLDR.\n\n## Key Entry Points\n*Stub — will be populated by the draft skill.*\n' > "$D/stub-short.md"
  expect_warn stub-short "$D/stub-short.md"
  # marker quoted inside a fence -> mature tier, TL;DR present -> silent
  printf -- '---\nx: 1\n---\n# T\n\n> TLDR.\n\n## About templates\n```markdown\n*Stub — will be populated by the draft skill.*\n```\n' > "$D/fenced-marker.md"
  expect_silent fenced-marker "$D/fenced-marker.md"
  # STATUS.md always silent
  printf -- 'anything' > "$D/STATUS.md"
  expect_silent status-md "$D/STATUS.md"
  # custom docs_dir via .scribe.yml, repo-relative path
  mkdir -p "$TMP/repo/docs/ai"; printf 'output:\n  docs_dir: "docs/ai"\n' > "$TMP/repo/.scribe.yml"
  printf -- '---\nx: 1\n---\nno heading\n' > "$TMP/repo/docs/ai/t.md"
  out="$(cd "$TMP/repo" && printf '{"tool_input":{"file_path":"docs/ai/t.md"}}' | env -u CLAUDE_PROJECT_DIR bash "$HOOK" 2>"$TMP/rel.err")"; rc=$?
  [ $rc -eq 0 ] && [ ! -s "$TMP/rel.err" ] && printf '%s' "$out" | grep -q WARNING \
    && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL[$MODE]: custom-docs-dir-relative rc=$rc"; }
  rm "$TMP/repo/.scribe.yml"
  # stub with all 5 sections but NO TL;DR -> warn
  printf -- '---\nx: 1\n---\n# T\n\n## Key Entry Points\n*Stub — will be populated by the draft skill.*\n\n## Patterns & Conventions\n*Stub — will be populated by the draft skill.*\n\n## Gotchas\n*Stub — will be populated by the draft skill.*\n\n## Dependencies & Context\n*Stub — will be populated by the draft skill.*\n\n## Links\n*Stub — will be populated by the draft skill.*\n' > "$D/stub-no-tldr.md"
  expect_warn stub-no-tldr "$D/stub-no-tldr.md"
  # custom docs_dir again, ABSOLUTE path this time
  printf 'output:\n  docs_dir: "docs/ai"\n' > "$TMP/repo/.scribe.yml"
  expect_warn custom-docs-dir-absolute "$TMP/repo/docs/ai/t.md"
  rm "$TMP/repo/.scribe.yml"
  # leading-/ docs_dir value: exact path prefix semantics
  printf 'output:\n  docs_dir: "%s/docs/ai"\n' "$TMP/repo" > "$TMP/repo/.scribe.yml"
  expect_warn leading-slash-docs-dir "$TMP/repo/docs/ai/t.md"
  rm "$TMP/repo/.scribe.yml"
  # malformed JSON input -> silent on stdout AND stderr, exit 0
  out="$(printf 'not json' | bash "$HOOK" 2>"$TMP/mj.err")"; rc=$?
  [ $rc -eq 0 ] && [ -z "$out" ] && [ ! -s "$TMP/mj.err" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL[$MODE]: malformed-json rc=$rc"; }
  # non-docs file silent
  printf 'x' > "$TMP/repo/other.md"; expect_silent non-docs "$TMP/repo/other.md"

  # frontmatter only, no heading, no body -> stub tier -> warn
  printf -- '---\nx: 1\n---\n' > "$D/empty-body.md"
  expect_warn empty-body "$D/empty-body.md"

  # marker mentioned mid-sentence outside a fence must not anchor the stub tier
  printf -- '---\nx: 1\n---\n# T\n\n> TLDR.\n\n## Notes\nSee how *Stub — will be populated* text renders inline.\n' > "$D/marker-midline.md"
  expect_silent marker-midline "$D/marker-midline.md"

  # marker inside a ~~~ fence -> mature, TL;DR present -> silent
  printf -- '---\nx: 1\n---\n# T\n\n> TLDR.\n\n## About templates\n~~~markdown\n*Stub — will be populated by the draft skill.*\n~~~\n' > "$D/tilde-fence.md"
  expect_silent tilde-fence "$D/tilde-fence.md"

  # a "# comment" inside YAML frontmatter must not satisfy the heading anchor
  printf -- '---\n# comment\nx: 1\n---\nno heading here\n' > "$D/frontmatter-comment.md"
  expect_warn frontmatter-comment "$D/frontmatter-comment.md"

  # docs_dir moved to docs/ai; a bad file under docs/agents/ is out of scope
  printf 'output:\n  docs_dir: "docs/ai"\n' > "$TMP/repo/.scribe.yml"
  printf -- '---\nx: 1\n---\nno heading\n' > "$D/negative-scope.md"
  expect_silent negative-docs-dir "$D/negative-scope.md"
  rm "$TMP/repo/.scribe.yml"

  # absolute docs_dir: a path merely CONTAINING the value as a substring must not match
  printf 'output:\n  docs_dir: "/scribetest/docs/ai"\n' > "$TMP/repo/.scribe.yml"
  mkdir -p "$TMP/repo/decoy/scribetest/docs/ai"
  printf -- '---\nx: 1\n---\nno heading\n' > "$TMP/repo/decoy/scribetest/docs/ai/t.md"
  expect_silent leading-slash-not-prefix "$TMP/repo/decoy/scribetest/docs/ai/t.md"
  rm "$TMP/repo/.scribe.yml"

  # top-level docs_dir (outside output:) is ignored; the default dir is still validated
  printf 'docs_dir: "docs/ai"\noutput:\n  x: 1\n' > "$TMP/repo/.scribe.yml"
  printf -- '---\nx: 1\n---\nno heading\n' > "$D/top-level-docs-dir.md"
  expect_warn top-level-docs-dir-ignored "$D/top-level-docs-dir.md"
  rm "$TMP/repo/.scribe.yml"

  # unquoted docs_dir + trailing comment
  printf 'output:\n  docs_dir: docs/ai   # comment\n' > "$TMP/repo/.scribe.yml"
  printf -- '---\nx: 1\n---\nno heading\n' > "$TMP/repo/docs/ai/t2.md"
  expect_warn unquoted-comment-docs-dir "$TMP/repo/docs/ai/t2.md"
  rm "$TMP/repo/.scribe.yml"

  # well-formed JSON without a file_path key -> silent on both streams
  out="$(printf '{"tool_input":{}}' | bash "$HOOK" 2>"$TMP/nfp.err")"; rc=$?
  [ $rc -eq 0 ] && [ -z "$out" ] && [ ! -s "$TMP/nfp.err" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL[$MODE]: no-file-path rc=$rc"; }

  # file_path pointing at a file that does not exist -> silent on both streams
  expect_silent nonexistent-file "$D/does-not-exist.md"

  # neither jq nor python available -> no-op, even on a file that would warn
  out="$(printf '{"tool_input":{"file_path":"%s"}}' "$D/no-heading.md" | env SCRIBE_NO_JQ=1 SCRIBE_NO_PYTHON=1 bash "$HOOK" 2>"$TMP/nt.err")"; rc=$?
  [ $rc -eq 0 ] && [ -z "$out" ] && [ ! -s "$TMP/nt.err" ] && PASS=$((PASS+1)) \
    || { FAIL=$((FAIL+1)); echo "FAIL[$MODE]: no-extractor-available-no-op rc=$rc -> $out"; }

  # Windows-native, JSON-escaped file_path (real \\ pairs on the wire) must resolve.
  # Built via cygpath from an on-disk fixture so the path actually exists.
  printf -- '---\nx: 1\n---\nno heading\n' > "$D/win-style.md"
  if command -v cygpath >/dev/null 2>&1; then
    win_path="$(cygpath -w "$D/win-style.md" 2>/dev/null)"
    win_escaped="$(printf '%s' "$win_path" | sed 's/\\/\\\\/g')"
    out="$(printf '{"tool_input":{"file_path":"%s"}}' "$win_escaped" | bash "$HOOK" 2>"$TMP/win.err")"; rc=$?
    if [ $rc -eq 0 ] && [ ! -s "$TMP/win.err" ] && printf '%s' "$out" | grep -q '"systemMessage".*WARNING'; then
      PASS=$((PASS+1))
    else
      FAIL=$((FAIL+1)); echo "FAIL[$MODE]: windows-native-json-escaped-path rc=$rc -> $out"
    fi
  else
    echo "SKIP[$MODE]: windows-native-json-escaped-path (cygpath unavailable on this machine)"
  fi

  # the advisory text carries no "Fix before proceeding" clause
  out="$(invoke "$D/no-heading.md" 2>"$TMP/req7a.err")"; rc=$?
  if [ $rc -eq 0 ] && [ ! -s "$TMP/req7a.err" ] && ! printf '%s' "$out" | grep -q 'Fix before proceeding'; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1)); echo "FAIL[$MODE]: no-fix-before-proceeding-clause rc=$rc -> $out"
  fi

  # a mature-tier warning lists only the TL;DR element, never the 5 skeleton sections
  out="$(invoke "$D/no-heading.md" 2>"$TMP/req7b.err")"; rc=$?
  if [ $rc -eq 0 ] && [ ! -s "$TMP/req7b.err" ] \
     && printf '%s' "$out" | grep -q 'TL;DR blockquote' \
     && ! printf '%s' "$out" | grep -q 'Key Entry Points'; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1)); echo "FAIL[$MODE]: mature-warning-lists-only-tldr rc=$rc -> $out"
  fi

  # a CRLF stub file must validate exactly like its LF twin
  printf -- '---\r\nx: 1\r\n---\r\n# T\r\n\r\n> What this covers.\r\n\r\n## Key Entry Points\r\n*Stub — will be populated by the draft skill.*\r\n\r\n## Patterns & Conventions\r\n*Stub — will be populated by the draft skill.*\r\n\r\n## Gotchas\r\n*Stub — will be populated by the draft skill.*\r\n\r\n## Dependencies & Context\r\n*Stub — will be populated by the draft skill.*\r\n\r\n## Links\r\n*Stub — will be populated by the draft skill.*\r\n' > "$D/crlf-stub-good.md"
  expect_silent crlf-stub-good "$D/crlf-stub-good.md"

  # a body made entirely of fenced content is body content -> mature tier, TL;DR only
  printf -- '---\nx: 1\n---\n```go\nfunc main() {}\n```\n' > "$D/fence-only-body.md"
  out="$(invoke "$D/fence-only-body.md" 2>"$TMP/f16.err")"; rc=$?
  if [ $rc -eq 0 ] && [ ! -s "$TMP/f16.err" ] \
     && printf '%s' "$out" | grep -q 'TL;DR blockquote' \
     && ! printf '%s' "$out" | grep -q 'Key Entry Points'; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1)); echo "FAIL[$MODE]: fence-only-body-is-mature rc=$rc -> $out"
  fi

  # docs_dir with a trailing slash must normalize to the orchestrator's value
  printf 'output:\n  docs_dir: "docs/ai/"\n' > "$TMP/repo/.scribe.yml"
  expect_warn trailing-slash-docs-dir "$TMP/repo/docs/ai/t.md"
  rm "$TMP/repo/.scribe.yml"

  # an `output:` line with a trailing comment must still open the block
  printf 'output:   # where generated docs go\n  docs_dir: "docs/ai"\n' > "$TMP/repo/.scribe.yml"
  expect_warn output-key-trailing-comment "$TMP/repo/docs/ai/t.md"
  rm "$TMP/repo/.scribe.yml"

  # the element list is built by appending "<name>," so the sentence must not end in ",."
  out="$(invoke "$D/no-heading.md" 2>"$TMP/f16b.err")"; rc=$?
  if [ $rc -eq 0 ] && [ ! -s "$TMP/f16b.err" ] \
     && printf '%s' "$out" | grep -q 'TL;DR blockquote\.' \
     && ! printf '%s' "$out" | grep -q ',\.'; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1)); echo "FAIL[$MODE]: no-dangling-comma-in-warning rc=$rc -> $out"
  fi

  # malformed JSON that happens to contain a file_path must still be silent
  out="$(printf '{"tool_input": {"file_path": "%s"' "$D/no-heading.md" | bash "$HOOK" 2>"$TMP/g4a.err")"; rc=$?
  [ $rc -eq 0 ] && [ -z "$out" ] && [ ! -s "$TMP/g4a.err" ] && PASS=$((PASS+1)) \
    || { FAIL=$((FAIL+1)); echo "FAIL[$MODE]: malformed-json-carrying-file-path rc=$rc -> $out"; }

  # a top-level "file_path" is not `.tool_input.file_path` and must be ignored
  out="$(printf '{"file_path": "%s"}' "$D/no-heading.md" | bash "$HOOK" 2>"$TMP/g4b.err")"; rc=$?
  [ $rc -eq 0 ] && [ -z "$out" ] && [ ! -s "$TMP/g4b.err" ] && PASS=$((PASS+1)) \
    || { FAIL=$((FAIL+1)); echo "FAIL[$MODE]: top-level-file-path-only rc=$rc -> $out"; }

  # a second "file_path" elsewhere in the payload must not disturb selection
  out="$(printf '{"tool_input":{"file_path":"%s"},"tool_response":{"file_path":"%s"}}' "$D/no-heading.md" "$D/good.md" | bash "$HOOK" 2>"$TMP/g4c.err")"; rc=$?
  if [ $rc -eq 0 ] && [ ! -s "$TMP/g4c.err" ] \
     && printf '%s' "$out" | grep -q '"systemMessage".*WARNING' \
     && printf '%s' "$out" | grep -q 'no-heading\.md'; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1)); echo "FAIL[$MODE]: competing-file-path-keys rc=$rc -> $out"
  fi

  # duplicate file_path keys resolve to the LAST occurrence on both rungs
  out="$(printf '{"tool_input":{"file_path":"%s","file_path":"%s"}}' "$D/good.md" "$D/no-heading.md" | bash "$HOOK" 2>"$TMP/g4d.err")"; rc=$?
  if [ $rc -eq 0 ] && [ ! -s "$TMP/g4d.err" ] && printf '%s' "$out" | grep -q '"systemMessage".*no-heading\.md'; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1)); echo "FAIL[$MODE]: duplicate-key-last-wins rc=$rc -> $out"
  fi

  # trailing comma is malformed JSON on both rungs -> silent no-op
  out="$(printf '{"tool_input":{"file_path":"%s",}}' "$D/no-heading.md" | bash "$HOOK" 2>"$TMP/g4e.err")"; rc=$?
  [ $rc -eq 0 ] && [ -z "$out" ] && [ ! -s "$TMP/g4e.err" ] && PASS=$((PASS+1)) \
    || { FAIL=$((FAIL+1)); echo "FAIL[$MODE]: trailing-comma-json rc=$rc -> $out"; }

  # a Windows-native absolute docs_dir must match a Windows-native incoming path
  if command -v cygpath >/dev/null 2>&1; then
    win_docs="$(cygpath -w "$TMP/repo/docs/ai" 2>/dev/null)"
    win_topic="$(cygpath -w "$TMP/repo/docs/ai/t.md" 2>/dev/null)"
    printf 'output:\n  docs_dir: "%s"\n' "$(printf '%s' "$win_docs" | sed 's/\\/\\\\/g')" > "$TMP/repo/.scribe.yml"
    win_topic_escaped="$(printf '%s' "$win_topic" | sed 's/\\/\\\\/g')"
    out="$(printf '{"tool_input":{"file_path":"%s"}}' "$win_topic_escaped" | bash "$HOOK" 2>"$TMP/g4d.err")"; rc=$?
    if [ $rc -eq 0 ] && [ ! -s "$TMP/g4d.err" ] && printf '%s' "$out" | grep -q '"systemMessage".*WARNING'; then
      PASS=$((PASS+1))
    else
      FAIL=$((FAIL+1)); echo "FAIL[$MODE]: windows-native-absolute-docs-dir rc=$rc -> $out"
    fi
    rm "$TMP/repo/.scribe.yml"
  else
    echo "SKIP[$MODE]: windows-native-absolute-docs-dir (cygpath unavailable on this machine)"
  fi

  # a "#" inside a quoted scalar is part of the value, not a comment: it must not
  # widen validation to every unrelated tree under docs/
  printf 'output:\n  docs_dir: "docs/#agents"\n' > "$TMP/repo/.scribe.yml"
  mkdir -p "$TMP/repo/docs/other" "$TMP/repo/docs/#agents"
  printf -- '---\nx: 1\n---\nno heading\n' > "$TMP/repo/docs/other/x.md"
  expect_silent quoted-hash-docs-dir-no-widening "$TMP/repo/docs/other/x.md"
  printf -- '---\nx: 1\n---\nno heading\n' > "$TMP/repo/docs/#agents/t.md"
  expect_warn quoted-hash-docs-dir-honoured "$TMP/repo/docs/#agents/t.md"
  rm "$TMP/repo/.scribe.yml"

  # docs_dir is a direct child of output:, never a grandchild
  printf 'output:\n  nested:\n    docs_dir: "docs/ai"\n' > "$TMP/repo/.scribe.yml"
  printf -- '---\nx: 1\n---\nno heading\n' > "$D/nested-default.md"
  expect_warn nested-docs-dir-does-not-override-default "$D/nested-default.md"
  rm "$TMP/repo/.scribe.yml"

  # a UTF-8 BOM must not push the frontmatter block into the body grammar. The
  # plain BOM-plus-frontmatter shape would misparse without changing any verdict,
  # so the frontmatter here carries a `#` comment the body grammar reacts to.
  printf -- '\357\273\277---\n# yaml comment\nx: 1\n---\n# T\n\n> What this covers.\n\n## Notes\nbody\n' > "$D/bom-frontmatter-comment.md"
  expect_silent bom-frontmatter-comment "$D/bom-frontmatter-comment.md"

  # the same file with CRLF endings — neither strip may depend on the other's absence
  printf -- '\357\273\277---\r\n# yaml comment\r\nx: 1\r\n---\r\n# T\r\n\r\n> What this covers.\r\n\r\n## Notes\r\nbody\r\n' > "$D/bom-crlf-frontmatter-comment.md"
  expect_silent bom-crlf-frontmatter-comment "$D/bom-crlf-frontmatter-comment.md"

  # the BOM strip must not make the hook go blind on a genuinely broken file
  printf -- '\357\273\277---\nx: 1\n---\n# T\n\nintro with no blockquote\n' > "$D/bom-no-tldr.md"
  expect_warn bom-no-tldr "$D/bom-no-tldr.md"

  # $file_path is interpolated into a JSON string, so a quote in it must come back
  # escaped. Guarded: native Win32 rejects the character, the MSYS layer does not.
  quote_topic="$D/qu\"ote.md"
  if { printf -- '---\nx: 1\n---\nno heading\n' > "$quote_topic"; } 2>/dev/null && [ -f "$quote_topic" ]; then
    quote_payload="$(printf '%s' "$quote_topic" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    out="$(printf '{"tool_input":{"file_path":"%s"}}' "$quote_payload" | bash "$HOOK" 2>"$TMP/g6a.err")"; rc=$?
    if [ $rc -eq 0 ] && [ ! -s "$TMP/g6a.err" ] \
       && printf '%s' "$out" | grep -q '"systemMessage".*WARNING' \
       && printf '%s' "$out" | grep -qF 'qu\"ote.md'; then
      PASS=$((PASS+1))
    else
      FAIL=$((FAIL+1)); echo "FAIL[$MODE]: quote-in-path-escaped-in-envelope rc=$rc -> $out"
    fi
  else
    echo "SKIP[$MODE]: quote-in-path-escaped-in-envelope (this filesystem rejects '\"' in a filename)"
  fi

  # normalize_path rewrites separators only for drive-letter and UNC paths, so a
  # POSIX path keeps a literal backslash, which the envelope must double.
  backslash_topic="$D/back\\slash.md"
  if { printf -- '---\nx: 1\n---\nno heading\n' > "$backslash_topic"; } 2>/dev/null && [ -f "$backslash_topic" ]; then
    backslash_payload="$(printf '%s' "$backslash_topic" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    out="$(printf '{"tool_input":{"file_path":"%s"}}' "$backslash_payload" | bash "$HOOK" 2>"$TMP/g6b.err")"; rc=$?
    if [ $rc -eq 0 ] && [ ! -s "$TMP/g6b.err" ] \
       && printf '%s' "$out" | grep -q '"systemMessage".*WARNING' \
       && printf '%s' "$out" | grep -qF 'back\\slash.md'; then
      PASS=$((PASS+1))
    else
      FAIL=$((FAIL+1)); echo "FAIL[$MODE]: backslash-in-path-escaped-in-envelope rc=$rc -> $out"
    fi
  else
    echo "SKIP[$MODE]: backslash-in-path-escaped-in-envelope (this filesystem rejects '\\' in a filename)"
  fi

  # ``` and ~~~ are not interchangeable: only the marker that opened a fence closes it
  printf -- '---\nx: 1\n---\n# T\n\n> TLDR.\n\n## About fences\n~~~markdown\n```\n*Stub — will be populated by the draft skill.*\n```\n~~~\n' > "$D/mixed-fence.md"
  expect_silent mixed-fence-markers "$D/mixed-fence.md"

  # a fence opener is a non-blank line, so it occupies the TL;DR position: this
  # topic's blockquote arrives too late and only the TL;DR may be named
  printf -- '---\nx: 1\n---\n# Topic\n\n```go\nfunc main() {}\n```\n\n> Blockquote, but not first.\n\n## Notes\nbody\n' > "$D/fence-first.md"
  out="$(invoke "$D/fence-first.md" 2>"$TMP/g8a.err")"; rc=$?
  if [ $rc -eq 0 ] && [ ! -s "$TMP/g8a.err" ] \
     && printf '%s' "$out" | grep -q 'TL;DR blockquote' \
     && ! printf '%s' "$out" | grep -q 'Key Entry Points'; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1)); echo "FAIL[$MODE]: fence-first-fails-tldr rc=$rc -> $out"
  fi

  # a fence BELOW the blockquote is still invisible to the check
  printf -- '---\nx: 1\n---\n# Topic\n\n> TLDR first.\n\n```go\nfunc main() {}\n```\n' > "$D/fence-after-tldr.md"
  expect_silent fence-after-tldr "$D/fence-after-tldr.md"

  # a \uXXXX escape in the path resolves to the file on disk under its decoded
  # name. Guarded: the fixture needs a filesystem that accepts the character.
  unicode_topic="$D/café.md"
  if { printf -- '---\nx: 1\n---\nno heading\n' > "$unicode_topic"; } 2>/dev/null && [ -f "$unicode_topic" ]; then
    # Single-quoted so the payload reaches the hook carrying the escape rather
    # than a pre-decoded é.
    unicode_payload='{"tool_input":{"file_path":"'"$D"'/caf\u00e9.md"}}'
    out="$(printf '%s' "$unicode_payload" | bash "$HOOK" 2>"$TMP/g8b.err")"; rc=$?
    if [ $rc -eq 0 ] && [ ! -s "$TMP/g8b.err" ] && printf '%s' "$out" | grep -q '"systemMessage".*WARNING'; then
      PASS=$((PASS+1))
    else
      FAIL=$((FAIL+1)); echo "FAIL[$MODE]: unicode-escape-path-decoded rc=$rc -> $out"
    fi
    expect_warn unicode-literal-path "$unicode_topic"
  else
    echo "SKIP[$MODE]: unicode-escape-path (this filesystem rejects the fixture name)"
  fi

  # docs_dir with a leading "./" must normalize to the orchestrator's value
  printf 'output:\n  docs_dir: "./docs/ai"\n' > "$TMP/repo/.scribe.yml"
  expect_warn dot-slash-docs-dir "$TMP/repo/docs/ai/t.md"
  rm "$TMP/repo/.scribe.yml"

  # both marks at once: neither strip may depend on the other's absence
  printf 'output:\n  docs_dir: "./docs/ai/"\n' > "$TMP/repo/.scribe.yml"
  expect_warn dot-slash-and-trailing-slash-docs-dir "$TMP/repo/docs/ai/t.md"
  rm "$TMP/repo/.scribe.yml"

}

# A machine can only exercise the rungs whose tool it has, so report the rung
# each pass actually reached rather than the one it asked for.
have_jq=0; command -v jq >/dev/null 2>&1 && have_jq=1
have_python=0
for cand in python3 python py; do
  command -v "$cand" >/dev/null 2>&1 && { have_python=1; break; }
done

if [ "$have_jq" -eq 1 ]; then pass1_rung="jq"
elif [ "$have_python" -eq 1 ]; then pass1_rung="python"
else pass1_rung="none"; fi
if [ "$have_python" -eq 1 ]; then pass2_rung="python"; else pass2_rung="none"; fi

MODE="default"; export SCRIBE_NO_JQ= SCRIBE_NO_PYTHON=
echo "=== pass 1/2: no overrides -> rung reached: $pass1_rung ==="
run_cases

MODE="no-jq"; export SCRIBE_NO_JQ=1 SCRIBE_NO_PYTHON=
echo "=== pass 2/2: SCRIBE_NO_JQ=1 -> rung reached: $pass2_rung ==="
run_cases

echo "--- rungs exercised here: pass1=$pass1_rung pass2=$pass2_rung"
[ "$have_jq" -eq 1 ] || echo "--- jq is not installed on this machine, so the jq rung was never exercised"
[ "$have_python" -eq 1 ] || echo "--- no python interpreter on this machine, so the python rung was never exercised"
echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]
