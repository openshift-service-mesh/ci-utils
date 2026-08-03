#!/bin/bash
# Four-way version sync check for the codebase-scribe plugin: both plugin.json
# manifests and both marketplace.json entries for "codebase-scribe" must declare
# the identical version string. Exits 0 only when all four are present, parse,
# and agree; otherwise exits non-zero after printing the cause.
#
# Layout assumption: the monorepo (plugin.json under plugins/codebase-scribe/,
# marketplace.json files three directories up). Against a standalone plugin
# install the two marketplace checks report MISSING, which is expected here.
set -u

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../../.." && pwd)"

plugin_json="$repo_root/plugins/codebase-scribe/.claude-plugin/plugin.json"
cursor_plugin_json="$repo_root/plugins/codebase-scribe/.cursor-plugin/plugin.json"
claude_marketplace="$repo_root/.claude-plugin/marketplace.json"
cursor_marketplace="$repo_root/.cursor-plugin/marketplace.json"

# Anchored at BOTH ends: a leading anchor alone accepts "1.3.0garbage".
# The suffixes spell out dot-separated identifiers rather than putting "." in a
# character class, which would accept "1.3.0-." and "1.3.0+.".
version_shape='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$'

python_bin=""
for cand in python3 python py; do
  command -v "$cand" >/dev/null 2>&1 || continue
  if [ "$cand" = "py" ]; then
    if "$cand" -3 -c 'import json' >/dev/null 2>&1; then python_bin="$cand -3"; break; fi
  else
    if "$cand" -c 'import json' >/dev/null 2>&1; then python_bin="$cand"; break; fi
  fi
done
if [ -z "$python_bin" ]; then
  echo "FAIL: no working Python interpreter found (tried python3, python, py -3)"
  echo "      check-sync.sh parses the manifests with Python's json module and cannot run without one."
  exit 1
fi

# $1 = "plugin" | "marketplace", $2 = path.
read_version='
import json, sys

mode, path = sys.argv[1], sys.argv[2]

def fail(msg):
    sys.stderr.write(msg + "\n")
    raise SystemExit(1)

# json.load silently keeps the LAST of a set of duplicate keys while another
# consumer may take the first or reject the file, so a duplicate is ambiguous.
def reject_duplicate_keys(pairs):
    seen = set()
    for key, _ in pairs:
        if key in seen:
            fail("duplicate \"%s\" key in a JSON object - the manifest is ambiguous" % key)
        seen.add(key)
    return dict(pairs)

try:
    with open(path, encoding="utf-8") as handle:
        data = json.load(handle, object_pairs_hook=reject_duplicate_keys)
except ValueError as exc:
    fail("not valid JSON (%s)" % exc)
except OSError as exc:
    fail("could not be read (%s)" % exc)

if not isinstance(data, dict):
    fail("top-level JSON value is %s, expected an object" % type(data).__name__)

if mode == "plugin":
    entry = data
else:
    plugins = data.get("plugins")
    if not isinstance(plugins, list):
        fail("no top-level \"plugins\" array")
    matches = [p for p in plugins if isinstance(p, dict) and p.get("name") == "codebase-scribe"]
    if not matches:
        fail("no plugins[] entry named \"codebase-scribe\"")
    if len(matches) > 1:
        fail("%d plugins[] entries named \"codebase-scribe\" - the manifest is ambiguous" % len(matches))
    entry = matches[0]

version = entry.get("version")
if not isinstance(version, str):
    fail("\"version\" is missing or not a string (got %r)" % (version,))
print(version)
'

version_from_plugin_json() {
  $python_bin -c "$read_version" plugin "$1"
}

version_from_marketplace() {
  $python_bin -c "$read_version" marketplace "$1"
}

status=0
incomplete=0
# Initialized, not merely declared: under `set -u` a bare `declare -a v` leaves
# v unbound, so "${#versions[@]}" aborts on the all-four-unreadable path.
declare -a labels=() versions=()

check() {
  local label="$1" file="$2" extractor="$3" value rc
  if [ ! -f "$file" ]; then
    echo "MISSING: $label ($file)"
    status=1
    incomplete=1
    return
  fi
  # stderr is folded into the value so the parser's own reason can be reported.
  value="$("$extractor" "$file" 2>&1)"
  rc=$?
  if [ $rc -ne 0 ] || [ -z "$value" ] || ! [[ "$value" =~ $version_shape ]]; then
    echo "UNREADABLE: could not extract a version from $label ($file): ${value:-no output}"
    status=1
    incomplete=1
    return
  fi
  labels+=("$label")
  versions+=("$value")
  echo "$label: $value"
}

check "plugin.json (Claude Code)" "$plugin_json" version_from_plugin_json
check "plugin.json (Cursor)" "$cursor_plugin_json" version_from_plugin_json
check "marketplace.json (Claude Code)" "$claude_marketplace" version_from_marketplace
check "marketplace.json (Cursor)" "$cursor_marketplace" version_from_marketplace

# Compare whatever was extracted: a missing manifest must not suppress learning
# whether the rest agree.
mismatch=0
if [ "${#versions[@]}" -gt 0 ]; then
  first="${versions[0]}"
  for i in "${!versions[@]}"; do
    if [ "${versions[$i]}" != "$first" ]; then
      echo "MISMATCH: ${labels[$i]}=${versions[$i]} != ${labels[0]}=$first"
      mismatch=1
      status=1
    fi
  done
fi

if [ "$status" -eq 0 ]; then
  echo "OK: all four manifests agree on version $first"
elif [ "$incomplete" -eq 1 ] && [ "$mismatch" -eq 1 ]; then
  echo "FAIL: one or more manifests could not be read, and the ones that were read do not agree"
elif [ "$incomplete" -eq 1 ]; then
  echo "FAIL: one or more manifests could not be read (see MISSING/UNREADABLE above)"
else
  echo "FAIL: version mismatch across codebase-scribe manifests"
fi

exit "$status"
