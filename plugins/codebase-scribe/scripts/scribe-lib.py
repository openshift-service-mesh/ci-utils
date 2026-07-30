#!/usr/bin/env python3
# Canonical implementations of the deterministic computations the codebase-scribe
# skill prompts used to describe in prose. The --help text of each subcommand is
# the definition of record: prompts reference it instead of restating the rules,
# so it must stay complete and exact.
import argparse
import codecs
import difflib
import json
import math
import os
import re
import subprocess
import sys
import typing

SKIP_DIRS = {".git", "node_modules", "vendor", "dist", "_output", "__pycache__", ".build"}
STUB_MARKER = "*Stub — will be populated"
MANAGED_MARKER = "<!-- scribe:managed -->"
APPEND_ONLY_MARKER = "<!-- scribe:managed:append-only -->"
HEADING_RE = re.compile(r"^(#{1,6})[ \t]+(.*)$")
SCAN_RE = re.compile(r"^[ \t]*scan:[ \t]*(.*)$")
SHA_RE = re.compile(r"[0-9a-f]{7,40}")
INLINE_LINK_RE = re.compile(r"\[[^\]]*\]\([ \t]*([^)\s]*)")
REF_LINK_RE = re.compile(r"^\[[^\]]*\]:[ \t]*(\S+)")

SHARED_RULES = """\
SHARED PARSING RULES (identical to the doc-validate.sh hook)

  Encoding: files are read as UTF-8 with a leading byte-order mark tolerated and
  discarded, and one trailing carriage return is stripped from every line, so a
  CRLF file parses exactly like the same file with LF endings.

  Frontmatter: when line 1 is exactly "---", every line from there through the
  next line that is exactly "---" is frontmatter; everything after that closing
  line is the "body". A file that opens a frontmatter block and never closes it
  has an empty body. A file whose line 1 is not exactly "---" is body from line
  1 onward.

  Fences: a body line that starts at column 0 with "```" or "~~~" toggles fenced
  state, and only the marker that opened a fence closes it -- a "```" line
  inside a "~~~" block is fenced content, and a "~~~" line inside a "```" block
  likewise. Fenced lines, and the fence marker lines themselves, are invisible
  to heading, section and stub-marker detection, but they still count as body
  content for the purpose of deciding whether a body is empty.

  Headings: a heading is an unfenced body line matching one to six "#"
  characters followed by at least one space or tab, then the heading text. The
  heading text is everything after that separator, with trailing whitespace
  removed; a trailing "#" closing sequence is NOT stripped.

  Slug (GitHub-flavored): lowercase the text, keep only alphanumerics (any
  Unicode alphanumeric character), spaces and hyphens, then turn every space
  into a hyphen. Runs of hyphens are NOT collapsed and leading/trailing hyphens
  are NOT trimmed, so "Patterns & Conventions" slugs to "patterns--conventions"
  -- the "&" is dropped and both spaces that surrounded it become hyphens.

EXIT CODES

  0  success
  3  operational error (file missing or unreadable, git not runnable); the
     reason is written to stderr and nothing is written to stdout.

  validate-sha additionally uses exit codes 1 and 2 to carry its verdict; see
  "scribe-lib.py validate-sha --help".
"""

SECTIONS_HELP = """\
Print the fence-aware headings of FILE, one per line, as three tab-separated
fields:

    <level><TAB><slug><TAB><heading text>

Headings inside frontmatter or inside a fenced block are not printed. Only
levels 2 and 3 are ever printed; a level-1 heading is never printed and never
resets level-3 parent scoping.

  --level 2    (default) print only "##" headings
  --level 3    print only "###" headings
  --level all  print both, in document order

A level-2 slug is the slug of its own heading text. A level-3 slug is
parent-scoped: the slug of the nearest preceding level-2 heading, then "/",
then the slug of its own heading text. A level-3 heading with no preceding
level-2 heading anywhere above it uses its own slug alone, with no "/".

The <heading text> field is the heading with the leading "#" characters and the
separating whitespace removed; it is printed verbatim otherwise, so it may
contain characters the slug drops.

A file with no qualifying headings prints nothing and exits 0.
"""

SLUG_HELP = """\
Print the GitHub-flavored slug of TEXT.

The text is lowercased; every character that is not a Unicode alphanumeric, a
space or a hyphen is dropped; every remaining space becomes a hyphen. Hyphen
runs are not collapsed and leading/trailing hyphens are not trimmed.

    scribe-lib.py slug "Patterns & Conventions"   ->  patterns--conventions
    scribe-lib.py slug "Key Entry Points"         ->  key-entry-points

TEXT is taken as a single argument, so quote it. This is the same function the
sections subcommand applies to heading text; nothing here is parent-scoped.
"""

TIER_HELP = """\
Print the maturity tier of FILE: exactly the word "stub" or the word "mature".

The tier is "stub" when EITHER of these holds:

  * the body (everything after the frontmatter block) contains zero non-blank
    lines -- a line consisting only of whitespace is blank, and a fence marker
    line is not blank, so a body that is nothing but an empty code fence is NOT
    a stub by this rule; or
  * at least one UNFENCED body line begins, at column 0, with the exact prefix
    "*Stub — will be populated" (that is an em dash, U+2014). A line that merely
    mentions the marker mid-sentence does not match, and the same marker quoted
    inside a "```" or "~~~" fence does not match either.

Otherwise the tier is "mature".
"""

VALIDATE_SHA_HELP = """\
Validate a scan SHA against the git repository in the current working directory.
Prints exactly one word on stdout and encodes the same verdict in the exit code:

    null           exit 2   SHA is the empty string or the literal text "null"
    shape          exit 1   SHA does not match ^[0-9a-f]{7,40}$ (lowercase hex,
                            7 to 40 characters, whole string; no uppercase, no
                            surrounding whitespace)
    unresolvable   exit 1   shape is fine but `git cat-file -e SHA` fails, so no
                            object with that name exists in this repository
    unreachable    exit 1   the object exists but `git merge-base --is-ancestor
                            SHA HEAD` fails, so it is not an ancestor of HEAD
    valid          exit 0   the object exists and is an ancestor of HEAD

The checks run in that order and stop at the first failure. Both git commands
run in the current working directory, so the caller chooses the repository by
choosing where it runs this. If git itself cannot be executed the command
reports the error on stderr and exits 3 instead.
"""

