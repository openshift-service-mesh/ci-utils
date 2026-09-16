#!/bin/bash

# For more information please check the README.md file in the same directory.

set -o nounset
set -o errexit
set -o pipefail

# --- Global Variables ---
VERBOSE=false
DRY_RUN=false

# Snapshot-derived values (populated by read_snapshot)
SNAP_OSSM_VERSION=""
SNAP_OPERATOR_SHA=""
SNAP_OCP_VERSION=""
SNAP_ARCH=""
SNAP_PLATFORM=""
SNAP_NETWORK=""
SNAP_FLAVOR=""
SNAP_FIPS="false"
SNAP_DISCONNECTED="false"
SNAP_ISTIO_VERSION=""

# --- Helper Functions ---

show_help() {
    cat << EOF
DevLake Test Registry Results Sender

Reads ossm-env-snapshot.json and a JUnit XML from the Jenkins workspace and pushes
the test run to the DevLake Test Registry API.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help          Show this help message and exit
    -v, --verbose       Enable verbose output (shows all snapshot fields)
    --dry-run           Show what would be sent without actually sending

REQUIRED ENVIRONMENT VARIABLES:
    DEVLAKE_BASE        DevLake base URL (e.g. "https://konflux-devlake-ui-...")
    DEVLAKE_API_KEY     Bearer token (inject via Jenkins withCredentials)
    COMPONENT           Test component name, used as the job_name prefix segment.
                        Examples: sail-operator-e2e, kiali-playwright,
                                  kiali-cypress, kiali-operator, istio-integration

JENKINS-PROVIDED VARIABLES (set automatically or pass from currentBuild):
    BUILD_NUMBER        Jenkins build number                        (automatic)
    BUILD_URL           Jenkins build URL                           (automatic)
    BUILD_RESULT        currentBuild.currentResult                  (SUCCESS|FAILURE|UNSTABLE|ABORTED)
    BUILD_START_MS      currentBuild.startTimeInMillis.toString()   (epoch ms)
    BUILD_DURATION_MS   currentBuild.duration.toString()            (ms)

OPTIONAL ENVIRONMENT VARIABLES:
    DEVLAKE_CONNECTION  Connection name       (default: "ossm")
    DEVLAKE_ORG         Organization          (default: "OSSM")
    DEVLAKE_REPO        Repository            (default: "downstream-ossm")
    DEVLAKE_SCOPE_ID    Scope ID              (default: not sent — set per component,
                                               e.g. sail-operator, kiali, istio)
    SNAPSHOT_FILE       Env snapshot path     (default: "ossm-env-snapshot.json")
    JUNIT_FILE          JUnit XML path        (default: "report.xml")

EXAMPLES:
    # sail-operator E2E
    COMPONENT=sail-operator-e2e DEVLAKE_SCOPE_ID=sail-operator \\
      DEVLAKE_BASE='https://...' DEVLAKE_API_KEY='...' $0 --dry-run --verbose

    # Kiali playwright tests
    COMPONENT=kiali-playwright DEVLAKE_SCOPE_ID=kiali \\
      DEVLAKE_BASE='https://...' DEVLAKE_API_KEY='...' $0 --dry-run --verbose

    # Jenkins post block (see README for full pipeline snippet)
    # curl -fsSL https://raw.githubusercontent.com/openshift-service-mesh/ci-utils/main/devlake/send_testregistry_results.sh | bash

EOF
}

log_verbose() {
    if [[ "${VERBOSE}" == "true" ]]; then
        echo "[VERBOSE] $*" >&2
    fi
}

