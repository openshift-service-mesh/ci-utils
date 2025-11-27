#!/bin/bash

# For more information please check the README.md file in the same directory.

set -o nounset
set -o errexit
set -o pipefail

# --- Global Variables ---
VERBOSE=false
DRY_RUN=false

# Path to the metadata file used for Data Router submission
# Stored in /tmp to ensure writability in containerized environments
METADATA_FILE="/tmp/metadata.json"

# Security function to clear sensitive variables
cleanup_credentials() {
    unset DATA_ROUTER_USERNAME DATA_ROUTER_PASSWORD 2>/dev/null || true
}

# Security: Set up trap to clean up credentials on script exit
trap cleanup_credentials EXIT ERR INT TERM

# --- Helper Functions ---

show_help() {
    cat << EOF
Generic Report Portal Results Sender via Data Router

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help          Show this help message and exit
    -v, --verbose       Enable verbose output
    --dry-run          Show what would be sent without actually sending

REQUIRED ENVIRONMENT VARIABLES:
    REPORT_PORTAL_HOSTNAME    Report Portal hostname (e.g., "reportportal.example.com")
    REPORT_PORTAL_PROJECT     Report Portal project name

OPTIONAL ENVIRONMENT VARIABLES:
    TESTRUN_NAME             Name of the test run (default: "Test Run")
    TESTRUN_DESCRIPTION      Description of the test run (default: "Automated test run")
    TEST_RESULTS_DIR         Directory containing test result files (default: "/tmp/artifacts")
    TEST_FILE_NAME           Name of the JUnit XML test result file (default: "junit.xml")
    PRODUCT_VERSION          Version of the product being tested (default: "unknown")
    TEST_SUITE               Name of the test suite (default: "automated-tests")
    TEST_REPO                Repository being tested (default: current git repo or "unknown")
    INSTALLATION_METHOD      Method used for installation (default: "unknown")
    PRODUCT_STAGE            Product stage (default: "upstream")
    EXTRA_ATTRIBUTES         JSON array of additional key/value pairs for metadata
    DATA_ROUTER_URL          Data Router URL (default: "https://datarouter.ccitredhat.com")
    DATA_ROUTER_USERNAME     Data Router username (alternative to /creds-data-router/username file)
    DATA_ROUTER_PASSWORD     Data Router password/token (alternative to /creds-data-router/token file)

EXAMPLES:
    # Basic usage
    export REPORT_PORTAL_HOSTNAME="reportportal.example.com"
    export REPORT_PORTAL_PROJECT="my_project"
    $0

    # With custom settings
    export REPORT_PORTAL_HOSTNAME="reportportal.example.com"
    export REPORT_PORTAL_PROJECT="my_project"
    export TEST_FILE_NAME="integration-tests.xml"
    export TESTRUN_NAME="Integration Tests"
    export PRODUCT_VERSION="v1.2.3"
    $0 --verbose

    # Using environment variables for credentials
    export REPORT_PORTAL_HOSTNAME="reportportal.example.com"
    export REPORT_PORTAL_PROJECT="my_project"
    export DATA_ROUTER_USERNAME="my_username"
    export DATA_ROUTER_PASSWORD="my_token"
    $0

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

# Function to detect current git repository name
detect_git_repo() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        basename "$(git rev-parse --show-toplevel)" 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# Parse command line arguments
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

# Validate required environment variables
validate_environment() {
    local missing_vars=()

    if [[ -z "${REPORT_PORTAL_HOSTNAME:-}" ]]; then
        missing_vars+=("REPORT_PORTAL_HOSTNAME")
    fi

    if [[ -z "${REPORT_PORTAL_PROJECT:-}" ]]; then
        missing_vars+=("REPORT_PORTAL_PROJECT")
    fi

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            log_error "  - $var"
        done
        log_error ""
        log_error "Please set the required variables and try again."
        log_error "Use --help for more information."
        exit 1
    fi
}

# Set default values for optional environment variables
set_defaults() {
    readonly DATA_ROUTER_URL=${DATA_ROUTER_URL:-"https://datarouter.ccitredhat.com"}
    readonly TESTRUN_NAME=${TESTRUN_NAME:-"Test Run"}
    readonly TESTRUN_DESCRIPTION=${TESTRUN_DESCRIPTION:-"Automated test run"}
    readonly TEST_RESULTS_DIR=${TEST_RESULTS_DIR:-"/tmp/artifacts"}
    readonly TEST_FILE_NAME=${TEST_FILE_NAME:-"junit.xml"}
    readonly PRODUCT_VERSION=${PRODUCT_VERSION:-"unknown"}
    readonly TEST_SUITE=${TEST_SUITE:-"automated-tests"}
    readonly TEST_REPO=${TEST_REPO:-$(detect_git_repo)}
    readonly INSTALLATION_METHOD=${INSTALLATION_METHOD:-"unknown"}
    readonly PRODUCT_STAGE=${PRODUCT_STAGE:-"upstream"}
    readonly EXTRA_ATTRIBUTES=${EXTRA_ATTRIBUTES:-""}

    log_verbose "Configuration loaded:"
    log_verbose "  Report Portal: ${REPORT_PORTAL_HOSTNAME}/${REPORT_PORTAL_PROJECT}"
    log_verbose "  Data Router URL: ${DATA_ROUTER_URL}"
    log_verbose "  Test Run: ${TESTRUN_NAME}"
    log_verbose "  Test File: ${TEST_RESULTS_DIR}/${TEST_FILE_NAME}"
    log_verbose "  Product Version: ${PRODUCT_VERSION}"
    log_verbose "  Test Suite: ${TEST_SUITE}"
    log_verbose "  Test Repository: ${TEST_REPO}"
    log_verbose "  Product Stage: ${PRODUCT_STAGE}"
}

# --- Core Functions ---

create_metadata_file() {
    local starttime=$(date +%s)

    log_verbose "Creating metadata file: ${METADATA_FILE}"

    cat << EOF > "${METADATA_FILE}"
{
    "targets": {
        "reportportal": {
            "config": {
                "hostname": "${REPORT_PORTAL_HOSTNAME}",
                "project": "${REPORT_PORTAL_PROJECT}"
            },
            "processing": {
                "apply_tfa": false,
                "launch": {
                    "name": "${TESTRUN_NAME}",
                    "description": "${TESTRUN_DESCRIPTION}",
                    "startTime": ${starttime},
                    "attributes": [
                        {
                            "key": "tool",
                            "value": "data-router"
                        },
                        {
                            "key": "product_version",
                            "value": "${PRODUCT_VERSION}"
                        },
                        {
                            "key": "product_stage",
                            "value": "${PRODUCT_STAGE}"
                        },
                        {
                            "key": "test_suite",
                            "value": "${TEST_SUITE}"
                        },
                        {
                            "key": "installation_method",
                            "value": "${INSTALLATION_METHOD}"
                        },
                        {
                            "key": "test_repo",
                            "value": "${TEST_REPO}"
                        }
                    ]
                }
            }
        }
    }
}
EOF

    # Check if there are any extra attributes to add
    if [[ -n "${EXTRA_ATTRIBUTES}" ]]; then
        log_verbose "Adding extra attributes to metadata"

        local temp_file="/tmp/metadata_tmp.json"
        if ! jq --argjson extra "${EXTRA_ATTRIBUTES}" '.targets.reportportal.processing.launch.attributes += $extra' "${METADATA_FILE}" > "${temp_file}"; then
            log_error "Failed to merge extra attributes. Please check EXTRA_ATTRIBUTES format."
            log_error "Expected format: '[{\"key\": \"k1\", \"value\": \"v1\"}, {\"key\": \"k2\", \"value\": \"v2\"}]'"
            rm -f "${temp_file}" "${METADATA_FILE}"
            exit 1
        fi
        mv "${temp_file}" "${METADATA_FILE}"
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "DRY RUN: Metadata file content:"
        cat "${METADATA_FILE}"
    else
        log_verbose "Metadata file created successfully"
    fi
}

verify_test_file() {
    local test_file_path="${TEST_RESULTS_DIR}/${TEST_FILE_NAME}"

    log_verbose "Verifying test results file: ${test_file_path}"

    # Check if test results directory exists
    if [[ ! -d "${TEST_RESULTS_DIR}" ]]; then
        log_error "Test results directory '${TEST_RESULTS_DIR}' does not exist."
        exit 1
    fi

    # Verify test results file exists and is readable
    if [[ ! -f "${test_file_path}" ]]; then
        log_error "Test results file '${test_file_path}' not found."
        log_info "Available files in ${TEST_RESULTS_DIR}:"
        ls -la "${TEST_RESULTS_DIR}" 2>/dev/null || log_error "Could not list test results directory contents"
        exit 1
    fi

    if [[ ! -r "${test_file_path}" ]]; then
        log_error "Test results file '${test_file_path}' is not readable."
        exit 1
    fi

    log_info "Test results file found: ${test_file_path}"
    log_verbose "File size: $(du -h "${test_file_path}" | cut -f1)"
}

verify_credentials() {
    log_verbose "Verifying Data Router credentials"

    # Try to get credentials from environment variables first
    if [[ -n "${DATA_ROUTER_USERNAME:-}" && -n "${DATA_ROUTER_PASSWORD:-}" ]]; then
        log_verbose "Using Data Router credentials from environment variables"
        # Validate credentials are not empty strings
        if [[ "${DATA_ROUTER_USERNAME}" == "" || "${DATA_ROUTER_PASSWORD}" == "" ]]; then
            log_error "Data Router credentials cannot be empty strings"
            exit 1
        fi
        export DATA_ROUTER_USERNAME
        export DATA_ROUTER_PASSWORD
        log_verbose "Data Router credentials verified successfully (from environment)"
        return 0
    fi

    # Fallback to file-based credentials
    log_verbose "Environment variables not set, trying file-based credentials"

    # Check if both username and password files exist
    if [[ ! -f /creds-data-router/username || ! -f /creds-data-router/token ]]; then
        log_error "Data Router credentials not found"
        log_error "Please provide credentials using one of these methods:"
        log_error "  1. Environment variables: DATA_ROUTER_USERNAME and DATA_ROUTER_PASSWORD"
        log_error "  2. Files: /creds-data-router/username and /creds-data-router/token"
        exit 1
    fi

    if [[ ! -r /creds-data-router/username || ! -r /creds-data-router/token ]]; then
        log_error "Data Router credentials files are not readable"
        exit 1
    fi

    DATA_ROUTER_USERNAME=$(cat /creds-data-router/username)
    DATA_ROUTER_PASSWORD=$(cat /creds-data-router/token)

    if [[ -z "${DATA_ROUTER_USERNAME}" || -z "${DATA_ROUTER_PASSWORD}" ]]; then
        log_error "Data Router username or password is empty"
        exit 1
    fi

    export DATA_ROUTER_USERNAME
    export DATA_ROUTER_PASSWORD
    log_verbose "Data Router credentials verified successfully (from files)"
}

send_results() {
    local test_file_path="${TEST_RESULTS_DIR}/${TEST_FILE_NAME}"

    log_info "Preparing to send test results from '${test_file_path}'"

    # Verify prerequisites
    verify_test_file
    verify_credentials

    # Create metadata file
    create_metadata_file

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "DRY RUN: Would send the following:"
        log_info "  Metadata file: ${METADATA_FILE}"
        log_info "  Test results: ${test_file_path}"
        log_info "  Data Router URL: ${DATA_ROUTER_URL}"
        rm -f "${METADATA_FILE}"
        return 0
    fi

    # Check if droute command is available
    if ! command -v droute &> /dev/null; then
        log_error "droute command not found. Please ensure it's installed and available in PATH."
        rm -f "${METADATA_FILE}"
        exit 1
    fi

    log_info "Sending test results to Report Portal via Data Router..."
    log_verbose "Command: droute send --metadata ${METADATA_FILE} --results ${test_file_path} --url ${DATA_ROUTER_URL} [credentials passed via environment]"

    # Credentials are already exported as environment variables, which is secure
    # droute will read DATA_ROUTER_USERNAME and DATA_ROUTER_PASSWORD from the environment
    local max_retries=10
    local retry_delay=1
    local attempt=1
    local success=false

    while [[ ${attempt} -le ${max_retries} ]]; do
        if [[ ${attempt} -gt 1 ]]; then
            log_info "Retry attempt ${attempt}/${max_retries}..."
        fi

        if droute send \
            --metadata "${METADATA_FILE}" \
            --results "${test_file_path}" \
            --username "${DATA_ROUTER_USERNAME}" \
            --password "${DATA_ROUTER_PASSWORD}" \
            --url "${DATA_ROUTER_URL}" \
            --wait=10 \
            ${VERBOSE:+--verbose}; then
            success=true
            break
        fi

        if [[ ${attempt} -lt ${max_retries} ]]; then
            log_verbose "Attempt ${attempt} failed, waiting ${retry_delay} second(s) before retry..."
            sleep ${retry_delay}
        fi

        ((attempt++))
    done

    if [[ "${success}" != "true" ]]; then
        log_error "Failed to send results to Data Router after ${max_retries} attempts"
        rm -f "${METADATA_FILE}"
        exit 1
    fi

    log_info "Results sent successfully to Report Portal"
    log_info "Cleaning up metadata file..."
    rm -f "${METADATA_FILE}"

    # Security: Clear credentials from environment after use
    cleanup_credentials
}

# --- Main Execution ---

main() {
    # Parse command line arguments
    parse_args "$@"

    log_info "Starting Report Portal results submission via Data Router"

    # Validate environment and set defaults
    validate_environment
    set_defaults

    # Check required tools
    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not found. Please install jq."
        exit 1
    fi

    # Send results
    send_results

    log_info "Report Portal submission completed successfully"
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