HUMAN_INPUT_HELP = """\
Print an integer 0-100: the percentage of FILE's fence-aware level-2 sections
that the caller named in --slugs.

    score = round( (matched / total) * 100 )

where "total" is the number of fence-aware "##" headings in FILE, and "matched"
is the number of DISTINCT values in --slugs that equal the slug of one of those
headings. Values are compared literally against the slugs, so pass slugs (as
printed by the sections or slug subcommand), not raw heading text. Duplicates in
--slugs count once; a value matching no section contributes nothing and is not
an error.

--slugs takes one comma-separated argument. Surrounding whitespace is stripped
from each value and empty values are discarded, so --slugs "" is valid and
scores 0.

When FILE has zero "##" sections the score is 0 (no division is attempted).

Rounding is half-up: an exact .5 rounds away from zero, so 1 of 8 sections
scores 13, not 12.
"""

COMPLETENESS_HELP = """\
Print an integer 0-100: the percentage of watched source subdirectories that
FILE mentions.

The population is the union of the depth-1 subdirectories of every WATCH_PATH.
A WATCH_PATH that does not exist, or that is a file rather than a directory,
contributes nothing and is not an error. Subdirectories are identified by their
path relative to the current working directory, so the same directory reached
through two WATCH_PATH spellings is counted once. Subdirectories named .git,
node_modules, vendor, dist, _output, __pycache__ or .build are excluded from
the population, and directories with those names are also skipped while
descending, so files beneath them never count as evidence. (The exclusion is a
deliberate 1.4.0 change: the pre-1.4 prose formula counted every depth-1
subdirectory, vendored ones included, which penalized topics for not citing
dependency code the drafting skill is forbidden from reading.)

A subdirectory is "covered" when at least one file anywhere beneath it
(recursively) has its path -- taken relative to the current working directory
and written with forward slashes -- appearing as a substring of FILE's body.
FILE's frontmatter is excluded from that search; fenced blocks are NOT excluded,
because a path cited inside a code fence is still a citation.

    score = round( (covered / total) * 100 )

When the population is empty the score is 0. Rounding is half-up.
"""

CLASSIFY_HELP = """\
Classify the change between a snapshot of a topic file and its current content.
Prints exactly one of: major_rewrite, new_draft, claim_change, section_change,
large_diff, minor_mechanical.

The rules are applied IN THIS ORDER and the first one that matches wins; no
later rule is evaluated:

  a. --snapshot S does not exist                            -> major_rewrite
  b. S is zero bytes                                        -> new_draft
     otherwise read "scan" from S's frontmatter: the first line inside the
     frontmatter block matching optional whitespace, then "scan:", then the
     value. The value is stripped of surrounding whitespace and then of one
     pair of matching surrounding quotes. A value that is empty, the literal
     "null" or the literal "~" -- and a snapshot with no frontmatter or no
     scan key at all -- counts as null      -> null gives    new_draft
  c. changed lines > 50% of FILE's total line count         -> major_rewrite
     "changed lines" is the number of insertion plus deletion lines in a
     unified diff of S against FILE (Python difflib, whole files including
     frontmatter). The rule is skipped when FILE has zero lines.
  d. --snapshot-claims and --current-claims differ          -> claim_change
     compared as line lists with trailing whitespace stripped from each line;
     blank lines are significant; a missing file reads as an empty list.
  e. FILE's fence-aware "##" heading TEXTS, in document order, differ from the
     lines of --snapshot-headings                           -> section_change
     the snapshot headings have trailing whitespace stripped and blank lines
     dropped; a missing file reads as an empty list. Heading text is compared,
     not slugs, so a reworded heading is a section change.
  f. changed lines > --threshold N                          -> large_diff
  g. none of the above                                      -> minor_mechanical

Because the order is strict, a change that alters both claims and headings is
reported as claim_change, and a snapshot with a null scan is new_draft however
small the diff is.
"""

HUB_STATE_HELP = """\
Classify the AGENTS.md hub FILE. Prints exactly one word:

    absent        FILE does not exist. This is a classification and not an
                  error: the exit code is 0 and stderr stays empty.
    append-only   a marker line for "<!-- scribe:managed:append-only -->" is
                  present.
    managed       a marker line for "<!-- scribe:managed -->" is present and
                  no append-only marker line is.
    unmarked      FILE exists and carries no marker line.

A MARKER LINE is a line outside every fenced block whose entire content, once
surrounding whitespace is stripped, is exactly the marker string. Fences work
as they do everywhere else here: a column-0 "```" or "~~~" opens a block and
only the marker that opened it closes it. A marker occurring in any other
position -- inside a fence, in a sentence, or embedded in a longer line -- is
not a marker line, so a hub that merely documents the convention classifies
"unmarked" and is never silently adopted.

When both marker lines are present, append-only wins whichever comes first: it
is the more restrictive mode, and a file the scribe may only append to must
never be widened to full management by a stray second marker.

Nothing is special-cased for hubs, so the shared frontmatter rule applies
unchanged even though hubs carry no frontmatter: in a FILE whose line 1 is
exactly "---", the lines through the next "---" are frontmatter and are not
searched for markers.
"""

HUB_LINKS_HELP = """\
Print the destination of every topic link in FILE, one per line, in document
order. Both markdown link spellings are read:

  * inline links, "[text](dest)" -- every occurrence on a line is found, not
    only the first;
  * reference-style definitions, "[label]: dest" -- recognised only when "["
    is the first character of the line, so an indented definition is not one.

The destination is the text up to the first whitespace or ")", which drops a
title: "[t](dest "Title")" yields dest alone. An angle-bracketed
destination, "[t](<dest>)", is not unwrapped.

A destination is a TOPIC LINK when, after a single leading "./" is stripped,
it is exactly the --docs-dir value D or begins with D followed by "/". The
test is over whole path segments and never a bare string prefix: with
--docs-dir docs/agents, "docs/agents" and "docs/agents/api.md" match while
"docs/agents-old/api.md" and "docs/agentsx" do not. D is used exactly as
given, so a trailing slash on it is not stripped. The destination is printed
after the "./" strip, so "./docs/agents/api.md" prints "docs/agents/api.md".

Fenced blocks are NOT skipped, unlike everywhere else in this program: the
plugin defines link matching over the whole file, so a link inside a "```" or
"~~~" block counts like any other.

When one line holds both a reference definition and inline links, the
definition is printed first. A FILE with no topic links prints nothing and
exits 0; a FILE that does not exist is an error and exits 3.
"""

REPAIR_WATCH_PATHS_HELP = """\
Apply the plugin's "directories forever" repair to each PATH, in the order
given, and print one tab-separated line per surviving entry:

    <repaired><TAB><original><TAB><status>

Each entry is repaired on its own:

  1. Trailing "/" and "\\" characters are stripped, then every remaining "\\"
     becomes "/", so "src\\lib\\" and "src/lib" repair alike.
  2. While the value does not name an existing directory -- resolved against
     the current working directory, so the caller chooses the tree by
     choosing where it runs this -- and still has more than one segment, its
     last segment is dropped. A file-scoped entry is therefore widened to the
     directory holding it, which is the accepted cost of the rule.
  3. A single-segment value is never modified, even when nothing by that name
     exists: the scope is preserved rather than silently discarded.

Entries are then deduplicated ON THE REPAIRED VALUE with the first occurrence
winning, so two entries that repair to the same directory print one line,
carrying the first entry's <original>; the later duplicates print nothing.

<status> is one of:

    ok           the repaired value names an existing directory, or is a
                 preserved single-segment value naming an existing file.
    unresolved   the repaired value is a preserved single-segment value
                 naming neither a directory nor a file. The scope is
                 drift-blind and the plugin reports it to the user.

The repair is total, so the exit code is 0 whatever the statuses are. Giving
no PATH at all is an error and exits 3.
"""


FM_RULES = """\
STATE-WRITER RULES (every fm and claims verb)

  These subcommands rewrite files, and they need PyYAML. Without it they write
  nothing and exit 3.

  Frontmatter: a topic file opens with a line that is exactly "---", carries a
  YAML block, closes with another "---", and everything after that closing line
  is the body. All scribe state lives under the top-level "scribe:" mapping. A
  writer loads the whole frontmatter, changes only the keys its own description
  names inside "scribe:", and re-emits the whole mapping, so every other key --
  inside "scribe:" and beside it -- survives. This is the preservation clause,
  and it is the reason these verbs exist.

  A file with no frontmatter gains one holding only the keys the verb writes.
  These are errors, and each leaves the file exactly as it was and exits 3: a
  frontmatter block that is opened and never closed, frontmatter that is not
  valid YAML, frontmatter that is not a mapping, and a "scribe:" value that is
  not a mapping.

  YAML COMMENTS INSIDE FRONTMATTER DO NOT SURVIVE A WRITER CALL. Neither does
  quoting style, key indentation or blank-line placement: the frontmatter is
  re-emitted by the YAML dumper in block style with the key order it was read
  in, and non-ASCII characters are written as themselves. Only the body is
  preserved, and it is preserved byte for byte.

  Encoding: input is read as UTF-8 with a leading byte-order mark tolerated;
  the mark is NOT written back. Line endings are detected from the bytes read
  -- a file containing a CRLF is rewritten with CRLF throughout its
  frontmatter, any other file with LF -- and the body keeps whatever endings it
  already had.

  Claims file: a YAML mapping whose "claims:" key holds a list of
  {id, type, topic, claim, source, provenance{origin[,context,recorded]}}
  entries, alongside the optional "_retired_ids:" list, "_meta:" mapping and
  "contradictions:" list. It is loaded and re-emitted under the same rules; it
  has no body.

  Two-file verbs (retire-decision, refresh-decision) validate both files and
  resolve the named id before writing either, so a failure never leaves the
  topic file and the claims file disagreeing.

EXIT CODES

  0  success
  3  operational error: a file is missing or unreadable, PyYAML is missing, the
     YAML is malformed, an argument does not parse, or a named id is absent.
     The reason is written to stderr, nothing is written to stdout, and no file
     is modified.
"""

FM_HELP = """\
Read and write the "scribe:" frontmatter mapping of a topic file.

Each verb is one enforced state write: it names the keys it touches, leaves
every other key alone, and prints what it wrote. See "scribe-lib.py fm VERB
--help" for the verb's definition.
"""

CLAIMS_HELP = """\
Read and write a .claims.yml file.

Each verb is one enforced state write. See "scribe-lib.py claims VERB --help"
for the verb's definition.
"""

FM_READ_HELP = """\
Print FILE's "scribe:" mapping as one line of compact JSON with sorted keys.

A file with no frontmatter, frontmatter without a "scribe:" key, and a
"scribe:" key with an empty value all print "{}". FILE is not modified.
"""

FM_UPDATE_HELP = """\
Merge --json into FILE's "scribe:" mapping, then remove the --unset keys.
Prints the resulting mapping as compact JSON with sorted keys.

--json takes one JSON OBJECT. Each of its top-level keys replaces the key of
that name inside "scribe:" WHOLESALE -- a mapping or list value is not merged
element-wise -- and creates it when absent. Keys the object does not name are
untouched, which is the preservation clause.

--unset takes one comma-separated list of key names, applied after the merge,
so naming a key in both writes it and then removes it. Surrounding whitespace
is stripped from each name and empty names are discarded. Removing a key that
is not there is not an error.
"""

FM_STAMP_HELP = """\
Set scribe.scan to SHA and scribe.freshness to N, and print them back as
compact JSON with sorted keys.

SHA is written verbatim: this verb does not validate it (see "scribe-lib.py
validate-sha --help") and never invents one. N must parse as an integer.
"""

FM_CREDIT_SECTION_HELP = """\
Credit SLUG to the SME and recompute the human-input score. Prints compact
JSON with sorted keys: the resulting human_sections list and human_input.

Three keys are written, in one call, because doing them separately is what
drops steps:

  * scribe.human_sections gains SLUG. The list has set semantics with the
    existing order preserved and the new value appended, so crediting the same
    slug twice cannot inflate the score.
  * scribe.inferred_sections loses every entry whose "id" equals SLUG. Entries
    are compared by whole id, so a subsection entry ("patterns--conventions/
    error-handling") is never removed by crediting its parent -- only the
    top-level entry goes. A plain string entry is compared as itself. The key
    is only written when FILE already had it: crediting a section never
    introduces an empty inferred_sections.
  * scribe.human_input is recomputed from the CURRENT body as
    round( (matched / total) * 100 ), where "total" is the number of
    fence-aware "##" headings and "matched" is the number of DISTINCT
    human_sections values equal to one of their slugs. A credited slug with no
    matching heading contributes nothing and is not an error. Zero sections
    scores 0. Rounding is half-up.

SLUG is a slug, not heading text -- see "scribe-lib.py slug --help".
"""

FM_QUESTION_PASS_HELP = """\
Add one to scribe.question_passes and print the new value.

An absent counter, and a "question_passes:" key with an empty value, both count
as 0, so the first call prints 1. A counter that is not an integer is an error.
"""

FM_SETTLE_HELP = """\
Apply the settling rule to scribe.question_passes. Prints exactly one word:

    settled   question_passes is 2 AND human_input is 0. The topic has been
              asked twice with nothing to show for it, so the counter stays
              where it is and FILE is not modified at all.
    reset     anything else. question_passes is set to 0.

Both values are read from "scribe:", and an absent value -- or one with an
empty value -- counts as 0 for both. A value that is not an integer is an
error.
"""

FM_RETIRE_DECISION_HELP = """\
Retire decision ID across FILE and the claims file. Prints compact JSON with
sorted keys: {claim_removed, id, resolved_at, status}.

In FILE, the entry in scribe.decisions whose "id" equals ID gets
"status: retired" -- a tombstone, which is why no path deletes the entry. ID
having no entry is an error.

--resolved-at SHA additionally writes "resolved_at: SHA" on that entry. Without
the option no resolved_at is written and none is invented; the reported value
is then null.

In the claims file at PATH, which must exist:

  * the claim whose "id" equals ID is removed from "claims:" if it is there.
    claim_removed reports whether it was.
  * ID is appended to "_retired_ids", which is created when absent. The list
    has set semantics, so retiring twice does not duplicate the entry. The ID
    stays reserved forever, which is what stops it being handed out again.

Nothing else in either file is touched.
"""

FM_REFRESH_DECISION_HELP = """\
Refresh decision ID across FILE and the claims file. Prints compact JSON with
sorted keys: {claim_updated, context, id, recorded, resolved_at}.

In FILE, the entry in scribe.decisions whose "id" equals ID gets
"recorded: DATE", plus "context: TEXT" with --context and
"resolved_at: SHA" with --resolved-at. Each optional value is written only when
its option is given, and none is invented; an option not given is reported
null. ID having no entry is an error, and so is an entry carrying
"status: retired" -- retired entries are never updated.

In the claims file at PATH, which must exist, the claim whose "id" equals ID
gets "recorded" -- and "context" with --context -- written inside its
"provenance" mapping, which is created when the claim has none. A claims file
with no such claim is not an error: claim_updated reports false, and the
frontmatter write still happens.

Nothing else in either file is touched.
"""

FM_REMOVE_STALE_FLAG_HELP = """\
Remove every entry whose "id" equals ID from scribe.stale_flags and print how
many were removed.

An absent stale_flags list, and an ID matching nothing, both print 0. FILE is
rewritten only when the count is non-zero, so a no-op call cannot reformat the
frontmatter.
"""

CLAIMS_ADD_HELP = """\
Add claims for topic T to the claims file, reusing the id of any claim already
there. Prints compact JSON with sorted keys: {added, matched}, each a list of
ids in the order the input gave them.

The file is CREATED when it does not exist -- extraction is never conditional
on it already existing.

--json takes one JSON ARRAY of objects. Each object carries "type", "claim",
"source" and optionally "provenance"; an object carrying an "id" is an error,
because assigning ids is this verb's job and honouring an incoming one would
corrupt the sequence. "type" and "claim" are required. Any other key is copied
through, and "topic" is always set to T whatever the object says.

Each object is then either matched or added:

  * MATCHED when an existing claim has the same "type", has topic T, and its
    claim text agrees on the FIRST 50 CHARACTERS. The existing entry keeps its
    id and is not otherwise modified -- no field is overwritten, which is what
    makes re-extraction idempotent.
  * ADDED otherwise, with the id "<T>-<N>". N starts above every number already
    spoken for by topic T: the suffix of every existing claim of that topic,
    of every id in "_retired_ids", and of every id passed to --reserved
    (a comma-separated list -- pass the topic's frontmatter decision ids there,
    active and retired alike). Numbering never goes backwards and a retired id
    is never reused. Within one call each added claim reserves its own number,
    so ids stay consecutive.

Ids for other topics, and ids that do not end in "-<digits>", reserve nothing.
"""

CLAIMS_SET_META_HELP = """\
Set "_meta.<T>_extracted_at" to SHA in the claims file, which must exist, and
print the key that was written.

"_meta" is created when absent. No other key under it is touched, so recording
one topic's extraction point never disturbs another's. SHA is written verbatim
and is not validated.
"""


def die(message) -> "typing.NoReturn":
    sys.stderr.write("scribe-lib: %s\n" % message)
    raise SystemExit(3)


def read_lines(path):
    try:
        with open(path, encoding="utf-8-sig") as handle:
            text = handle.read()
    except (OSError, UnicodeDecodeError) as exc:
        die(str(exc))
    lines = text.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    return [line[:-1] if line.endswith("\r") else line for line in lines]


def read_lines_or_empty(path):
    if not os.path.exists(path):
        return []
    return read_lines(path)


def body_lines(lines):
    if lines and lines[0] == "---":
        for index in range(1, len(lines)):
            if lines[index] == "---":
                return lines[index + 1:]
        return []
    return lines


# Yields (line, fenced) over the body. `fenced` is true for fence marker lines
# themselves as well as for their contents, which is what makes a marker
# invisible to heading detection while still counting as body content.
def scan_body(lines):
    return scan_fenced(body_lines(lines))


def scan_fenced(lines):
    fence = None
    for line in lines:
        if line.startswith("```") or line.startswith("~~~"):
            mark = line[:3]
            if fence is None:
                fence = mark
            elif mark == fence:
                fence = None
            yield line, True
        else:
            yield line, fence is not None


def slug(text):
    kept = [c for c in text.lower() if c.isalnum() or c in " -"]
    return "".join(kept).replace(" ", "-")


def headings(lines):
    return fenced_headings(scan_body(lines))


def fenced_headings(scanned):
    found = []
    parent = None
    for line, fenced in scanned:
        if fenced:
            continue
        match = HEADING_RE.match(line)
        if not match:
            continue
        level = len(match.group(1))
        text = match.group(2).rstrip()
        if level == 2:
            parent = slug(text)
            found.append((2, parent, text))
        elif level == 3:
            own = slug(text)
            found.append((3, own if parent is None else parent + "/" + own, text))
    return found


def percent(part, total):
    return int(math.floor(part * 100.0 / total + 0.5))


def changed_line_count(old, new):
    # Skip the two file headers by position, not by prefix: a deleted "---"
    # content line renders as "----" and would be dropped by a prefix test.
    lines = list(difflib.unified_diff(old, new, lineterm=""))
    return sum(1 for line in lines[2:] if line.startswith(("+", "-")))


def frontmatter_scan(lines):
    if not lines or lines[0] != "---":
        return None
    for line in lines[1:]:
        if line == "---":
            return None
        match = SCAN_RE.match(line)
        if not match:
            continue
        value = match.group(1).strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1].strip()
        return None if value in ("", "null", "~") else value
    return None


def rel_posix(path):
    return os.path.relpath(path, os.getcwd()).replace(os.sep, "/")


def run_git(args):
    try:
        return subprocess.call(
            ["git"] + args,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except OSError as exc:
        die("could not run git: %s" % exc)


def cmd_sections(args):
    wanted = {"2": (2,), "3": (3,), "all": (2, 3)}[args.level]
    for level, name, text in headings(read_lines(args.file)):
        if level in wanted:
            print("%d\t%s\t%s" % (level, name, text))
    return 0


def cmd_slug(args):
    print(slug(args.text))
    return 0


def cmd_tier(args):
    nonblank = False
    marker = False
    for line, fenced in scan_body(read_lines(args.file)):
        if line.strip():
            nonblank = True
        if not fenced and line.startswith(STUB_MARKER):
            marker = True
    print("stub" if (not nonblank or marker) else "mature")
    return 0


def cmd_validate_sha(args):
    sha = args.sha
    if sha == "" or sha == "null":
        print("null")
        return 2
    if not SHA_RE.fullmatch(sha):
        print("shape")
        return 1
    if run_git(["cat-file", "-e", sha]) != 0:
        print("unresolvable")
        return 1
    if run_git(["merge-base", "--is-ancestor", sha, "HEAD"]) != 0:
        print("unreachable")
        return 1
    print("valid")
    return 0


def cmd_human_input(args):
    level2 = [h for h in headings(read_lines(args.file)) if h[0] == 2]
    if not level2:
        print(0)
        return 0
    existing = {h[1] for h in level2}
    given = {value.strip() for value in args.slugs.split(",")} - {""}
    print(percent(len(given & existing), len(level2)))
    return 0


def cmd_completeness(args):
    body = "\n".join(body_lines(read_lines(args.file)))
    subdirs = {}
    for watch in args.watch_path:
        if not os.path.isdir(watch):
            continue
        try:
            names = os.listdir(watch)
        except OSError as exc:
            die(str(exc))
        for name in names:
            if name in SKIP_DIRS:
                continue
            full = os.path.join(watch, name)
            if os.path.isdir(full):
                subdirs[rel_posix(full)] = full
    if not subdirs:
        print(0)
        return 0
    covered = 0
    for full in subdirs.values():
        if _mentions_any_file(full, body):
            covered += 1
    print(percent(covered, len(subdirs)))
    return 0


def _mentions_any_file(root, body):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            if rel_posix(os.path.join(dirpath, name)) in body:
                return True
    return False


def cmd_classify(args):
    print(_classification(args))
    return 0


def _classification(args):
    if not os.path.exists(args.snapshot):
        return "major_rewrite"
    if os.path.getsize(args.snapshot) == 0:
        return "new_draft"

    snapshot = read_lines(args.snapshot)
    if frontmatter_scan(snapshot) is None:
        return "new_draft"

    current = read_lines(args.file)
    changed = changed_line_count(snapshot, current)
    if current and changed * 2 > len(current):
        return "major_rewrite"

    old_claims = [l.rstrip() for l in read_lines_or_empty(args.snapshot_claims)]
    new_claims = [l.rstrip() for l in read_lines_or_empty(args.current_claims)]
    if old_claims != new_claims:
        return "claim_change"

    old_headings = [l.rstrip() for l in read_lines_or_empty(args.snapshot_headings) if l.strip()]
    if [h[2] for h in headings(current) if h[0] == 2] != old_headings:
        return "section_change"

    if changed > args.threshold:
        return "large_diff"
    return "minor_mechanical"


def cmd_hub_state(args):
    if not os.path.exists(args.file):
        print("absent")
        return 0
    managed = False
    append_only = False
    for line, fenced in scan_body(read_lines(args.file)):
        if fenced:
            continue
        stripped = line.strip()
        if stripped == APPEND_ONLY_MARKER:
            append_only = True
        elif stripped == MANAGED_MARKER:
            managed = True
    if append_only:
        print("append-only")
    else:
        print("managed" if managed else "unmarked")
    return 0


def cmd_hub_links(args):
    for line in read_lines(args.file):
        destinations = []
        reference = REF_LINK_RE.match(line)
        if reference:
            destinations.append(reference.group(1))
        destinations.extend(m.group(1) for m in INLINE_LINK_RE.finditer(line))
        for dest in destinations:
            topic = _topic_link(dest, args.docs_dir)
            if topic is not None:
                print(topic)
    return 0


def _topic_link(dest, docs_dir):
    if dest.startswith("./"):
        dest = dest[2:]
    if dest == docs_dir or dest.startswith(docs_dir + "/"):
        return dest
    return None


def cmd_repair_watch_paths(args):
    if not args.path:
        die("repair-watch-paths needs at least one PATH")
    seen = set()
    for original in args.path:
        repaired = _repair_watch_path(original)
        if repaired in seen:
            continue
        seen.add(repaired)
        resolved = os.path.isdir(repaired) or os.path.isfile(repaired)
        print("%s\t%s\t%s" % (repaired, original, "ok" if resolved else "unresolved"))
    return 0


def _repair_watch_path(value):
    value = value.rstrip("/\\").replace("\\", "/")
    while "/" in value and not os.path.isdir(value):
        value = value.rsplit("/", 1)[0]
    return value


# Imported here rather than at module scope so the read-only subcommands keep
# working on an interpreter without PyYAML.
def require_yaml():
    try:
        import yaml
    except ImportError:
        die("PyYAML is required for state-writer subcommands (pip install pyyaml)")
    return yaml


def strip_cr(line):
    return line[:-1] if line.endswith("\r") else line


def read_text(path):
    try:
        with open(path, "rb") as handle:
            raw = handle.read()
    except OSError as exc:
        die(str(exc))
    if raw.startswith(codecs.BOM_UTF8):
        raw = raw[len(codecs.BOM_UTF8):]
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        die("%s: %s" % (path, exc))
    return text, "\r\n" if "\r\n" in text else "\n"


def write_text(path, text):
    try:
        with open(path, "wb") as handle:
            handle.write(text.encode("utf-8"))
    except OSError as exc:
        die(str(exc))


def parse_yaml(text, what):
    yaml = require_yaml()
    try:
        data = yaml.safe_load(text)
    except yaml.YAMLError as exc:
        die("%s is not valid YAML: %s" % (what, str(exc).replace("\n", " ")))
    if data is None:
        return {}
    if not isinstance(data, dict):
        die("%s is not a YAML mapping" % what)
    return data


def dump_yaml(data):
    return require_yaml().safe_dump(
        data,
        sort_keys=False,
        allow_unicode=True,
        default_flow_style=False,
    )


# The body is returned as a raw slice of the decoded file, carriage returns and
# all, so re-emitting it cannot perturb a byte the verb did not mean to touch.
def load_topic(path):
    require_yaml()
    text, newline = read_text(path)
    pieces = text.split("\n")
    if not pieces or strip_cr(pieces[0]) != "---":
        return {}, text, newline
    for index in range(1, len(pieces)):
        if strip_cr(pieces[index]) == "---":
            block = "\n".join(strip_cr(piece) for piece in pieces[1:index])
            return parse_yaml(block, "frontmatter"), "\n".join(pieces[index + 1:]), newline
    die("%s: frontmatter block is opened and never closed" % path)


def save_topic(path, data, body, newline):
    front = "---\n" + dump_yaml(data) + "---\n"
    write_text(path, front.replace("\n", newline) + body)


def load_yaml_file(path):
    if not os.path.exists(path):
        die("%s: no such file" % path)
    text, newline = read_text(path)
    return parse_yaml(text, path), newline


def save_yaml_file(path, data, newline):
    write_text(path, dump_yaml(data).replace("\n", newline))


def scribe_slot(data):
    value = data.get("scribe")
    if value is None:
        value = {}
        data["scribe"] = value
    elif not isinstance(value, dict):
        die('frontmatter key "scribe" is not a mapping')
    return value


def as_list(container, key, what):
    value = container.get(key)
    if value is None:
        return []
    if not isinstance(value, list):
        die("%s is not a list" % what)
    return value


def as_int(value, what):
    if value is None:
        return 0
    if isinstance(value, bool) or not isinstance(value, int):
        die("%s is not an integer" % what)
    return value


def entry_id(entry):
    return entry.get("id") if isinstance(entry, dict) else entry


def as_json(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), default=str)


def parse_json_arg(text, kind, what):
    try:
        value = json.loads(text)
    except ValueError as exc:
        die("--json does not parse: %s" % exc)
    if not isinstance(value, kind):
        die("--json must be a JSON %s" % what)
    return value


def csv_values(text):
    if not text:
        return []
    return [value for value in (item.strip() for item in text.split(",")) if value]


def body_sections(body):
    lines = body.split("\n")
    if lines and lines[-1] == "":
        lines.pop()
    scanned = scan_fenced(strip_cr(line) for line in lines)
    return [h for h in fenced_headings(scanned) if h[0] == 2]


def find_decision(scribe, ident):
    for entry in as_list(scribe, "decisions", "scribe.decisions"):
        if isinstance(entry, dict) and entry.get("id") == ident:
            return entry
    die('no scribe.decisions entry with id "%s"' % ident)


def cmd_fm_read(args):
    data, _body, _newline = load_topic(args.file)
    value = data.get("scribe")
    if value is not None and not isinstance(value, dict):
        die('frontmatter key "scribe" is not a mapping')
    print(as_json(value if value else {}))
    return 0


def cmd_fm_update(args):
    incoming = parse_json_arg(args.json, dict, "object")
    data, body, newline = load_topic(args.file)
    scribe = scribe_slot(data)
    scribe.update(incoming)
    for key in csv_values(args.unset):
        scribe.pop(key, None)
    save_topic(args.file, data, body, newline)
    print(as_json(scribe))
    return 0


def cmd_fm_stamp(args):
    data, body, newline = load_topic(args.file)
    scribe = scribe_slot(data)
    scribe["scan"] = args.scan
    scribe["freshness"] = args.freshness
    save_topic(args.file, data, body, newline)
    print(as_json({"scan": args.scan, "freshness": args.freshness}))
    return 0


def cmd_fm_credit_section(args):
    data, body, newline = load_topic(args.file)
    scribe = scribe_slot(data)
    human = as_list(scribe, "human_sections", "scribe.human_sections")
    if args.slug not in human:
        human = human + [args.slug]
    if "inferred_sections" in scribe:
        inferred = as_list(scribe, "inferred_sections", "scribe.inferred_sections")
        scribe["inferred_sections"] = [e for e in inferred if entry_id(e) != args.slug]
    scribe["human_sections"] = human
    level2 = body_sections(body)
    matched = len({h[1] for h in level2} & set(human))
    scribe["human_input"] = percent(matched, len(level2)) if level2 else 0
    save_topic(args.file, data, body, newline)
    print(as_json({"human_sections": human, "human_input": scribe["human_input"]}))
    return 0


def cmd_fm_question_pass(args):
    data, body, newline = load_topic(args.file)
    scribe = scribe_slot(data)
    count = as_int(scribe.get("question_passes"), "scribe.question_passes") + 1
    scribe["question_passes"] = count
    save_topic(args.file, data, body, newline)
    print(count)
    return 0


def cmd_fm_settle(args):
    data, body, newline = load_topic(args.file)
    scribe = scribe_slot(data)
    passes = as_int(scribe.get("question_passes"), "scribe.question_passes")
    human = as_int(scribe.get("human_input"), "scribe.human_input")
    if passes == 2 and human == 0:
        print("settled")
        return 0
    scribe["question_passes"] = 0
    save_topic(args.file, data, body, newline)
    print("reset")
    return 0


def cmd_fm_retire_decision(args):
    data, body, newline = load_topic(args.file)
    entry = find_decision(scribe_slot(data), args.id)
    claims, claims_newline = load_yaml_file(args.claims)
    entry["status"] = "retired"
    if args.resolved_at is not None:
        entry["resolved_at"] = args.resolved_at
    items = as_list(claims, "claims", "%s: claims" % args.claims)
    kept = [claim for claim in items if entry_id(claim) != args.id]
    removed = len(kept) != len(items)
    if removed:
        claims["claims"] = kept
    retired = as_list(claims, "_retired_ids", "%s: _retired_ids" % args.claims)
    claims["_retired_ids"] = retired if args.id in retired else retired + [args.id]
    save_topic(args.file, data, body, newline)
    save_yaml_file(args.claims, claims, claims_newline)
    print(as_json({
        "id": args.id,
        "status": "retired",
        "resolved_at": args.resolved_at,
        "claim_removed": removed,
    }))
    return 0


def cmd_fm_refresh_decision(args):
    data, body, newline = load_topic(args.file)
    entry = find_decision(scribe_slot(data), args.id)
    if entry.get("status") == "retired":
        die('decision "%s" is retired; retired entries are never updated' % args.id)
    claims, claims_newline = load_yaml_file(args.claims)
    entry["recorded"] = args.recorded
    if args.context is not None:
        entry["context"] = args.context
    if args.resolved_at is not None:
        entry["resolved_at"] = args.resolved_at
    updated = False
    for claim in as_list(claims, "claims", "%s: claims" % args.claims):
        if entry_id(claim) != args.id:
            continue
        provenance = claim.get("provenance")
        if not isinstance(provenance, dict):
            provenance = {}
            claim["provenance"] = provenance
        provenance["recorded"] = args.recorded
        if args.context is not None:
            provenance["context"] = args.context
        updated = True
    save_topic(args.file, data, body, newline)
    save_yaml_file(args.claims, claims, claims_newline)
    print(as_json({
        "id": args.id,
        "recorded": args.recorded,
        "context": args.context,
        "resolved_at": args.resolved_at,
        "claim_updated": updated,
    }))
    return 0


def cmd_fm_remove_stale_flag(args):
    data, body, newline = load_topic(args.file)
    scribe = scribe_slot(data)
    flags = as_list(scribe, "stale_flags", "scribe.stale_flags")
    kept = [flag for flag in flags if entry_id(flag) != args.id]
    removed = len(flags) - len(kept)
    if removed:
        scribe["stale_flags"] = kept
        save_topic(args.file, data, body, newline)
    print(removed)
    return 0


def cmd_claims_add(args):
    incoming = parse_json_arg(args.json, list, "array")
    if os.path.exists(args.claims):
        claims, newline = load_yaml_file(args.claims)
    else:
        claims, newline = {}, "\n"
    items = as_list(claims, "claims", "%s: claims" % args.claims)
    retired = as_list(claims, "_retired_ids", "%s: _retired_ids" % args.claims)
    number = _next_claim_number(args.topic, items, retired + csv_values(args.reserved))
    added = []
    matched = []
    for entry in incoming:
        if not isinstance(entry, dict):
            die("every --json element must be a JSON object")
        if "id" in entry:
            die("incoming claims must not carry an id")
        if entry.get("type") is None or entry.get("claim") is None:
            die("every claim needs a type and a claim")
        existing = _matching_claim(items, args.topic, entry)
        if existing is not None:
            matched.append(existing.get("id"))
            continue
        built = {
            "id": "%s-%d" % (args.topic, number),
            "type": entry["type"],
            "topic": args.topic,
            "claim": entry["claim"],
        }
        for key in ["source", "provenance"]:
            if key in entry:
                built[key] = entry[key]
        for key, value in entry.items():
            if key not in built and key != "topic":
                built[key] = value
        items.append(built)
        added.append(built["id"])
        number += 1
    claims["claims"] = items
    save_yaml_file(args.claims, claims, newline)
    print(as_json({"added": added, "matched": matched}))
    return 0


def _next_claim_number(topic, items, reserved):
    pattern = re.compile(r"^%s-(\d+)$" % re.escape(topic))
    highest = 0
    for value in [entry_id(claim) for claim in items] + list(reserved):
        match = pattern.match(value) if isinstance(value, str) else None
        if match:
            highest = max(highest, int(match.group(1)))
    return highest + 1


def _matching_claim(items, topic, entry):
    head = str(entry["claim"])[:50]
    for claim in items:
        if not isinstance(claim, dict):
            continue
        if claim.get("type") != entry["type"] or claim.get("topic") != topic:
            continue
        if str(claim.get("claim", ""))[:50] == head:
            return claim
    return None


def cmd_claims_set_meta(args):
    claims, newline = load_yaml_file(args.claims)
    meta = claims.get("_meta")
    if meta is None:
        meta = {}
        claims["_meta"] = meta
    elif not isinstance(meta, dict):
        die("%s: _meta is not a mapping" % args.claims)
    key = "%s_extracted_at" % args.topic
    meta[key] = args.sha
    save_yaml_file(args.claims, claims, newline)
    print(key)
    return 0


