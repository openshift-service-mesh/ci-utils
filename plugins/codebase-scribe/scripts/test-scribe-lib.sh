#!/bin/bash
# Test harness for scribe-lib.py. Run from anywhere: bash test-scribe-lib.sh
set -u
LIB="$(cd "$(dirname "$0")" && pwd)/scribe-lib.py"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0

python_bin=""
for cand in python3 python py; do
  command -v "$cand" >/dev/null 2>&1 || continue
  if [ "$cand" = "py" ]; then
    if "$cand" -3 -c 'import sys' >/dev/null 2>&1; then python_bin="$cand -3"; break; fi
  else
    if "$cand" -c 'import sys' >/dev/null 2>&1; then python_bin="$cand"; break; fi
  fi
done
if [ -z "$python_bin" ]; then
  echo "FAIL: no working Python interpreter found (tried python3, python, py -3)"
  exit 1
fi

lib() { $python_bin "$LIB" "$@"; }

expect() { # $1=name $2=expected stdout $3=expected exit code $4...=args to scribe-lib.py
  local name="$1" want="$2" wantrc="$3"; shift 3
  local out rc
  out="$(lib "$@" 2>/dev/null)"; rc=$?
  if [ "$out" = "$want" ] && [ "$rc" -eq "$wantrc" ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    echo "FAIL: $name -- want [$want] rc=$wantrc, got [$out] rc=$rc"
  fi
}

check() { # $1=name $2=actual $3=expected -- for assertions about written files
  if [ "$2" = "$3" ]; then
    PASS=$((PASS+1))
  else
    FAIL=$((FAIL+1))
    echo "FAIL: $1 -- want [$3], got [$2]"
  fi
}

# --- shared parsing rules -------------------------------------------------
# The "## Fake" heading sits INSIDE frontmatter, so it is only invisible if the
# BOM / CRLF handling let the frontmatter block be recognised at all.
printf -- '\xef\xbb\xbf---\n## Fake\n---\n## Alpha\n' > "$TMP/bom.md"
expect bom-tolerated $'2\talpha\tAlpha' 0 sections "$TMP/bom.md"

printf -- '---\r\n## Fake\r\n---\r\n## Alpha\r\n' > "$TMP/crlf.md"
expect crlf-tolerated $'2\talpha\tAlpha' 0 sections "$TMP/crlf.md"

printf -- '---\nx: 1\n---\n## Real\n```\n## Fenced\n```\n## Other\n' > "$TMP/fence.md"
expect fenced-heading-invisible $'2\treal\tReal\n2\tother\tOther' 0 sections "$TMP/fence.md"

# A ``` line quoted inside a ~~~ block must not close that block.
printf -- '---\nx: 1\n---\n~~~\n```\n## Hidden\n~~~\n## Visible\n' > "$TMP/pair.md"
expect fence-marker-pairing $'2\tvisible\tVisible' 0 sections "$TMP/pair.md"

# --- sections -------------------------------------------------------------
printf -- '---\nx: 1\n---\n### Orphan\n## Patterns & Conventions\n### Sub Thing\n' > "$TMP/nested.md"
expect sections-level3-scoping \
  $'3\torphan\tOrphan\n3\tpatterns--conventions/sub-thing\tSub Thing' 0 \
  sections "$TMP/nested.md" --level 3
expect sections-level-all \
  $'3\torphan\tOrphan\n2\tpatterns--conventions\tPatterns & Conventions\n3\tpatterns--conventions/sub-thing\tSub Thing' 0 \
  sections "$TMP/nested.md" --level all

# --- slug -----------------------------------------------------------------
expect slug-no-hyphen-dedup patterns--conventions 0 slug "Patterns & Conventions"

# --- tier -----------------------------------------------------------------
printf -- '---\nx: 1\n---\n' > "$TMP/empty.md"
expect tier-empty-body stub 0 tier "$TMP/empty.md"

printf -- '---\nx: 1\n---\n# T\n\n## Key Entry Points\n*Stub — will be populated by the draft skill.*\n' > "$TMP/stub.md"
expect tier-unfenced-marker stub 0 tier "$TMP/stub.md"

printf -- '---\nx: 1\n---\n# T\n\n~~~markdown\n*Stub — will be populated by the draft skill.*\n~~~\n' > "$TMP/fenced-marker.md"
expect tier-fenced-marker-only mature 0 tier "$TMP/fenced-marker.md"

# A body that is nothing but an empty fence still counts as body content.
printf -- '---\nx: 1\n---\n```\n```\n' > "$TMP/only-fence.md"
expect tier-empty-fence-is-content mature 0 tier "$TMP/only-fence.md"

# --- human-input ----------------------------------------------------------
printf -- '---\nx: 1\n---\n## Alpha\n## Beta\n## Gamma\n## Delta\n' > "$TMP/four.md"
expect human-input-two-of-four 50 0 human-input "$TMP/four.md" --slugs "alpha,beta"
expect human-input-distinct 25 0 human-input "$TMP/four.md" --slugs "alpha, alpha"
expect human-input-unknown-slug 0 0 human-input "$TMP/four.md" --slugs "no-such-section"
expect human-input-empty-csv 0 0 human-input "$TMP/four.md" --slugs ""
expect human-input-no-sections 0 0 human-input "$TMP/empty.md" --slugs "alpha"

printf -- '---\nx: 1\n---\n## A1\n## A2\n## A3\n## A4\n## A5\n## A6\n## A7\n## A8\n' > "$TMP/eight.md"
expect human-input-round-half-up 13 0 human-input "$TMP/eight.md" --slugs "a1"

# --- completeness ---------------------------------------------------------
mkdir -p "$TMP/tree/src/a" "$TMP/tree/src/b" "$TMP/tree/src/.git" "$TMP/tree/flat"
echo x > "$TMP/tree/src/a/one.txt"
echo x > "$TMP/tree/src/b/two.txt"
echo x > "$TMP/tree/src/.git/config"
echo x > "$TMP/tree/flat/only-file.txt"
# src/b/two.txt is cited only in FRONTMATTER, which does not count as coverage;
# src/.git must be skipped, or the population would be 3 and the score 33.
printf -- '---\nscan: "src/b/two.txt"\n---\nSee `src/a/one.txt` for details.\n' > "$TMP/tree/doc.md"
printf -- '---\nx: 1\n---\nsrc/a/one.txt and src/b/two.txt are both covered.\n' > "$TMP/tree/doc2.md"
cd "$TMP/tree" || exit 1
expect completeness-half 50 0 completeness doc.md src
expect completeness-watch-union 50 0 completeness doc.md src ./src
expect completeness-full 100 0 completeness doc2.md src
expect completeness-no-subdirs 0 0 completeness doc.md flat
expect completeness-missing-watch 0 0 completeness doc.md no-such-dir
cd "$TMP" || exit 1

# --- validate-sha ---------------------------------------------------------
mkdir -p "$TMP/repo"
cd "$TMP/repo" || exit 1
git init -q . >/dev/null 2>&1
git config user.email test@example.com
git config user.name test
git config core.autocrlf false
echo one > f.txt; git add f.txt; git commit -qm one >/dev/null 2>&1
echo two >> f.txt; git add f.txt; git commit -qm two >/dev/null 2>&1
# Read after the first commit: an unborn HEAD has no resolvable branch name, and
# an empty one here silently leaves the orphan branch below checked out.
orig_branch="$(git rev-parse --abbrev-ref HEAD)"
ancestor_sha="$(git rev-parse HEAD~1)"
git checkout -q --orphan side >/dev/null 2>&1
echo side > s.txt; git add s.txt; git commit -qm side >/dev/null 2>&1
orphan_sha="$(git rev-parse HEAD)"
git checkout -q "$orig_branch" >/dev/null 2>&1
expect sha-empty null 2 validate-sha ""
expect sha-literal-null null 2 validate-sha "null"
expect sha-bad-shape shape 1 validate-sha "ZZZ123"
expect sha-unresolvable unresolvable 1 validate-sha "0123456789abcdef0123456789abcdef01234567"
expect sha-unreachable unreachable 1 validate-sha "$orphan_sha"
expect sha-valid valid 0 validate-sha "$ancestor_sha"
cd "$TMP" || exit 1

# --- classify -------------------------------------------------------------
CD="$TMP/cls"; mkdir -p "$CD"
{
  printf -- '---\nx: 1\n---\n# Topic\n\n> TLDR.\n\n## Alpha\n'
  for i in 1 2 3 4 5; do echo "alpha line $i"; done
  printf -- '\n## Beta\n'
  for i in 1 2 3 4 5; do echo "beta line $i"; done
} > "$CD/current.md"                       # 20 lines, two ## sections
# 2 changed lines => 4 diff lines: under 50% of 20, and tunable against --threshold
sed -e 's/^x: 1$/scan: "abc1234"/' -e 's/^alpha line 3$/alpha line THREE/' "$CD/current.md" > "$CD/snap.md"
sed -e 's/^x: 1$/scan: null/' "$CD/current.md" > "$CD/snap-null.md"
sed -e 's/^x: 1$/scan: ~/' "$CD/current.md" > "$CD/snap-tilde.md"
{ printf -- '---\nscan: "abc1234"\n---\n'; for i in $(seq 1 20); do echo "wholly different $i"; done; } > "$CD/snap-big.md"
: > "$CD/snap-zero.md"
printf 'claim one\nclaim two\n' > "$CD/sc.txt"
printf 'claim one\nclaim two\n' > "$CD/cc.txt"
printf 'claim one\nclaim CHANGED\n' > "$CD/cc-diff.txt"
printf 'Alpha\nBeta\n' > "$CD/sh.txt"
printf 'Alpha\nGamma\n' > "$CD/sh-diff.txt"

classify_case() { # $1=name $2=expected $3=snapshot $4=current-claims $5=snapshot-headings $6=threshold
  expect "$1" "$2" 0 classify "$CD/current.md" --snapshot "$3" \
    --snapshot-claims "$CD/sc.txt" --current-claims "$4" \
    --snapshot-headings "$5" --threshold "$6"
}
classify_case classify-a-no-snapshot   major_rewrite    "$CD/absent.md"     "$CD/cc.txt"      "$CD/sh.txt"      100
classify_case classify-b-zero-bytes    new_draft        "$CD/snap-zero.md"  "$CD/cc.txt"      "$CD/sh.txt"      100
classify_case classify-b-scan-null     new_draft        "$CD/snap-null.md"  "$CD/cc.txt"      "$CD/sh.txt"      100
classify_case classify-b-scan-tilde    new_draft        "$CD/snap-tilde.md" "$CD/cc.txt"      "$CD/sh.txt"      100
classify_case classify-c-major-rewrite major_rewrite    "$CD/snap-big.md"   "$CD/cc.txt"      "$CD/sh.txt"      100
classify_case classify-d-claim-change  claim_change     "$CD/snap.md"       "$CD/cc-diff.txt" "$CD/sh.txt"      100
classify_case classify-e-section-chg   section_change   "$CD/snap.md"       "$CD/cc.txt"      "$CD/sh-diff.txt" 100
classify_case classify-f-large-diff    large_diff       "$CD/snap.md"       "$CD/cc.txt"      "$CD/sh.txt"      1
classify_case classify-g-minor         minor_mechanical "$CD/snap.md"       "$CD/cc.txt"      "$CD/sh.txt"      10
# deleted "---" content lines render as "----" in a unified diff and must count
cat "$CD/snap.md" > "$CD/snap-hr.md"; printf -- '---\n---\n---\n---\n' >> "$CD/snap-hr.md"
classify_case classify-f-hr-deletions  large_diff       "$CD/snap-hr.md"    "$CD/cc.txt"      "$CD/sh.txt"      7
# claims AND headings both differ: rule d wins because the order is strict
classify_case classify-precedence      claim_change     "$CD/snap.md"       "$CD/cc-diff.txt" "$CD/sh-diff.txt" 100
# both claim files missing read as empty, so they are equal
expect classify-missing-claims minor_mechanical 0 classify "$CD/current.md" --snapshot "$CD/snap.md" \
  --snapshot-claims "$CD/gone-a.txt" --current-claims "$CD/gone-b.txt" \
  --snapshot-headings "$CD/sh.txt" --threshold 10

# --- hub-state ------------------------------------------------------------
HB="$TMP/hub"; mkdir -p "$HB"
expect hub-state-absent absent 0 hub-state "$HB/no-such-hub.md"

printf -- '<!-- scribe:managed -->\n# Hub\n' > "$HB/managed.md"
expect hub-state-managed managed 0 hub-state "$HB/managed.md"

printf -- '# Hub\n\n  <!-- scribe:managed:append-only -->\n' > "$HB/append.md"
expect hub-state-append-only append-only 0 hub-state "$HB/append.md"

printf -- '# Hub\n\nNothing here.\n' > "$HB/plain.md"
expect hub-state-unmarked unmarked 0 hub-state "$HB/plain.md"

# A hub that only documents the convention must not be silently adopted.
printf -- '# Hub\n\n```markdown\n<!-- scribe:managed -->\n```\n' > "$HB/fenced.md"
expect hub-state-fenced-marker unmarked 0 hub-state "$HB/fenced.md"

printf -- '# Hub\n\nAdd <!-- scribe:managed --> to opt in.\n' > "$HB/midline.md"
expect hub-state-midline-marker unmarked 0 hub-state "$HB/midline.md"

# append-only is the more restrictive mode, so it wins even when it comes second
printf -- '<!-- scribe:managed -->\n<!-- scribe:managed:append-only -->\n' > "$HB/both.md"
expect hub-state-both-markers append-only 0 hub-state "$HB/both.md"

# --- hub-links ------------------------------------------------------------
printf -- '- [Api](docs/agents/api.md)\n[ref]: docs/agents/ref.md\n' > "$HB/l-basic.md"
expect hub-links-inline-and-reference $'docs/agents/api.md\ndocs/agents/ref.md' 0 \
  hub-links "$HB/l-basic.md" --docs-dir docs/agents

printf -- '- [Old](docs/agents-old/api.md)\n- [X](docs/agentsx)\n' > "$HB/l-sibling.md"
expect hub-links-segment-boundary "" 0 hub-links "$HB/l-sibling.md" --docs-dir docs/agents

printf -- '- [Dot](./docs/agents/dot.md)\n' > "$HB/l-dot.md"
expect hub-links-dot-slash-stripped docs/agents/dot.md 0 \
  hub-links "$HB/l-dot.md" --docs-dir docs/agents

printf -- 'See [a](docs/agents/a.md) and [b](docs/agents/b.md) both.\n' > "$HB/l-two.md"
expect hub-links-two-on-one-line $'docs/agents/a.md\ndocs/agents/b.md' 0 \
  hub-links "$HB/l-two.md" --docs-dir docs/agents

# link matching is defined over the whole file, so fences are not skipped here
printf -- '```\n[Fenced](docs/agents/fenced.md)\n```\n' > "$HB/l-fenced.md"
expect hub-links-fence-not-skipped docs/agents/fenced.md 0 \
  hub-links "$HB/l-fenced.md" --docs-dir docs/agents

expect hub-links-none "" 0 hub-links "$HB/plain.md" --docs-dir docs/agents
expect hub-links-missing-file "" 3 hub-links "$HB/no-such-hub.md" --docs-dir docs/agents

# --- repair-watch-paths ---------------------------------------------------
mkdir -p "$TMP/wp/src/lib" "$TMP/wp/cmd/server"
echo x > "$TMP/wp/cmd/server/main.go"
echo x > "$TMP/wp/top.txt"
cd "$TMP/wp" || exit 1
expect repair-file-widened $'cmd/server\tcmd/server/main.go\tok' 0 \
  repair-watch-paths cmd/server/main.go
expect repair-trailing-slash $'src/lib\tsrc/lib/\tok' 0 repair-watch-paths "src/lib/"
expect repair-backslashes $'src/lib\tsrc\\lib\\\tok' 0 repair-watch-paths 'src\lib\'
expect repair-single-segment-dir $'src\tsrc\tok' 0 repair-watch-paths src
expect repair-single-segment-file $'top.txt\ttop.txt\tok' 0 repair-watch-paths top.txt
expect repair-single-segment-unresolved $'nope\tnope\tunresolved' 0 repair-watch-paths nope
# nothing on the way up exists, so the walk stops at the preserved single segment
expect repair-walks-to-single-segment $'nope\tnope/deep/x.go\tunresolved' 0 \
  repair-watch-paths nope/deep/x.go
# both entries repair to cmd/server; the first occurrence keeps its <original>
expect repair-dedupe-first-wins $'cmd/server\tcmd/server/main.go\tok' 0 \
  repair-watch-paths cmd/server/main.go cmd/server/
expect repair-order-preserved $'src/lib\tsrc/lib\tok\nnope\tnope\tunresolved' 0 \
  repair-watch-paths src/lib nope
expect repair-no-args "" 3 repair-watch-paths
cd "$TMP" || exit 1

# --- fm read --------------------------------------------------------------
SW="$TMP/sw"; mkdir -p "$SW"
printf -- '---\ntitle: X\n---\n# Topic\n' > "$SW/no-scribe.md"
expect fm-read-no-scribe '{}' 0 fm read "$SW/no-scribe.md"

printf -- '---\nscribe:\n  scan: "abc1234"\n  freshness: 80\n---\n# Topic\n' > "$SW/read.md"
expect fm-read-populated '{"freshness":80,"scan":"abc1234"}' 0 fm read "$SW/read.md"
expect fm-read-missing-file "" 3 fm read "$SW/no-such-topic.md"

# --- fm update ------------------------------------------------------------
printf -- '---\ntitle: X\nscribe:\n  scan: "abc1234"\n  freshness: 80\n  watch_paths: ["src/"]\n---\n# Topic\n' > "$SW/upd.md"
expect fm-update-merge '{"completeness":40,"freshness":100,"scan":"abc1234","watch_paths":["src/"]}' 0 \
  fm update "$SW/upd.md" --json '{"freshness":100,"completeness":40}'
# a key beside "scribe:" is outside every verb's remit and must survive
check fm-update-keeps-sibling "$(grep -c '^title: X$' "$SW/upd.md")" 1
expect fm-update-unset '{"freshness":100,"watch_paths":["src/"]}' 0 \
  fm update "$SW/upd.md" --json '{}' --unset "scan, completeness"
expect fm-update-replaces-wholesale '{"freshness":100,"watch_paths":["cmd/"]}' 0 \
  fm update "$SW/upd.md" --json '{"watch_paths":["cmd/"]}'

# --- fm stamp -------------------------------------------------------------
printf -- '---\nscribe:\n  freshness: 0\n  question_passes: 2\n---\n# Topic\n' > "$SW/stamp.md"
expect fm-stamp '{"freshness":100,"scan":"deadbee"}' 0 fm stamp "$SW/stamp.md" --scan deadbee --freshness 100
expect fm-stamp-preserves '{"freshness":100,"question_passes":2,"scan":"deadbee"}' 0 fm read "$SW/stamp.md"

# --- fm credit-section ----------------------------------------------------
printf -- '---\nscribe:\n  inferred_sections:\n    - id: alpha\n      heading: "## Alpha"\n    - id: alpha/deep\n      heading: "### Deep"\n    - id: beta\n      heading: "## Beta"\n---\n# Topic\n\n## Alpha\n\n### Deep\n\n## Beta\n' > "$SW/credit.md"
expect fm-credit-adds '{"human_input":50,"human_sections":["alpha"]}' 0 fm credit-section "$SW/credit.md" alpha
expect fm-credit-repeat-no-dup '{"human_input":50,"human_sections":["alpha"]}' 0 fm credit-section "$SW/credit.md" alpha
# the top-level inferred entry goes; the subsection beneath it stays
expect fm-credit-inferred-pruned \
  '{"human_input":50,"human_sections":["alpha"],"inferred_sections":[{"heading":"### Deep","id":"alpha/deep"},{"heading":"## Beta","id":"beta"}]}' 0 \
  fm read "$SW/credit.md"
expect fm-credit-second-section '{"human_input":100,"human_sections":["alpha","beta"]}' 0 \
  fm credit-section "$SW/credit.md" beta

printf -- '---\nscribe: {}\n---\n# Topic\n\n## Alpha\n\n## Beta\n' > "$SW/ghost.md"
expect fm-credit-unmatched-slug '{"human_input":0,"human_sections":["ghost"]}' 0 \
  fm credit-section "$SW/ghost.md" ghost
# crediting must not introduce an inferred_sections the file never had
check fm-credit-no-phantom-inferred "$(grep -c inferred_sections "$SW/ghost.md")" 0

printf -- '---\nscribe: {}\n---\n# Topic\n\n## Alpha\n\n```\n## Fenced\n```\n\n## Beta\n' > "$SW/credit-fence.md"
expect fm-credit-fence-aware '{"human_input":50,"human_sections":["alpha"]}' 0 \
  fm credit-section "$SW/credit-fence.md" alpha

# --- fm question-pass / settle --------------------------------------------
printf -- '---\nscribe: {}\n---\n# Topic\n' > "$SW/qp0.md"
expect fm-question-pass-from-absent 1 0 fm question-pass "$SW/qp0.md"
printf -- '---\nscribe:\n  question_passes: 2\n---\n# Topic\n' > "$SW/qp2.md"
expect fm-question-pass-from-two 3 0 fm question-pass "$SW/qp2.md"

printf -- '---\nscribe:\n  question_passes: 2\n  human_input: 0\n---\n# Topic\n' > "$SW/settled.md"
cp "$SW/settled.md" "$SW/settled.bak"
expect fm-settle-settled settled 0 fm settle "$SW/settled.md"
cmp -s "$SW/settled.md" "$SW/settled.bak"; check fm-settle-settled-untouched "$?" 0

printf -- '---\nscribe:\n  question_passes: 2\n  human_input: 40\n---\n# Topic\n' > "$SW/reset.md"
expect fm-settle-reset reset 0 fm settle "$SW/reset.md"
expect fm-settle-reset-wrote '{"human_input":40,"question_passes":0}' 0 fm read "$SW/reset.md"
printf -- '---\nscribe:\n  human_input: 0\n---\n# Topic\n' > "$SW/reset-absent.md"
expect fm-settle-absent-counter reset 0 fm settle "$SW/reset-absent.md"

# --- fm retire-decision / refresh-decision --------------------------------
decision_case() { # $1=dir -- a topic with one active decision plus its claim
  mkdir -p "$1"
  printf -- '---\nscribe:\n  human_sections:\n    - alpha\n  decisions:\n    - id: t-1\n      type: constraint\n      claim: "Window is fixed"\n      context: "legal"\n      recorded: "2026-03-01"\n      status: active\n---\n# Topic\n\n## Alpha\n' > "$1/topic.md"
  printf -- 'claims:\n  - id: t-1\n    type: constraint\n    topic: t\n    claim: "Window is fixed"\n    source: "a.go"\n    provenance:\n      origin: user\n      recorded: "2026-03-01"\n  - id: t-2\n    type: pattern\n    topic: t\n    claim: "Other"\n    source: "b.go"\n' > "$1/.claims.yml"
}

decision_case "$SW/ret"
expect fm-retire '{"claim_removed":true,"id":"t-1","resolved_at":"cafe123","status":"retired"}' 0 \
  fm retire-decision "$SW/ret/topic.md" t-1 --claims "$SW/ret/.claims.yml" --resolved-at cafe123
expect fm-retire-tombstone \
  '{"decisions":[{"claim":"Window is fixed","context":"legal","id":"t-1","recorded":"2026-03-01","resolved_at":"cafe123","status":"retired","type":"constraint"}],"human_sections":["alpha"]}' 0 \
  fm read "$SW/ret/topic.md"
check fm-retire-claim-removed "$(grep -c 'id: t-1' "$SW/ret/.claims.yml")" 0
check fm-retire-other-claim-kept "$(grep -c 'id: t-2' "$SW/ret/.claims.yml")" 1
check fm-retire-reserves-id "$(grep -c '^- t-1$' "$SW/ret/.claims.yml")" 1

decision_case "$SW/ret2"
expect fm-retire-missing-id "" 3 fm retire-decision "$SW/ret2/topic.md" t-9 --claims "$SW/ret2/.claims.yml"
expect fm-retire-missing-claims-file "" 3 \
  fm retire-decision "$SW/ret2/topic.md" t-1 --claims "$SW/ret2/gone.yml"
# nothing was written by either failure, so the entry is still active
expect fm-retire-failure-left-file-alone \
  '{"decisions":[{"claim":"Window is fixed","context":"legal","id":"t-1","recorded":"2026-03-01","status":"active","type":"constraint"}],"human_sections":["alpha"]}' 0 \
  fm read "$SW/ret2/topic.md"
expect fm-retire-without-sha '{"claim_removed":true,"id":"t-1","resolved_at":null,"status":"retired"}' 0 \
  fm retire-decision "$SW/ret2/topic.md" t-1 --claims "$SW/ret2/.claims.yml"
check fm-retire-invents-no-sha "$(grep -c resolved_at "$SW/ret2/topic.md")" 0
# retiring twice keeps one tombstone id and reports the claim already gone
expect fm-retire-twice '{"claim_removed":false,"id":"t-1","resolved_at":null,"status":"retired"}' 0 \
  fm retire-decision "$SW/ret2/topic.md" t-1 --claims "$SW/ret2/.claims.yml"
check fm-retire-no-duplicate-id "$(grep -c '^- t-1$' "$SW/ret2/.claims.yml")" 1

decision_case "$SW/ref"
expect fm-refresh \
  '{"claim_updated":true,"context":"new reasoning","id":"t-1","recorded":"2026-08-01","resolved_at":"cafe123"}' 0 \
  fm refresh-decision "$SW/ref/topic.md" t-1 --claims "$SW/ref/.claims.yml" \
  --recorded 2026-08-01 --context "new reasoning" --resolved-at cafe123
expect fm-refresh-entry \
  '{"decisions":[{"claim":"Window is fixed","context":"new reasoning","id":"t-1","recorded":"2026-08-01","resolved_at":"cafe123","status":"active","type":"constraint"}],"human_sections":["alpha"]}' 0 \
  fm read "$SW/ref/topic.md"
check fm-refresh-claim-context "$(grep -c 'context: new reasoning' "$SW/ref/.claims.yml")" 1
check fm-refresh-claim-recorded "$(grep -c "recorded: '2026-08-01'" "$SW/ref/.claims.yml")" 1
expect fm-refresh-without-context '{"claim_updated":true,"context":null,"id":"t-1","recorded":"2026-09-01","resolved_at":null}' 0 \
  fm refresh-decision "$SW/ref/topic.md" t-1 --claims "$SW/ref/.claims.yml" --recorded 2026-09-01
check fm-refresh-keeps-context "$(grep -c 'context: new reasoning' "$SW/ref/.claims.yml")" 1

decision_case "$SW/ref2"
lib fm retire-decision "$SW/ref2/topic.md" t-1 --claims "$SW/ref2/.claims.yml" >/dev/null 2>&1
expect fm-refresh-retired-refused "" 3 \
  fm refresh-decision "$SW/ref2/topic.md" t-1 --claims "$SW/ref2/.claims.yml" --recorded 2026-08-01

# --- fm remove-stale-flag -------------------------------------------------
printf -- '---\nscribe:\n  stale_flags:\n    - id: decision-t-1\n      reason: decision_drift\n    - id: ref-2\n      reason: deleted\n    - id: decision-t-1\n      reason: semantic\n---\n# Topic\n' > "$SW/flags.md"
expect fm-remove-stale-flag 2 0 fm remove-stale-flag "$SW/flags.md" decision-t-1
expect fm-remove-stale-flag-kept '{"stale_flags":[{"id":"ref-2","reason":"deleted"}]}' 0 fm read "$SW/flags.md"
expect fm-remove-stale-flag-none 0 0 fm remove-stale-flag "$SW/flags.md" decision-t-1
expect fm-remove-stale-flag-absent-list 0 0 fm remove-stale-flag "$SW/read.md" decision-t-1

# --- claims add / set-meta ------------------------------------------------
CL="$SW/claims"; mkdir -p "$CL"
expect claims-add-creates-file '{"added":["t-1"],"matched":[]}' 0 \
  claims add --claims "$CL/.claims.yml" --topic t \
  --json '[{"type":"pattern","claim":"Purging runs as a scheduled job","source":"a.go"}]'
# same type, topic and leading 50 characters: the id is kept and nothing else changes
expect claims-add-exact-match '{"added":[],"matched":["t-1"]}' 0 \
  claims add --claims "$CL/.claims.yml" --topic t \
  --json '[{"type":"pattern","claim":"Purging runs as a scheduled job","source":"DIFFERENT.go"}]'
check claims-add-match-keeps-source "$(grep -c 'source: a.go' "$CL/.claims.yml")" 1
check claims-add-match-updates-nothing "$(grep -c DIFFERENT "$CL/.claims.yml")" 0

printf -- 'claims:\n  - id: t-1\n    type: pattern\n    topic: t\n    claim: "First"\n    source: "a.go"\n_retired_ids:\n  - t-2\n' > "$CL/seq.yml"
expect claims-add-skips-retired-and-reserved '{"added":["t-4"],"matched":[]}' 0 \
  claims add --claims "$CL/seq.yml" --topic t \
  --json '[{"type":"constraint","claim":"Second","source":"b.go"}]' --reserved "t-3"
expect claims-add-consecutive-ids '{"added":["t-5","t-6"],"matched":[]}' 0 \
  claims add --claims "$CL/seq.yml" --topic t \
  --json '[{"type":"pattern","claim":"Third","source":"c.go"},{"type":"pattern","claim":"Fourth","source":"d.go"}]'
# same type and text, different topic: matching is per-topic, so this is new
expect claims-add-other-topic '{"added":["u-1"],"matched":[]}' 0 \
  claims add --claims "$CL/seq.yml" --topic u \
  --json '[{"type":"pattern","claim":"Third","source":"c.go"}]'
expect claims-add-rejects-incoming-id "" 3 \
  claims add --claims "$CL/seq.yml" --topic t \
  --json '[{"id":"t-9","type":"pattern","claim":"Fifth","source":"e.go"}]'

expect claims-set-meta t_extracted_at 0 claims set-meta --claims "$CL/seq.yml" --topic t --sha deadbee
check claims-set-meta-written "$(grep -c '  t_extracted_at: deadbee' "$CL/seq.yml")" 1
expect claims-set-meta-second-topic u_extracted_at 0 \
  claims set-meta --claims "$CL/seq.yml" --topic u --sha cafe123
check claims-set-meta-keeps-first "$(grep -c '  t_extracted_at: deadbee' "$CL/seq.yml")" 1
expect claims-set-meta-missing-file "" 3 claims set-meta --claims "$CL/gone.yml" --topic t --sha deadbee

# --- writer file handling -------------------------------------------------
printf -- '---\r\nscribe:\r\n  freshness: 50\r\n---\r\n# Topic\r\n\r\n## Alpha\r\n' > "$SW/crlf-topic.md"
sed -n '/^# Topic/,$p' "$SW/crlf-topic.md" > "$SW/crlf-body-before"
expect fm-crlf-stamp '{"freshness":100,"scan":"deadbee"}' 0 \
  fm stamp "$SW/crlf-topic.md" --scan deadbee --freshness 100
sed -n '/^# Topic/,$p' "$SW/crlf-topic.md" > "$SW/crlf-body-after"
cmp -s "$SW/crlf-body-before" "$SW/crlf-body-after"; check fm-crlf-body-identical "$?" 0
# every LF in the rewritten file is still half of a CRLF pair
check fm-crlf-preserved \
  "$(tr -cd '\r' < "$SW/crlf-topic.md" | wc -c | tr -d '[:space:]')" \
  "$(tr -cd '\n' < "$SW/crlf-topic.md" | wc -c | tr -d '[:space:]')"

printf -- '# Topic\n\n## Alpha\n' > "$SW/bare.md"
expect fm-bare-stamp '{"freshness":100,"scan":"deadbee"}' 0 \
  fm stamp "$SW/bare.md" --scan deadbee --freshness 100
check fm-bare-opens-block "$(head -1 "$SW/bare.md")" '---'
expect fm-bare-block-parses '{"freshness":100,"scan":"deadbee"}' 0 fm read "$SW/bare.md"
check fm-bare-body-survives "$(sed -n '/^# Topic/,$p' "$SW/bare.md" | tr -d '\n')" '# Topic## Alpha'

printf -- '---\nscribe: [oops\n---\n# Topic\n' > "$SW/bad.md"
cp "$SW/bad.md" "$SW/bad.bak"
expect fm-malformed-dies "" 3 fm question-pass "$SW/bad.md"
cmp -s "$SW/bad.md" "$SW/bad.bak"; check fm-malformed-leaves-file "$?" 0

printf -- '---\nscribe:\n  freshness: 50\n# Topic\n' > "$SW/unclosed.md"
cp "$SW/unclosed.md" "$SW/unclosed.bak"
expect fm-unclosed-dies "" 3 fm question-pass "$SW/unclosed.md"
cmp -s "$SW/unclosed.md" "$SW/unclosed.bak"; check fm-unclosed-leaves-file "$?" 0

# --- operational errors ---------------------------------------------------
expect error-missing-file "" 3 tier "$TMP/no-such-file.md"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
