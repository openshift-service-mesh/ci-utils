#!/bin/bash

# For information regarding this script, please refer to the README.md file in the same directory.

set -euo pipefail

# --- Global Variables ---
SCRIPT_START_TIME=$(date '+%Y%m%d_%H%M%S')
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
VERBOSE=false
DRY_RUN=false

# Operation modes
CREATE_CLUSTER=true
DELETE_CLUSTER=true

# State tracking
cluster_created=false
s3_bucket_created=false
cluster_destroyed=false
cleanup_done=false

# Log files
MAIN_LOG_FILE="mapt_cluster_${SCRIPT_START_TIME}.log"
CREATE_LOG_FILE="mapt_create_${SCRIPT_START_TIME}.log"
DESTROY_LOG_FILE="mapt_destroy_${SCRIPT_START_TIME}.log"

# Container names (unique per execution)
CREATE_CONTAINER_NAME="mapt-create-${SCRIPT_START_TIME}"
DESTROY_CONTAINER_NAME="mapt-destroy-${SCRIPT_START_TIME}"

# --- Security and Cleanup Functions ---

# Security function to clear sensitive variables
cleanup_credentials() {
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY 2>/dev/null || true
}

# Comprehensive cleanup function
cleanup() {
    # Disable ERR trap to prevent infinite loops during cleanup
    trap - ERR

    # Prevent cleanup from running multiple times
    if [ "$cleanup_done" = true ]; then
        log_info "Cleanup already completed, skipping..."
        return 0
    fi

    log_info "Starting cleanup process..."
    cleanup_done=true

    # Determine if we should destroy the cluster
    should_destroy=false

    if [ "$DELETE_CLUSTER" = true ]; then
        log_verbose "Delete mode enabled, will destroy cluster if it exists"
        should_destroy=true
    elif [ "$cluster_created" = true ] && [ "$?" -ne 0 ]; then
        log_info "Error detected and cluster was created, will destroy for cleanup"
        should_destroy=true
    fi

    # Check if cluster exists
    cluster_exists=false
    if [ "$cluster_created" = true ] || container_exists "$CREATE_CONTAINER_NAME"; then
        cluster_exists=true
    elif [ "$BACKEND_URL_TYPE" = "s3" ] && [ "$DELETE_CLUSTER" = true ]; then
        # For delete-only operations, check if Pulumi state exists in S3
        if aws s3 ls "s3://$S3_BUCKET_NAME/.pulumi/" &>/dev/null; then
            log_verbose "Found Pulumi state files in S3, cluster exists for deletion"
            cluster_exists=true
        fi
    fi

    # Destroy cluster if needed
    if [ "$should_destroy" = true ] && [ "$cluster_exists" = true ]; then
        if [ "$DRY_RUN" = true ]; then
            log_info "DRY RUN: Would destroy cluster: $CLUSTER_NAME"
        else
            destroy_cluster
        fi
    fi

    # Only clean up S3 bucket if cluster was successfully destroyed
    # This preserves the Pulumi state files needed for cluster cleanup
    if [ "$BACKEND_URL_TYPE" = "s3" ] && [ "$DRY_RUN" = false ]; then
        if [ "$cluster_destroyed" = true ]; then
            log_info "Cluster successfully destroyed, cleaning up S3 bucket: $S3_BUCKET_NAME"
            if aws s3 rb "s3://$S3_BUCKET_NAME" --force 2>/dev/null; then
                log_info "S3 bucket deleted successfully"
            else
                log_warn "Failed to delete S3 bucket - may need manual cleanup"
            fi
        else
            log_warn "Preserving S3 bucket for cluster cleanup: $S3_BUCKET_NAME"
            if [ "$cluster_created" = true ]; then
                log_warn "IMPORTANT: Cluster resources may still be running in AWS!"
                log_warn "To properly clean up:"
                log_warn "  1. First destroy the cluster: $0 --delete"
                log_warn "  2. Then delete the S3 bucket: aws s3 rb s3://$S3_BUCKET_NAME --force"
            else
                log_info "Cluster was not created, but S3 bucket may contain state files"
                log_info "You can safely delete the S3 bucket: aws s3 rb s3://$S3_BUCKET_NAME --force"
            fi
        fi
    fi

    # Clean up containers (force removal to ensure cleanup)
    cleanup_containers

    # Clear credentials
    cleanup_credentials

    log_info "Cleanup completed"
}