log_info() {
    echo "[INFO] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

validate_environment() {
    local missing_vars=()

    if [[ -z "${DEVLAKE_BASE:-}" ]]; then
        missing_vars+=("DEVLAKE_BASE")
    fi

    if [[ -z "${DEVLAKE_API_KEY:-}" ]]; then
        missing_vars+=("DEVLAKE_API_KEY")
    fi

    if [[ -z "${COMPONENT:-}" ]]; then
        missing_vars+=("COMPONENT (e.g. sail-operator-e2e, kiali-playwright, istio-integration)")
    fi

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            log_error "  - $var"
        done
        log_error ""
        log_error "Use --help for more information."
        exit 1
    fi
}

set_defaults() {
    readonly DEVLAKE_CONNECTION=${DEVLAKE_CONNECTION:-"ossm"}
    readonly DEVLAKE_ORG=${DEVLAKE_ORG:-"OSSM"}
    readonly DEVLAKE_REPO=${DEVLAKE_REPO:-"downstream-ossm"}
    readonly DEVLAKE_SCOPE_ID=${DEVLAKE_SCOPE_ID:-""}
    readonly SNAPSHOT_FILE=${SNAPSHOT_FILE:-"ossm-env-snapshot.json"}
    readonly JUNIT_FILE=${JUNIT_FILE:-"report.xml"}

    log_verbose "Configuration:"
    log_verbose "  DevLake URL:    ${DEVLAKE_BASE}"
    log_verbose "  Connection:     ${DEVLAKE_CONNECTION}"
    log_verbose "  Org/Repo:       ${DEVLAKE_ORG}/${DEVLAKE_REPO}"
    log_verbose "  Component:      ${COMPONENT}"
    log_verbose "  Scope ID:       ${DEVLAKE_SCOPE_ID:-<not set>}"
    log_verbose "  Snapshot file:  ${SNAPSHOT_FILE}"
    log_verbose "  JUnit file:     ${JUNIT_FILE}"
    log_verbose "  Build number:   ${BUILD_NUMBER:-<not set>}"
    log_verbose "  Build result:   ${BUILD_RESULT:-UNKNOWN}"
    log_verbose "  Build URL:      ${BUILD_URL:-<not set>}"
}

# --- Core Functions ---

verify_artifacts() {
    if [[ ! -f "${SNAPSHOT_FILE}" ]]; then
        log_error "Env snapshot not found: ${SNAPSHOT_FILE}"
        log_error "Ensure the pipeline archives ossm-env-snapshot.json before this step runs."
        exit 1
    fi

    if [[ ! -f "${JUNIT_FILE}" ]]; then
        log_error "JUnit report not found: ${JUNIT_FILE}"
        log_error "Ensure the pipeline archives report.xml before this step runs."
        exit 1
    fi

    log_info "Artifacts found: ${SNAPSHOT_FILE}, ${JUNIT_FILE}"
}

# Extract all relevant fields from the env snapshot in one pass.
# Populates the SNAP_* global variables used by the rest of the script.
read_snapshot() {
    local snap="$1"

    SNAP_OSSM_VERSION=$(jq -r '.ossm.operator_simple_version // empty' "$snap")
    SNAP_OPERATOR_SHA=$(jq -r '.ossm.operator_image_sha // empty' "$snap" | sed 's/sha256://' | cut -c1-12)
    SNAP_OCP_VERSION=$(jq -r '.ocp.version // empty' "$snap")
    SNAP_ARCH=$(jq -r '.ocp.cluster_arch // "amd64"' "$snap" | tr '[:upper:]' '[:lower:]')
    [[ "${SNAP_ARCH}" == "x86_64" ]] && SNAP_ARCH="amd64"
    SNAP_PLATFORM=$(jq -r '.ocp.cluster_platform // empty' "$snap" | tr '[:upper:]' '[:lower:]')
    SNAP_NETWORK=$(jq -r '.ocp.cluster_network_type // empty' "$snap" | tr '[:upper:]' '[:lower:]')
    SNAP_FLAVOR=$(jq -r '.ocp.cluster_flavor // empty' "$snap" | tr '[:upper:]' '[:lower:]')
    SNAP_FIPS=$(jq -r '.ocp.fips // false' "$snap")
    SNAP_DISCONNECTED=$(jq -r '.ocp.is_disconnected // false' "$snap")
    SNAP_ISTIO_VERSION=$(jq -r '(.control_planes // {}) | to_entries[0].value.version // empty' "$snap" | sed 's/^v//')

    if [[ -z "${SNAP_OSSM_VERSION}" ]]; then
        log_error "Snapshot is missing .ossm.operator_simple_version — cannot build job name"
        exit 1
    fi
    if [[ -z "${SNAP_OCP_VERSION}" ]]; then
        log_error "Snapshot is missing .ocp.version — cannot build job name"
        exit 1
    fi

    log_verbose "Snapshot values:"
    log_verbose "  OSSM version:   ${SNAP_OSSM_VERSION}"
    log_verbose "  Operator SHA:   ${SNAP_OPERATOR_SHA:-<empty>}"
    log_verbose "  OCP version:    ${SNAP_OCP_VERSION}"
    log_verbose "  Architecture:   ${SNAP_ARCH}"
    log_verbose "  Platform:       ${SNAP_PLATFORM:-<none>}"
    log_verbose "  Network type:   ${SNAP_NETWORK:-<none>}"
    log_verbose "  Flavor:         ${SNAP_FLAVOR:-<none>}"
    log_verbose "  FIPS:           ${SNAP_FIPS}"
    log_verbose "  Disconnected:   ${SNAP_DISCONNECTED}"
    log_verbose "  Istio version:  ${SNAP_ISTIO_VERSION:-<none>}"
}

# Build a stable job_name from COMPONENT and the snapshot values set by read_snapshot().
# Pattern: downstream-{COMPONENT}-release-X.Y-ocp-X.Y[-platform][-arm|-arch][-net][-flavor][-fips][-disc][-release-X.Y]
# Compatible with OSSM Quality dashboard regex: job_name LIKE 'downstream-%'
build_job_name() {
    local ossm_seg ocp_seg flags istio_seg job_name

    ossm_seg=$(awk -F. '{printf "release-%s.%s.%s", $1, $2, $3}' <<< "${SNAP_OSSM_VERSION}")
    ocp_seg=$(awk -F. '{printf "ocp-%s.%s", $1, $2}' <<< "${SNAP_OCP_VERSION}")

    flags=""
    [[ "${SNAP_FIPS}" == "true" ]] && flags+="-fips"
    [[ "${SNAP_DISCONNECTED}" == "true" ]] && flags+="-disc"

    istio_seg=""
    [[ -n "${SNAP_ISTIO_VERSION}" ]] && istio_seg="release-${SNAP_ISTIO_VERSION}"

    job_name="downstream-${COMPONENT}-${ossm_seg}-${ocp_seg}"
    [[ -n "${SNAP_PLATFORM}" ]] && job_name+="-${SNAP_PLATFORM}"
    if [[ "${SNAP_ARCH}" == "arm64" ]]; then
        job_name+="-arm"
    elif [[ "${SNAP_ARCH}" != "amd64" ]]; then
        job_name+="-${SNAP_ARCH}"
    fi
    [[ -n "${SNAP_NETWORK}" ]] && job_name+="-${SNAP_NETWORK}"
    [[ -n "${SNAP_FLAVOR}" ]] && job_name+="-${SNAP_FLAVOR}"
    job_name+="${flags}"
    [[ -n "${istio_seg}" ]] && job_name+="-${istio_seg}"

    printf '%s' "${job_name}"
}

map_jenkins_result() {
    case "${1:-UNKNOWN}" in
        SUCCESS)            echo "SUCCESS" ;;
        FAILURE|FAILED)     echo "FAILURE" ;;
        UNSTABLE)           echo "FAILURE" ;;
        ABORTED)            echo "ABORTED" ;;
        *)                  echo "UNKNOWN" ;;
    esac
}

# Convert epoch milliseconds to ISO 8601 UTC string.
ms_to_iso8601() {
    python3 -W ignore -c "import datetime; print(datetime.datetime.utcfromtimestamp(${1}/1000).strftime('%Y-%m-%dT%H:%M:%SZ'))"
}

send_results() {
    verify_artifacts

    read_snapshot "${SNAPSHOT_FILE}"

    local job_name result job_id push_url
    job_name=$(build_job_name)
    result=$(map_jenkins_result "${BUILD_RESULT:-UNKNOWN}")
    local build_num
    if [[ "${DRY_RUN}" == "true" ]]; then
        build_num="${BUILD_NUMBER:-0}"
    else
        if [[ -z "${BUILD_NUMBER:-}" ]]; then
            log_error "BUILD_NUMBER is required for non-dry-run invocations"
            exit 1
        fi
        build_num="${BUILD_NUMBER}"
    fi
    local sha_suffix=""
    [[ -n "${SNAP_OPERATOR_SHA}" ]] && sha_suffix="-${SNAP_OPERATOR_SHA}"
    job_id="${job_name}${sha_suffix}-${build_num}"
    push_url="${DEVLAKE_BASE}/api/rest/plugins/testregistry/connections/by-name/${DEVLAKE_CONNECTION}/test_results"

    log_info "Job ID:   ${job_id}"
    log_info "Result:   ${result}"

    # Derive timing from Jenkins build metadata passed in by the Jenkinsfile.
    local timing_fields=()
    local start_ms="${BUILD_START_MS:-}"
    local duration_ms="${BUILD_DURATION_MS:-}"

    if [[ -n "${start_ms}" && "${start_ms}" != "null" ]]; then
        local started_at
        started_at=$(ms_to_iso8601 "${start_ms}")
        timing_fields+=(-F "startedAt=${started_at}")
        log_verbose "  startedAt:    ${started_at}"

        if [[ -n "${duration_ms}" && "${duration_ms}" != "null" ]]; then
            local duration_sec finished_at finish_ms
            duration_sec=$(python3 -c "print(int(${duration_ms}) // 1000)")
            finish_ms=$(( start_ms + duration_ms ))
            finished_at=$(ms_to_iso8601 "${finish_ms}")
            timing_fields+=(-F "finishedAt=${finished_at}" -F "durationSec=${duration_sec}")
            log_verbose "  finishedAt:   ${finished_at}"
            log_verbose "  durationSec:  ${duration_sec}"
        fi
    fi

    # Optional fields omitted when not set.
    local scope_fields=()
    [[ -n "${DEVLAKE_SCOPE_ID}" ]] && scope_fields+=(-F "scopeId=${DEVLAKE_SCOPE_ID}")

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "DRY RUN: Would POST to ${push_url}"
        log_info "  jobId=${job_id}"
        log_info "  jobName=${job_name}"
        log_info "  organization=${DEVLAKE_ORG}  repository=${DEVLAKE_REPO}"
        log_info "  result=${result}  jobType=jenkins  triggerType=push"
        [[ -n "${DEVLAKE_SCOPE_ID}" ]] && log_info "  scopeId=${DEVLAKE_SCOPE_ID}"
        log_info "  viewUrl=${BUILD_URL:-}"
        log_info "  junit=@${JUNIT_FILE}"
        if [[ ${#timing_fields[@]} -gt 0 ]]; then
            log_info "  timing: ${timing_fields[*]}"
        fi
        return 0
    fi

    log_info "Pushing to DevLake Test Registry..."

    # extraArgs: omit until server has extraArgs support; include when deployed.
    # The full snapshot carries operator_image_sha (${SNAP_OPERATOR_SHA}) and all env detail.
    #   -F "extraArgs=@${SNAPSHOT_FILE}"
    local response http_code body
    response=$(curl -s -w "\n%{http_code}" -X POST \
        -H "Authorization: Bearer ${DEVLAKE_API_KEY}" \
        -F "jobId=${job_id}" \
        -F "jobName=${job_name}" \
        -F "organization=${DEVLAKE_ORG}" \
        -F "repository=${DEVLAKE_REPO}" \
        -F "result=${result}" \
        -F "jobType=jenkins" \
        -F "triggerType=push" \
        -F "viewUrl=${BUILD_URL:-}" \
        "${scope_fields[@]}" \
        "${timing_fields[@]}" \
        -F "junit=@${JUNIT_FILE}" \
        "${push_url}") || { log_error "curl failed (network error)"; exit 1; }

    http_code=$(tail -n1 <<< "${response}")
    body=$(sed '$d' <<< "${response}")

    log_verbose "Response body: ${body}"

    if [[ "${http_code}" != "200" ]]; then
        log_error "Push failed for job_id=${job_id} (HTTP ${http_code}): ${body}"
        exit 1
    fi

    log_info "Push succeeded: ${job_id}"
}

# --- Main Execution ---

main() {
    parse_args "$@"

    log_info "Starting DevLake Test Registry submission"

    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not found. Please install jq."
        exit 1
    fi

    if ! command -v python3 &> /dev/null; then
        log_error "python3 is required but not found."
        exit 1
    fi

    validate_environment
    set_defaults

    send_results

    log_info "DevLake submission completed successfully"
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
