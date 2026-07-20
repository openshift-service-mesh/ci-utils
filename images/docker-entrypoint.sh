#!/bin/bash
# Sync ai-helpers marketplace on every container start.
# Discovers available plugins via the GitHub API and enables them in settings,
# so new skills are picked up without rebuilding the image.

SETTINGS="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"

python3 - "$SETTINGS" <<'PYEOF'
import json, subprocess, sys

settings_file = sys.argv[1]

try:
    result = subprocess.run(
        ['gh', 'api', 'repos/openshift-eng/ai-helpers/contents/plugins',
         '--jq', '.[].name'],
        capture_output=True, text=True, timeout=30
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.strip() or "gh api failed")

    plugins = [p.strip() for p in result.stdout.splitlines() if p.strip()]

    with open(settings_file) as f:
        settings = json.load(f)

    enabled = settings.setdefault('enabledPlugins', {})
    for name in plugins:
        enabled[f'{name}@ai-helpers'] = True

    with open(settings_file, 'w') as f:
        json.dump(settings, f, indent=2)

    print(f"ai-helpers: {len(plugins)} plugins enabled", flush=True)
except Exception as e:
    print(f"ai-helpers sync skipped ({e})", flush=True)
PYEOF

exec claude "$@"
