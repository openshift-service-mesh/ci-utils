---
name: Prow CI Execution Metrics
description: Collect and present Prow CI execution data for OSSM repositories, with summary statistics and TSV export for Excel
command: /ossm-ci:prow-metrics
---

# Prow CI Execution Data

You are an AI assistant specialized in gathering real execution data from Prow CI for OpenShift Service Mesh repositories. Your goal is to collect and present **completed test executions plus all currently pending jobs** with key metrics and timing data.

**Default**: Collect the last 100 completed executions + all pending jobs.
**Configurable**: Accept a specific count or number of days from the user.

## OSSM Repositories

- `openshift-service-mesh/istio`
- `openshift-service-mesh/proxy`
- `openshift-service-mesh/sail-operator`
- `openshift-service-mesh/ztunnel`

## Skill Execution

### Step 1 — Ask user for scope (or read from headless input)

```
How much Prow CI data should we collect?
- Default (Recommended): Last 100 completed + all pending
- Custom count: e.g. 50, 200, 500
- Time-based: e.g. last 3 days, 7 days
```

### Step 2 — Fetch and filter Prow data

Run this inline Python script to fetch and process the data. It fetches the Prow API, filters for OSSM repos, and outputs a JSON summary + TSV file:

```bash
python3 - <<'EOF'
import urllib.request, json, ssl, csv, sys
from datetime import datetime, timezone, timedelta
from statistics import median

REPOS = [
    'openshift-service-mesh/istio',
    'openshift-service-mesh/proxy',
    'openshift-service-mesh/sail-operator',
    'openshift-service-mesh/ztunnel',
]
COUNT = 100      # Replace with user-specified count
DAYS = None      # Replace with user-specified days (or None)

def fetch_jobs():
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    url = "https://prow.ci.openshift.org/prowjobs.js"
    req = urllib.request.Request(url, headers={"Accept-Encoding": "identity"})
    with urllib.request.urlopen(req, context=ctx, timeout=120) as r:
        data = json.loads(r.read().decode('utf-8'))
    return data.get('items', data) if isinstance(data, dict) else data

def repo_of(job):
    refs = job.get('spec', {}).get('refs') or {}
    org = refs.get('org', '')
    repo = refs.get('repo', '')
    if org and repo:
        return f"{org}/{repo}"
    extra = job.get('spec', {}).get('extra_refs', [])
    if extra:
        return f"{extra[0].get('org','')}/{extra[0].get('repo','')}"
    return ''

def suite_type(name):
    n = name.lower()
    if 'gencheck' in n or 'generate' in n: return 'gencheck'
    if 'lint' in n: return 'lint'
    if 'unit' in n: return 'unit-tests'
    if 'e2e' in n or 'integration' in n or 'integ' in n: return 'e2e'
    if 'sync' in n: return 'sync-upstream'
    if 'interop' in n or 'lpinterop' in n: return 'lpinterop'
    if 'build' in n or 'images' in n: return 'build'
    return 'other'

def duration_minutes(start, end):
    if not start or not end: return None
    fmt = '%Y-%m-%dT%H:%M:%SZ'
    try:
        s = datetime.strptime(start, fmt).replace(tzinfo=timezone.utc)
        e = datetime.strptime(end, fmt).replace(tzinfo=timezone.utc)
        return round((e - s).total_seconds() / 60, 1)
    except: return None

def spyglass_url(job):
    build_id = job.get('status', {}).get('build_id', '')
    job_name = job.get('spec', {}).get('job', '')
    if build_id and job_name:
        return f"https://prow.ci.openshift.org/view/gs/test-platform-results/logs/{job_name}/{build_id}"
    return ''

print("Fetching Prow data...", file=sys.stderr)
all_jobs = fetch_jobs()

cutoff = None
if DAYS:
    cutoff = datetime.now(timezone.utc) - timedelta(days=DAYS)

ossm_jobs = [j for j in all_jobs if repo_of(j) in REPOS]

completed = [j for j in ossm_jobs if j.get('status', {}).get('state') not in ('pending', 'triggered')]
pending   = [j for j in ossm_jobs if j.get('status', {}).get('state') in ('pending', 'triggered')]

if cutoff:
    def started_after(j):
        t = j.get('status', {}).get('startTime', '')
        if not t: return False
        try:
            return datetime.strptime(t, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc) >= cutoff
        except: return False
    completed = [j for j in completed if started_after(j)]
else:
    completed = completed[:COUNT]

rows = []
for j in completed + pending:
    spec   = j.get('spec', {})
    status = j.get('status', {})
    start  = status.get('startTime', '')
    end    = status.get('completionTime', '')
    rows.append({
        'Job_Name':        spec.get('job', ''),
        'Repository':      repo_of(j).split('/')[-1],
        'Branch':          (spec.get('refs') or {}).get('base_ref', ''),
        'Job_Type':        spec.get('type', ''),
        'Start_Time':      start,
        'Completion_Time': end,
        'Duration_Minutes': duration_minutes(start, end) or '',
        'Status':          status.get('state', ''),
        'Build_ID':        status.get('build_id', ''),
        'Cluster':         status.get('cluster', ''),
        'Test_Suite_Type': suite_type(spec.get('job', '')),
        'Spyglass_URL':    spyglass_url(j),
    })

from datetime import datetime as dt
ts = dt.now().strftime('%Y%m%d_%H%M%S')
label = f"days{DAYS}" if DAYS else f"{COUNT}completed"
tsv_file = f"ossm_prow_{label}_plus_pending_{ts}.tsv"
with open(tsv_file, 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=rows[0].keys(), delimiter='\t')
    w.writeheader()
    w.writerows(rows)

print(json.dumps({'rows': rows, 'tsv_file': tsv_file}))
EOF
```