# Set up traps for cleanup
trap 'log_error "Script aborted due to error. Running cleanup..."; cleanup' ERR
trap 'log_warn "Script interrupted by user. Running cleanup..."; cleanup' INT TERM
trap 'cleanup' EXIT

# --- Logging Functions ---

log_with_timestamp() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$MAIN_LOG_FILE"
}

log_info() {
    log_with_timestamp "[INFO] $*"
}

log_warn() {
    log_with_timestamp "[WARN] $*" >&2
}

log_error() {
    log_with_timestamp "[ERROR] $*" >&2
}

log_verbose() {
    if [ "$VERBOSE" = true ]; then
        log_with_timestamp "[VERBOSE] $*"
    fi
}

log_continue() {
    echo "$*" | tee -a "$MAIN_LOG_FILE"
}

# --- Helper Functions ---

show_help() {
    cat << EOF
Generic MAPT Cluster Management Tool

USAGE:
    $0 [OPTIONS]

DESCRIPTION:
    Standardized tool for creating and managing OpenShift clusters using MAPT
    across different environments (local development and CI/CD pipelines).

OPTIONS:
    --create                Create cluster only (don't delete)
    --delete                Delete cluster only (don't create)
    Default (no options)    Create cluster, then delete it after completion
    -h, --help              Show this help message and exit
    -v, --verbose           Enable verbose logging
    --dry-run              Show what would be executed without running

REQUIRED ENVIRONMENT VARIABLES:
    AWS_ACCESS_KEY_ID       AWS access key for S3 and cluster provisioning
    AWS_SECRET_ACCESS_KEY   AWS secret key for S3 and cluster provisioning

OPTIONAL ENVIRONMENT VARIABLES:
    AWS_DEFAULT_REGION      AWS region for resources (default: us-east-1)
    CLUSTER_NAME           Name of the cluster project (default: auto-generated)
    CLUSTER_VERSION        OpenShift version (default: 4.19.0)
    CLUSTER_CPUS           Number of CPUs (default: 16)
    CLUSTER_MEMORY         Memory in GB (default: 64)
    CLUSTER_SPOT           Use spot instances (default: true)
    PULL_SECRET_FILE       Path to pull secret file (default: ./pull-secret.json)
    CLUSTER_TAGS           Additional tags (default: basic tags)
    BACKEND_URL_TYPE        Backing URL type: "s3" or "file" (auto-detected)
    S3_BUCKET_PREFIX       S3 bucket prefix (default: mapt-cluster)
    CONTAINER_ENGINE       Container engine: "podman" or "docker" (default: podman)
    MAPT_IMAGE            MAPT container image (default: latest stable)
    LOG_LEVEL             Logging: "verbose" or "normal" (default: normal)

EXAMPLES:
    # Basic usage (create and delete)
    export AWS_ACCESS_KEY_ID="your_key"
    export AWS_SECRET_ACCESS_KEY="your_secret"
    $0

    # Create cluster only for testing
    $0 --create --verbose

    # Custom cluster configuration
    export CLUSTER_NAME="my-test-cluster"
    export CLUSTER_VERSION="4.18.0"
    export CLUSTER_CPUS=8
    export CLUSTER_MEMORY=32
    $0

    # Delete existing cluster
    export CLUSTER_NAME="existing-cluster"
    $0 --delete

ENVIRONMENT DETECTION:
    The script automatically detects the environment:
    - CI Environment: Set CI=true to use S3 backing with auto-generated bucket names
    - Local Environment: Uses file-based backing in current directory

LOGS:
    All operations are logged to timestamped files:
    - $MAIN_LOG_FILE (main log)
    - mapt_create_*.log (cluster creation)
    - mapt_destroy_*.log (cluster destruction)

EOF
}

# Check if container exists
container_exists() {
    local container_name="$1"
    local engine="${CONTAINER_ENGINE:-podman}"
    "$engine" ps -a --format "{{.Names}}" | grep -q "^${container_name}$" 2>/dev/null
}

# Clean up containers
cleanup_containers() {
    log_verbose "Cleaning up containers..."

    # Use default container engine if not set yet
    local engine="${CONTAINER_ENGINE:-podman}"

    # Clean up specific containers by name
    for container_name in "$CREATE_CONTAINER_NAME" "$DESTROY_CONTAINER_NAME"; do
        if "$engine" ps -a --format "{{.Names}}" | grep -q "^${container_name}$" 2>/dev/null; then
            log_verbose "Removing container: $container_name"
            # First try to stop the container if it's running
            "$engine" stop "$container_name" &>/dev/null || true
            # Then force remove it
            "$engine" rm -f "$container_name" &>/dev/null || true
        fi
    done

    # Also clean up any containers that might have been left from previous runs
    # Look for containers with the mapt-create or mapt-destroy pattern
    local old_containers
    old_containers=$("$engine" ps -a --format "{{.Names}}" | grep -E "^mapt-(create|destroy)-" 2>/dev/null || true)

    if [ -n "$old_containers" ]; then
        log_verbose "Found old MAPT containers, cleaning up..."
        echo "$old_containers" | while read -r container_name; do
            if [ -n "$container_name" ]; then
                log_verbose "Removing old container: $container_name"
                "$engine" stop "$container_name" &>/dev/null || true
                "$engine" rm -f "$container_name" &>/dev/null || true
            fi
        done
    fi
}

# Detect environment and set defaults
detect_environment() {
    # Detect if running in CI environment
    if [ "${CI:-}" = "true" ]; then
        log_info "CI environment detected"
        IS_CI=true

        # Auto-generate cluster name for CI if not provided
        if [ -z "${CLUSTER_NAME:-}" ]; then
            CLUSTER_NAME="mapt-ci-${SCRIPT_START_TIME}"
        fi

        # Set S3 backing for CI
        BACKEND_URL_TYPE="s3"
    else
        log_info "Local environment detected"
        IS_CI=false
        BACKEND_URL_TYPE="${BACKEND_URL_TYPE:-file}"
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --create)
                CREATE_CLUSTER=true
                DELETE_CLUSTER=false
                log_verbose "Mode: Create cluster only"
                shift
                ;;
            --delete)
                CREATE_CLUSTER=false
                DELETE_CLUSTER=true
                log_verbose "Mode: Delete cluster only"
                shift
                ;;
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
                log_info "DRY RUN mode enabled - no actual operations will be performed"
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

    if [ -z "${AWS_ACCESS_KEY_ID:-}" ]; then
        missing_vars+=("AWS_ACCESS_KEY_ID")
    fi

    if [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
        missing_vars+=("AWS_SECRET_ACCESS_KEY")
    fi

    if [ ${#missing_vars[@]} -gt 0 ]; then
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
    # Detect environment first
    detect_environment

    readonly AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-"us-east-1"}
    readonly CLUSTER_NAME=${CLUSTER_NAME:-"mapt-cluster-${SCRIPT_START_TIME}"}
    readonly CLUSTER_VERSION=${CLUSTER_VERSION:-"4.20.0"}
    readonly CLUSTER_CPUS=${CLUSTER_CPUS:-16}
    readonly CLUSTER_MEMORY=${CLUSTER_MEMORY:-64}
    readonly CLUSTER_SPOT=${CLUSTER_SPOT:-true}
    readonly PULL_SECRET_FILE=${PULL_SECRET_FILE:-"./pull-secret.json"}
    readonly CLUSTER_TAGS=${CLUSTER_TAGS:-"tool=mapt"}
    readonly S3_BUCKET_PREFIX=${S3_BUCKET_PREFIX:-"mapt-cluster"}
    readonly CONTAINER_ENGINE=${CONTAINER_ENGINE:-"podman"}
    readonly MAPT_IMAGE=${MAPT_IMAGE:-"quay.io/redhat-developer/mapt:v0.9.9"}

    # Set backing URL based on environment
    if [ "$BACKEND_URL_TYPE" = "s3" ]; then
        readonly S3_BUCKET_NAME="${S3_BUCKET_PREFIX}-${CLUSTER_NAME}"
        readonly BACKED_URL="s3://${S3_BUCKET_NAME}"
    else
        readonly BACKED_URL="file:///workspace"
    fi

    # Enable verbose if LOG_LEVEL is set to verbose
    if [ "${LOG_LEVEL:-}" = "verbose" ]; then
        VERBOSE=true
    fi

    log_verbose "Configuration loaded:"
    if [ "$IS_CI" = true ]; then
        log_verbose "  Environment: CI"
    else
        log_verbose "  Environment: Local"
    fi
    log_verbose "  Cluster Name: $CLUSTER_NAME"
    log_verbose "  Cluster Version: $CLUSTER_VERSION"
    log_verbose "  Cluster CPUs: $CLUSTER_CPUS"
    log_verbose "  Cluster Memory: ${CLUSTER_MEMORY}GB"
    log_verbose "  Spot Instances: $CLUSTER_SPOT"
    log_verbose "  Backing URL: $BACKED_URL"
    log_verbose "  Container Engine: $CONTAINER_ENGINE"
    log_verbose "  MAPT Image: $MAPT_IMAGE"
    log_verbose "  Pull Secret: $PULL_SECRET_FILE"
    log_verbose "  Cluster Tags: $CLUSTER_TAGS"
}

# --- Core Functions ---

# Create S3 bucket if needed
create_s3_bucket() {
    if [ "$BACKEND_URL_TYPE" = "s3" ]; then
        log_info "Creating S3 bucket: $S3_BUCKET_NAME"

        if [ "$DRY_RUN" = true ]; then
            log_info "DRY RUN: Would create S3 bucket: $S3_BUCKET_NAME"
            return 0
        fi

        if aws s3api create-bucket --bucket "$S3_BUCKET_NAME" --region "$AWS_DEFAULT_REGION" 2>/dev/null; then
            s3_bucket_created=true
            log_info "S3 bucket created successfully"
        else
            # Bucket might already exist, check if we can access it
            if aws s3 ls "s3://$S3_BUCKET_NAME" &>/dev/null; then
                log_info "S3 bucket already exists and is accessible"
            else
                log_error "Failed to create or access S3 bucket: $S3_BUCKET_NAME"
                exit 1
            fi
        fi
    fi
}

# Verify prerequisites
verify_prerequisites() {
    log_verbose "Verifying prerequisites..."

    # Check container engine
    if ! command -v "$CONTAINER_ENGINE" &> /dev/null; then
        log_error "Container engine '$CONTAINER_ENGINE' not found. Please install $CONTAINER_ENGINE."
        exit 1
    fi

    # Check AWS CLI if using S3 backing
    if [ "$BACKEND_URL_TYPE" = "s3" ] && ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found but S3 backing is enabled. Please install AWS CLI."
        exit 1
    fi

    # Check pull secret file
    if [ "$CREATE_CLUSTER" = true ] && [ ! -f "$PULL_SECRET_FILE" ]; then
        log_error "Pull secret file not found: $PULL_SECRET_FILE"
        log_error "Please ensure the pull secret file exists or set PULL_SECRET_FILE environment variable."
        exit 1
    fi

    log_verbose "Prerequisites verified successfully"
}

# Create cluster
create_cluster() {
    log_info "Creating OpenShift cluster: $CLUSTER_NAME"

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY RUN: Would create cluster with the following configuration:"
        log_info "  Name: $CLUSTER_NAME"
        log_info "  Version: $CLUSTER_VERSION"
        log_info "  CPUs: $CLUSTER_CPUS"
        log_info "  Memory: ${CLUSTER_MEMORY}GB"
        log_info "  Spot: $CLUSTER_SPOT"
        log_info "  Backing URL: $BACKED_URL"
        log_info "  Tags: $CLUSTER_TAGS"
        return 0
    fi

    # Prepare spot argument
    local spot_arg=""
    if [ "$CLUSTER_SPOT" = true ]; then
        spot_arg="--spot"
    fi

    log_info "Starting cluster creation container..."
    "$CONTAINER_ENGINE" run -d --name "$CREATE_CONTAINER_NAME" \
        -v "${PWD}:/workspace:z" \
        -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
        -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
        -e AWS_DEFAULT_REGION="$AWS_DEFAULT_REGION" \
        "$MAPT_IMAGE" aws openshift-snc create \
            --backed-url "$BACKED_URL" \
            --conn-details-output "/workspace" \
            --pull-secret-file "/workspace/$(basename "$PULL_SECRET_FILE")" \
            --project-name "$CLUSTER_NAME" \
            --tags "$CLUSTER_TAGS" \
            --version "$CLUSTER_VERSION" \
            $spot_arg \
            --cpus "$CLUSTER_CPUS" \
            --memory "$CLUSTER_MEMORY"

    # Wait for creation to complete
    log_info "Waiting for cluster creation to complete..."
    local container_id
    container_id=$("$CONTAINER_ENGINE" ps -q --filter "name=$CREATE_CONTAINER_NAME")

    if [ -z "$container_id" ]; then
        log_error "Create container did not start properly"
        exit 1
    fi

    # Show live logs if verbose mode is enabled
    if [ "$VERBOSE" = true ]; then
        log_info "Showing live container logs (press Ctrl+C to stop following logs):"
        log_info "Container logs will continue in background..."

        # Start following logs in background and save to file
        ("$CONTAINER_ENGINE" logs -f "$container_id" 2>&1 | tee "$CREATE_LOG_FILE") &
        local logs_pid=$!

        # Convert timeout to seconds
        local timeout_seconds=1200

        # Wait for container to complete
        if timeout "$timeout_seconds" "$CONTAINER_ENGINE" wait "$container_id"; then
            # Stop following logs
            kill $logs_pid 2>/dev/null || true
            wait $logs_pid 2>/dev/null || true

            local exit_code
            exit_code=$("$CONTAINER_ENGINE" inspect "$container_id" --format '{{.State.ExitCode}}')

            log_info "Container execution completed with exit code: $exit_code"
        else
            # Stop following logs on timeout
            kill $logs_pid 2>/dev/null || true
            wait $logs_pid 2>/dev/null || true
            log_error "Timeout waiting for cluster creation to complete"
            # Clean up container
            "$CONTAINER_ENGINE" rm -f "$CREATE_CONTAINER_NAME" &>/dev/null || true
            exit 1
        fi
    else
        # Convert timeout to seconds
        local timeout_seconds=1200

        if timeout "$timeout_seconds" "$CONTAINER_ENGINE" wait "$container_id"; then
            local exit_code
            exit_code=$("$CONTAINER_ENGINE" inspect "$container_id" --format '{{.State.ExitCode}}')

            # Save logs
            log_info "Saving cluster creation logs to $CREATE_LOG_FILE"
            "$CONTAINER_ENGINE" logs "$container_id" > "$CREATE_LOG_FILE" 2>&1
        else
            log_error "Timeout waiting for cluster creation to complete"
            # Save logs even on timeout
            "$CONTAINER_ENGINE" logs "$container_id" > "$CREATE_LOG_FILE" 2>&1
            # Clean up container
            "$CONTAINER_ENGINE" rm -f "$CREATE_CONTAINER_NAME" &>/dev/null || true
            exit 1
        fi
    fi

    local exit_code
    exit_code=$("$CONTAINER_ENGINE" inspect "$container_id" --format '{{.State.ExitCode}}')

    if [ "$exit_code" -eq 0 ]; then
        cluster_created=true
        log_info "Cluster created successfully: $CLUSTER_NAME"

        # Verify kubeconfig was created
        if [ -f "./kubeconfig" ]; then
            log_info "Kubeconfig file created successfully"
        else
            log_warn "Kubeconfig file not found after cluster creation"
        fi
    else
        log_error "Cluster creation failed with exit code: $exit_code"
        log_error "Check $CREATE_LOG_FILE for detailed error information"
        # Clean up container
        "$CONTAINER_ENGINE" rm -f "$CREATE_CONTAINER_NAME" &>/dev/null || true
        exit 1
    fi

    # Clean up the container after successful execution
    log_verbose "Cleaning up creation container: $CREATE_CONTAINER_NAME"
    "$CONTAINER_ENGINE" rm -f "$CREATE_CONTAINER_NAME" &>/dev/null || true
}

# Destroy cluster
destroy_cluster() {
    log_info "Destroying cluster: $CLUSTER_NAME"

    if [ "$DRY_RUN" = true ]; then
        log_info "DRY RUN: Would destroy cluster: $CLUSTER_NAME"
        return 0
    fi

    log_info "Starting cluster destruction container..."
    "$CONTAINER_ENGINE" run -d --name "$DESTROY_CONTAINER_NAME" \
        -v "${PWD}:/workspace:z" \
        -e AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
        -e AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
        -e AWS_DEFAULT_REGION="$AWS_DEFAULT_REGION" \
        "$MAPT_IMAGE" aws openshift-snc destroy \
            --project-name "$CLUSTER_NAME" \
            --backed-url "$BACKED_URL"

    # Wait for destruction to complete
    log_info "Waiting for cluster destruction to complete (timeout: 20m)..."
    local container_id
    container_id=$("$CONTAINER_ENGINE" ps -q --filter "name=$DESTROY_CONTAINER_NAME")

    if [ -n "$container_id" ]; then
        # Show live logs if verbose mode is enabled
        if [ "$VERBOSE" = true ]; then
            log_info "Showing live destruction logs:"

            # Start following logs in background and save to file
            ("$CONTAINER_ENGINE" logs -f "$container_id" 2>&1 | tee "$DESTROY_LOG_FILE") &
            local logs_pid=$!

            # Wait for container to complete
            if timeout 1200 "$CONTAINER_ENGINE" wait "$container_id"; then
                # Stop following logs
                kill $logs_pid 2>/dev/null || true
                wait $logs_pid 2>/dev/null || true

                local exit_code
                exit_code=$("$CONTAINER_ENGINE" inspect "$container_id" --format '{{.State.ExitCode}}')

                log_info "Destruction container completed with exit code: $exit_code"
            else
                # Stop following logs on timeout
                kill $logs_pid 2>/dev/null || true
                wait $logs_pid 2>/dev/null || true
                log_warn "Timeout waiting for cluster destruction to complete"
                log_warn "Cluster destruction may not have completed"
            fi
        else
            if timeout 1200 "$CONTAINER_ENGINE" wait "$container_id"; then
                local exit_code
                exit_code=$("$CONTAINER_ENGINE" inspect "$container_id" --format '{{.State.ExitCode}}')

                # Save logs
                log_info "Saving cluster destruction logs to $DESTROY_LOG_FILE"
                "$CONTAINER_ENGINE" logs "$container_id" > "$DESTROY_LOG_FILE" 2>&1
            else
                log_warn "Timeout waiting for cluster destruction to complete"
                # Save logs even on timeout
                "$CONTAINER_ENGINE" logs "$container_id" > "$DESTROY_LOG_FILE" 2>&1
                log_warn "Cluster destruction may not have completed"
            fi
        fi

        local exit_code
        exit_code=$("$CONTAINER_ENGINE" inspect "$container_id" --format '{{.State.ExitCode}}')

        if [ "$exit_code" -eq 0 ]; then
            cluster_destroyed=true
            log_info "Cluster destroyed successfully: $CLUSTER_NAME"
        else
            log_warn "Cluster destruction may have failed, exit code: $exit_code"
            log_warn "Check $DESTROY_LOG_FILE for detailed information"
            log_warn "S3 bucket will be preserved to allow manual cleanup"
        fi

        # Clean up the container after execution
        log_verbose "Cleaning up destruction container: $DESTROY_CONTAINER_NAME"
        "$CONTAINER_ENGINE" rm -f "$DESTROY_CONTAINER_NAME" &>/dev/null || true
    else
        log_warn "Could not find destroy container. Manual cleanup may be required for project: $CLUSTER_NAME"
    fi
}

# --- Main Execution ---

main() {
    # Initialize log file with proper permissions
    touch "$MAIN_LOG_FILE"
    chmod 600 "$MAIN_LOG_FILE"

    log_info "=== MAPT Cluster Management Tool Started ==="
    log_info "Script version: 1.0.0"
    log_info "Start time: $(date)"
    log_info "Log file: $MAIN_LOG_FILE"

    # Parse command line arguments
    parse_args "$@"

    # Validate and set up environment
    validate_environment
    set_defaults

    log_info "Operation modes - Create: $CREATE_CLUSTER, Delete: $DELETE_CLUSTER"
    log_info "Cluster name: $CLUSTER_NAME"
    if [ "$IS_CI" = true ]; then
        log_info "Environment: CI"
    else
        log_info "Environment: Local"
    fi

    # Record start time for duration calculation
    local start_time
    start_time=$(date +%s)

    # Verify prerequisites
    verify_prerequisites

    # Create S3 bucket if needed
    if [ "$CREATE_CLUSTER" = true ]; then
        create_s3_bucket
    fi

    # Execute requested operations
    if [ "$CREATE_CLUSTER" = true ]; then
        create_cluster
    fi

    # Note: Cluster deletion is handled in cleanup function
    # This ensures proper cleanup even on errors

    # Calculate and display execution summary
    local end_time elapsed hours minutes seconds
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    hours=$((elapsed / 3600))
    minutes=$(((elapsed % 3600) / 60))
    seconds=$((elapsed % 60))

    log_info ""
    log_info "=== EXECUTION SUMMARY ==="
    if [ "$CREATE_CLUSTER" = true ] && [ "$cluster_created" = true ]; then
        log_info "✓ Cluster created successfully: $CLUSTER_NAME"
    elif [ "$CREATE_CLUSTER" = true ]; then
        log_info "✗ Cluster creation failed or incomplete"
    fi

    if [ "$DELETE_CLUSTER" = true ]; then
        log_info "✓ Cluster deletion scheduled for cleanup"
    elif [ "$cluster_created" = true ]; then
        log_info "ℹ Cluster preserved (use '$0 --delete' to delete later)"
    fi

    log_info "Total execution time: $(printf "%02d:%02d:%02d" $hours $minutes $seconds)"
    log_info "Log files created:"
    log_info "  - $MAIN_LOG_FILE (main execution log)"
    if [ -f "$CREATE_LOG_FILE" ]; then
        log_info "  - $CREATE_LOG_FILE (cluster creation log)"
    fi
    if [ -f "$DESTROY_LOG_FILE" ]; then
        log_info "  - $DESTROY_LOG_FILE (cluster destruction log)"
    fi
    log_info "========================="

    log_info "Script execution completed. Cleanup will run automatically."
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi