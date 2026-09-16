# DevLake Test Registry Results Sender

Pushes OSSM downstream test results to the **DevLake Test Registry (Konflux)** as a
post-build Jenkins step.

## Prerequisites

- `jq`, `python3`, `curl` available in the Jenkins agent
- `ossm-env-snapshot.json` and a JUnit XML archived in the workspace
- A Jenkins credential of type **Secret text** containing the DevLake API token

## How It Works

The script reads two artifacts already present in the Jenkins workspace:

1. **`ossm-env-snapshot.json`** — extracts OSSM version, OCP version, architecture,
   platform, network type, flavor, FIPS and disconnected flags, and operator image SHA
2. **JUnit XML** — uploaded as the test report

From these it derives a stable `job_name` for trending and a `job_id` that embeds the
operator SHA for per-build filtering.

## Adding a Post Step to a Jenkins Pipeline

### 1. Create the Jenkins credential

In **Manage Jenkins → Credentials → System → Global credentials → Add**:

| Field | Value |
|-------|-------|
| Kind | Secret text |
| ID | `devlake-api-key` |
| Secret | DevLake Bearer token |

### 2. Add a `post { always { } }` block to your Jenkinsfile

Set `COMPONENT` to a name that identifies the test suite (examples:
`sail-operator-e2e`, `kiali-playwright`, `kiali-cypress`, `kiali-operator`,
`istio-integration`). Set `DEVLAKE_SCOPE_ID` to the corresponding component scope
(`sail-operator`, `kiali`, `istio`).

```groovy
environment {
    DEVLAKE_BASE = 'https://konflux-devlake-ui-konflux-devlake.apps.rosa.kflux-c-prd-i01.7hyu.p3.openshiftapps.com'
}

post {
    always {
        script {
            if (fileExists('ossm-env-snapshot.json') && fileExists('report.xml')) {
                withCredentials([string(credentialsId: 'devlake-api-key', variable: 'DEVLAKE_API_KEY')]) {
                    env.COMPONENT         = 'your-component-name'   // e.g. kiali-playwright
                    env.DEVLAKE_SCOPE_ID  = 'your-scope'            // e.g. kiali
                    env.BUILD_RESULT      = currentBuild.currentResult
                    env.BUILD_START_MS    = currentBuild.startTimeInMillis.toString()
                    env.BUILD_DURATION_MS = currentBuild.duration.toString()
                    sh '''
                        curl -fsSL https://raw.githubusercontent.com/openshift-service-mesh/ci-utils/main/devlake/send_testregistry_results.sh \
                          | bash
                    '''
                }
            } else {
                echo 'devlake-push: artifacts not found, skipping'
            }
        }
    }
}
```

> **No internet access on the agent?** Copy `devlake/send_testregistry_results.sh`
> into the test repository and call it directly:
> ```groovy
> sh 'bash devlake/send_testregistry_results.sh'
> ```

## Environment Variables

### Required

| Variable | Description |
|----------|-------------|
| `DEVLAKE_BASE` | DevLake base URL |
| `DEVLAKE_API_KEY` | Bearer token (via `withCredentials`) |
| `COMPONENT` | Test suite identifier used as the `job_name` prefix |

### From Jenkins (pass from `currentBuild`)

| Variable | Source |
|----------|--------|
| `BUILD_NUMBER` | automatic |
| `BUILD_URL` | automatic — used as `viewUrl` in DevLake |
| `BUILD_RESULT` | `currentBuild.currentResult` |
| `BUILD_START_MS` | `currentBuild.startTimeInMillis.toString()` |
| `BUILD_DURATION_MS` | `currentBuild.duration.toString()` |

### Optional overrides

| Variable | Default | Description |
|----------|---------|-------------|
| `DEVLAKE_CONNECTION` | `ossm` | We will use this for all of our Test Registry connection name to be able to later identify and manage connections consistently |
| `DEVLAKE_ORG` | `OSSM` | Organization in our case |
| `DEVLAKE_REPO` | `downstream-ossm` | Repository to which the tests belong |
| `DEVLAKE_SCOPE_ID` | _(not sent)_ | Scope — set per test suite |
| `SNAPSHOT_FILE` | `ossm-env-snapshot.json` | Path to env snapshot |
| `JUNIT_FILE` | `report.xml` | Path to JUnit XML |

## Local Testing

```bash
export DEVLAKE_BASE='https://konflux-devlake-ui-...'
export DEVLAKE_API_KEY='...'
export COMPONENT='kiali-playwright'
export DEVLAKE_SCOPE_ID='kiali'
export BUILD_NUMBER='999'
export BUILD_RESULT='SUCCESS'
export BUILD_START_MS='1726390000000'
export BUILD_DURATION_MS='3720000'

./devlake/send_testregistry_results.sh --dry-run --verbose
```

## Verification

```sql
SELECT job_id, job_name, result, started_at, finished_at
FROM   ci_test_jobs
WHERE  job_name LIKE 'downstream-%'
ORDER  BY finished_at DESC
LIMIT  10;
```

Filter by a specific operator build (SHA):
```sql
SELECT * FROM ci_test_jobs WHERE job_id LIKE '%-deb6dd6fae24-%';
```