### Step 3 — Compute and present statistics from the JSON output

Parse the JSON output and calculate:
- Total counts by status (success/failure/pending/aborted)
- Breakdown by repository
- Median duration per `Test_Suite_Type` (exclude rows with empty Duration_Minutes)
- Build cluster distribution
- Job start hour distribution (UTC)

## Output Format

```
PROW CI EXECUTION DATA - LAST [N] COMPLETED + PENDING JOBS
===========================================================
Data collected: [timestamp]
Time range: [start date] to [end date]

## SUMMARY STATISTICS

Total executions: [N]
Success rate: [X]% ([N] successful)
Failure rate: [X]% ([N] failed)
Pending jobs: [N] running

Repository breakdown:
- istio: [N] jobs ([X]%)
- sail-operator: [N] jobs ([X]%)
- proxy: [N] jobs ([X]%)
- ztunnel: [N] jobs ([X]%)

## EXECUTION TIME BY JOB TYPE

| Job Type | Median Duration | Count | Range |
|----------|----------------|--------|--------|
| e2e | [X] min | [N] | [X]-[Y] min |
| lint | [X] min | [N] | [X]-[Y] min |
| unit-tests | [X] min | [N] | [X]-[Y] min |
| sync-upstream | [X] min | [N] | [X]-[Y] min |

## INFRASTRUCTURE USAGE

Build clusters:
- build05: [N] jobs
- build06: [N] jobs

Job distribution by time (UTC):
- 00:00-06:00: [N] jobs
- 06:00-12:00: [N] jobs
- 12:00-18:00: [N] jobs
- 18:00-24:00: [N] jobs

## CURRENT ISSUES

Failed jobs:
| Job Name | Repository | Duration | Status |

Pending jobs:
| Job Name | Repository | Running Time | Status |

## EXCEL DATA EXPORT

TSV file saved to: [tsv_file]
Columns: Job_Name, Repository, Branch, Job_Type, Start_Time, Completion_Time, Duration_Minutes, Status, Build_ID, Cluster, Test_Suite_Type, Spyglass_URL
```

## Rules

- **No analysis or recommendations** — present data only.
- **Never fabricate numbers** — all figures come from the API response.
- **Always save the TSV file** for Excel import.
- If the API fetch fails, report the error and do not guess at numbers.
- Replace `COUNT` and `DAYS` in the Python script with the user's actual values before running.
- When using count-based collection, set `DAYS = None` and `COUNT = <user_value>`.
- When using time-based collection, set `DAYS = <user_value>` and `COUNT` is ignored.
