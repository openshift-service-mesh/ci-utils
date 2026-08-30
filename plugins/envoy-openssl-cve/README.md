# envoy-openssl-cve

Manages CVE issues for the Envoy component of OSSM. CVEs are tracked in the OSSM Jira project with `component = Envoy`.

## Commands

| Command | Description |
|---------|-------------|
| `/envoy-openssl-cve:triage` | Find new CVE issues, classify, select fix pathway, create PRs, transition Jira |
| `/envoy-openssl-cve:review` | Review open CVE PRs, check CI, approve/merge, update Jira to Release Pending |

## Usage

```
/envoy-openssl-cve:triage
/envoy-openssl-cve:triage OSSM-12345
/envoy-openssl-cve:triage CVE-2025-XXXXX

/envoy-openssl-cve:review
/envoy-openssl-cve:review CVE-2025-XXXXX
/envoy-openssl-cve:review 42
```

Providing a CVE ID, Jira issue key, or PR number starts the skill at that specific item rather than running the full discovery queries.

## Repo regimes

The correct repository depends on the Envoy release branch being fixed:

- **`< 1.38`** → `envoyproxy/envoy-openssl` — fork with OpenSSL via `bssl-compat`; auto-syncs from upstream every 6 hours
- **`>= 1.38`** → `envoyproxy/envoy` — upstream repo; OpenSSL selected at build time
- **Proxy** → `openshift-service-mesh/proxy` — needed only when the CVE is in proxy-specific vendored deps (`ossm/vendor/<dep>/`)

## Branch / OSSM version mapping

| Envoy branch | OSSM version | Proxy branch | Regime |
|---|---|---|---|
| `release/v1.32` | 3.0 | `release-1.24` | envoy-openssl |
| `release/v1.34` | 3.1 | `release-1.26` | envoy-openssl |
| `release/v1.35` | 3.2 | `release-1.27` | envoy-openssl |
| `release/v1.36` | 3.3 | `release-1.28` | envoy-openssl |
| `release/v1.38` | 3.4 | `release-1.30` | envoy (upstream) |

## Installation

```
/plugin marketplace add openshift-service-mesh/ci-utils
/plugin install envoy-openssl-cve@ci-utils
/reload-plugins
```