def build_parser():
    parser = argparse.ArgumentParser(
        prog="scribe-lib.py",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        description="Deterministic helpers for the codebase-scribe skills. Each "
                    "subcommand's --help is the canonical definition of what it "
                    "computes.",
        epilog=SHARED_RULES,
    )
    sub = parser.add_subparsers(dest="command", metavar="SUBCOMMAND")
    sub.required = True

    def add(name, help_text, description):
        return sub.add_parser(
            name,
            help=help_text,
            description=description,
            formatter_class=argparse.RawDescriptionHelpFormatter,
            epilog=SHARED_RULES,
        )

    p = add("sections", "list fence-aware headings as level/slug/text", SECTIONS_HELP)
    p.add_argument("file", metavar="FILE")
    p.add_argument("--level", choices=["2", "3", "all"], default="2")
    p.set_defaults(func=cmd_sections)

    p = add("slug", "print the GitHub-flavored slug of TEXT", SLUG_HELP)
    p.add_argument("text", metavar="TEXT")
    p.set_defaults(func=cmd_slug)

    p = add("tier", "print stub or mature for a topic file", TIER_HELP)
    p.add_argument("file", metavar="FILE")
    p.set_defaults(func=cmd_tier)

    p = add("validate-sha", "check a scan SHA against the repo in CWD", VALIDATE_SHA_HELP)
    p.add_argument("sha", metavar="SHA")
    p.set_defaults(func=cmd_validate_sha)

    p = add("human-input", "score SME-touched sections 0-100", HUMAN_INPUT_HELP)
    p.add_argument("file", metavar="FILE")
    p.add_argument("--slugs", required=True, metavar="CSV")
    p.set_defaults(func=cmd_human_input)

    p = add("completeness", "score watched subdirectory coverage 0-100", COMPLETENESS_HELP)
    p.add_argument("file", metavar="FILE")
    p.add_argument("watch_path", metavar="WATCH_PATH", nargs="+")
    p.set_defaults(func=cmd_completeness)

    p = add("classify", "classify the change between a snapshot and FILE", CLASSIFY_HELP)
    p.add_argument("file", metavar="FILE")
    p.add_argument("--snapshot", required=True, metavar="S")
    p.add_argument("--snapshot-claims", required=True, metavar="SC")
    p.add_argument("--current-claims", required=True, metavar="CC")
    p.add_argument("--snapshot-headings", required=True, metavar="SH")
    p.add_argument("--threshold", required=True, type=int, metavar="N")
    p.set_defaults(func=cmd_classify)

    p = add("hub-state", "classify an AGENTS.md hub's marker state", HUB_STATE_HELP)
    p.add_argument("file", metavar="FILE")
    p.set_defaults(func=cmd_hub_state)

    p = add("hub-links", "list the topic-link destinations in a hub", HUB_LINKS_HELP)
    p.add_argument("file", metavar="FILE")
    p.add_argument("--docs-dir", required=True, metavar="D")
    p.set_defaults(func=cmd_hub_links)

    p = add("repair-watch-paths", "widen watch paths to existing directories", REPAIR_WATCH_PATHS_HELP)
    p.add_argument("path", metavar="PATH", nargs="*")
    p.set_defaults(func=cmd_repair_watch_paths)

    def group(name, help_text, description):
        parent = sub.add_parser(
            name,
            help=help_text,
            description=description,
            formatter_class=argparse.RawDescriptionHelpFormatter,
            epilog=FM_RULES,
        )
        verbs = parent.add_subparsers(dest=name + "_verb", metavar="VERB")
        verbs.required = True

        def add_verb(verb, verb_help, verb_description):
            return verbs.add_parser(
                verb,
                help=verb_help,
                description=verb_description,
                formatter_class=argparse.RawDescriptionHelpFormatter,
                epilog=FM_RULES,
            )

        return add_verb

    fm = group("fm", "read and write a topic file's scribe: frontmatter", FM_HELP)

    p = fm("read", "print the scribe: mapping as JSON", FM_READ_HELP)
    p.add_argument("file", metavar="FILE")
    p.set_defaults(func=cmd_fm_read)

    p = fm("update", "merge keys into the scribe: mapping", FM_UPDATE_HELP)
    p.add_argument("file", metavar="FILE")
    p.add_argument("--json", required=True, metavar="OBJECT")
    p.add_argument("--unset", metavar="CSV")
    p.set_defaults(func=cmd_fm_update)

    p = fm("stamp", "set scan and freshness", FM_STAMP_HELP)
    p.add_argument("file", metavar="FILE")
    p.add_argument("--scan", required=True, metavar="SHA")
    p.add_argument("--freshness", required=True, type=int, metavar="N")
    p.set_defaults(func=cmd_fm_stamp)

    p = fm("credit-section", "credit a section to the SME and rescore", FM_CREDIT_SECTION_HELP)
    p.add_argument("file", metavar="FILE")
    p.add_argument("slug", metavar="SLUG")
    p.set_defaults(func=cmd_fm_credit_section)

    p = fm("question-pass", "increment question_passes", FM_QUESTION_PASS_HELP)
    p.add_argument("file", metavar="FILE")
    p.set_defaults(func=cmd_fm_question_pass)

    p = fm("settle", "apply the settling rule to question_passes", FM_SETTLE_HELP)
    p.add_argument("file", metavar="FILE")
    p.set_defaults(func=cmd_fm_settle)

    p = fm("retire-decision", "tombstone a decision and retire its claim", FM_RETIRE_DECISION_HELP)
    p.add_argument("file", metavar="FILE")
    p.add_argument("id", metavar="ID")
    p.add_argument("--claims", required=True, metavar="PATH")
    p.add_argument("--resolved-at", metavar="SHA")
    p.set_defaults(func=cmd_fm_retire_decision)

    p = fm("refresh-decision", "re-date a decision and its claim", FM_REFRESH_DECISION_HELP)
    p.add_argument("file", metavar="FILE")
    p.add_argument("id", metavar="ID")
    p.add_argument("--claims", required=True, metavar="PATH")
    p.add_argument("--recorded", required=True, metavar="DATE")
    p.add_argument("--context", metavar="TEXT")
    p.add_argument("--resolved-at", metavar="SHA")
    p.set_defaults(func=cmd_fm_refresh_decision)

    p = fm("remove-stale-flag", "drop stale_flags entries by id", FM_REMOVE_STALE_FLAG_HELP)
    p.add_argument("file", metavar="FILE")
    p.add_argument("id", metavar="ID")
    p.set_defaults(func=cmd_fm_remove_stale_flag)

    claims = group("claims", "read and write a .claims.yml file", CLAIMS_HELP)

    p = claims("add", "append claims, reusing ids where they match", CLAIMS_ADD_HELP)
    p.add_argument("--claims", required=True, metavar="PATH")
    p.add_argument("--topic", required=True, metavar="T")
    p.add_argument("--json", required=True, metavar="ARRAY")
    p.add_argument("--reserved", metavar="CSV")
    p.set_defaults(func=cmd_claims_add)

    p = claims("set-meta", "record a topic's extraction SHA", CLAIMS_SET_META_HELP)
    p.add_argument("--claims", required=True, metavar="PATH")
    p.add_argument("--topic", required=True, metavar="T")
    p.add_argument("--sha", required=True, metavar="SHA")
    p.set_defaults(func=cmd_claims_set_meta)

    return parser


def main():
    # Callers capture stdout from bash on Windows, where the default text layer
    # would emit CRLF (poisoning "$(...)" captures) and encode with the console
    # codepage (raising UnicodeEncodeError on a non-ASCII heading).
    sys.stdout.reconfigure(encoding="utf-8", newline="\n")
    args = build_parser().parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
