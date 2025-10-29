# MAPT Cluster Management Tool

A standardized, reusable tool for creating and managing OpenShift clusters using MAPT (Managed Application Platform Tools) across different environments - from local development to CI/CD pipelines.

## Features

- **Multi-Environment Support**: Works seamlessly in local development and CI/CD environments
- **Automatic Environment Detection**: Auto-detects CI vs local environments and adjusts configuration
- **Flexible Backing URLs**: Supports both S3 (for CI) and local file-based backing
- **S3 Bucket Management**: Automatic creation and cleanup of S3 buckets for CI environments
- **Comprehensive Logging**: Timestamped logs with separate files for different operations and live log streaming in verbose mode
- **Secure Credential Handling**: No credentials logged, automatic cleanup on exit
- **Configurable Cluster Specs**: CPU, memory, version, and other cluster parameters
- **Error Handling**: Proper cleanup on failures with detailed error reporting
- **Container Engine Flexibility**: Supports both Podman and Docker

## Prerequisites

### Required Tools
- **Container Engine**: Podman (recommended) or Docker
- **AWS CLI**: Required when using S3 backing (CI environments)

### Required Credentials
- **AWS Access Key ID**: For S3 operations and cluster provisioning
- **AWS Secret Access Key**: For S3 operations and cluster provisioning
- **OpenShift Pull Secret**: Valid pull secret file for cluster creation

## Installation

1. Copy the script to your desired location
2. Make it executable: `chmod +x create_mapt_cluster.sh`
3. Ensure prerequisites are installed and available in PATH

## Usage

### Basic Usage

```bash
# Set required environment variables
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"

# Ensure pull secret is available
cp /path/to/your/pull-secret.json ./pull-secret.json

# Create and destroy cluster (default behavior)
./create_mapt_cluster.sh
```

### Advanced Usage

```bash
# Create cluster only (for development/testing/ci)
./create_mapt_cluster.sh --create --verbose

# Delete existing cluster only
export CLUSTER_NAME="my-existing-cluster"
./create_mapt_cluster.sh --delete

# Custom cluster configuration
export CLUSTER_NAME="my-test-cluster"
export CLUSTER_VERSION="4.18.0"
export CLUSTER_CPUS=8
export CLUSTER_MEMORY=32
export CLUSTER_SPOT=false
./create_mapt_cluster.sh --verbose

# Test configuration without execution
./create_mapt_cluster.sh --dry-run --verbose
```

## Environment Variables

### Required

| Variable | Description | Example |
|----------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS access key for S3 and cluster provisioning | `AKIA...` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key for S3 and cluster provisioning | `abcd1234...` |

### Optional Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `AWS_DEFAULT_REGION` | `us-east-1` | AWS region for resources |
| `CLUSTER_NAME` | `mapt-cluster-{timestamp}` | Name of the cluster project |
| `CLUSTER_VERSION` | `4.20.0` | OpenShift version to deploy (full version with patch required, e.g., `4.20.0`) |
| `CLUSTER_CPUS` | `16` | Number of CPUs for the cluster |
| `CLUSTER_MEMORY` | `64` | Memory in GB for the cluster |
| `CLUSTER_SPOT` | `true` | Use spot instances (true/false) |
| `CLUSTER_TIMEOUT` | `60` | Timeout for cluster operations in minutes |
| `PULL_SECRET_FILE` | `./pull-secret.json` | Path to pull secret file |
| `CLUSTER_TAGS` | Basic tags | Additional tags for AWS resources |
| `BACKEND_URL_TYPE` | Auto-detected | Backing URL type: "s3" or "file" |
| `S3_BUCKET_PREFIX` | `mapt-cluster` | Prefix for S3 bucket names |
| `CONTAINER_ENGINE` | `podman` | Container engine: "podman" or "docker" |
| `MAPT_IMAGE` | `quay.io/redhat-developer/mapt:v0.9.4` | MAPT container image |
| `LOG_LEVEL` | `normal` | Logging verbosity: "verbose" or "normal" |

## Command Line Options

| Option | Description |
|--------|-------------|
| `--create` | Create cluster only (don't delete) |
| `--delete` | Delete cluster only (don't create) |
| Default (no options) | Create cluster, then delete it after completion |
| `-h, --help` | Show help message and exit |
| `-v, --verbose` | Enable verbose logging |
| `--dry-run` | Show what would be executed without running |

**Note**: The default behavior creates a cluster and then immediately deletes it. This is useful for end-to-end testing of the cluster lifecycle. For typical CI/CD workflows, you would:
1. Use `--create` to create the cluster
2. Run your tests or workloads
3. Use `--delete` to clean up the cluster after tests complete

## Environment Detection

The script automatically detects the environment and adjusts its behavior:

### CI Environment Detection
The script detects CI environments by checking for these variables:
- `CI=true` (generic CI indicator)

### CI Environment Behavior
- **Backing URL**: Uses S3 with auto-generated bucket names
- **Cluster Name**: Auto-generates with timestamp if not provided
- **S3 Management**: Automatically creates and cleans up S3 buckets
- **Logging**: Enhanced logging for CI debugging

### Local Environment Behavior
- **Backing URL**: Uses local file-based backing (`file:///workspace`)
- **Cluster Name**: Uses provided name or generates timestamped name
- **S3 Management**: No S3 operations (unless explicitly configured)
- **Logging**: Standard logging to local files

## Examples

### Local Development

```bash
# Basic local cluster for development
export AWS_ACCESS_KEY_ID="your_key"
export AWS_SECRET_ACCESS_KEY="your_secret"
export CLUSTER_NAME="dev-cluster"
./create_mapt_cluster.sh --create --verbose
```

### CI/CD Pipeline Usage

#### GitHub Actions

```yaml
- name: Create OpenShift cluster
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    CI: true
    CLUSTER_NAME: "gh-${{ github.run_id }}"
    CLUSTER_VERSION: "4.19.0"
    PULL_SECRET_FILE: "./pull-secret.json"
  run: |
    echo "${{ secrets.PULL_SECRET_CONTENT }}" > pull-secret.json
    ./mapt_cluster/create_mapt_cluster.sh --create --verbose

- name: Run tests
  env:
    KUBECONFIG: ./kubeconfig
  run: |
    # Your test commands here
    make test.e2e.ocp

- name: Cleanup cluster
  if: always()
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    CI: true
    CLUSTER_NAME: "gh-${{ github.run_id }}"
  run: |
    ./mapt_cluster/create_mapt_cluster.sh --delete
```

### Custom Configuration Examples

```bash
# High-spec cluster for performance testing
export CLUSTER_CPUS=32
export CLUSTER_MEMORY=128
export CLUSTER_SPOT=false
export CLUSTER_TIMEOUT=90
./create_mapt_cluster.sh

# Minimal cluster for quick testing
export CLUSTER_CPUS=8
export CLUSTER_MEMORY=32
export CLUSTER_VERSION="4.18.0"
./create_mapt_cluster.sh --create

# Custom tags and S3 configuration
export CLUSTER_TAGS="project=myproject,team=platform,environment=testing"
export S3_BUCKET_PREFIX="mycompany-mapt"
./create_mapt_cluster.sh

# Using custom MAPT image version
export MAPT_IMAGE="quay.io/redhat-developer/mapt:v0.9.3"
export CONTAINER_ENGINE="docker"
./create_mapt_cluster.sh --verbose
```

## Logging

The script creates comprehensive logs for all operations:

### Log Files

| File | Content |
|------|---------|
| `mapt_cluster_YYYYMMDD_HHMMSS.log` | Main execution log with timestamps |
| `mapt_create_YYYYMMDD_HHMMSS.log` | Cluster creation container logs |
| `mapt_destroy_YYYYMMDD_HHMMSS.log` | Cluster destruction container logs |

### Log Levels

- **Normal**: Standard information and error messages with logs saved to files
- **Verbose**: Detailed configuration and operation information with live container logs displayed in real-time

### Log Security

- No AWS credentials are ever logged
- Sensitive information is redacted in logs
- Log files are created with restricted permissions (600)

## Troubleshooting

### Common Issues

1. **Container engine not found**
   ```bash
   # Install Podman (recommended)
   # Ubuntu/Debian
   sudo apt-get install podman

   # RHEL/CentOS/Fedora
   sudo dnf install podman

   # macOS
   brew install podman
   ```

2. **AWS CLI not found** (for S3 backing)
   ```bash
   # Install AWS CLI
   # Using pip
   pip install awscli

   # Using package manager
   # Ubuntu/Debian
   sudo apt-get install awscli
   ```

3. **Pull secret file not found**
   ```bash
   # Download from Red Hat Cloud Console
   # https://console.redhat.com/openshift/install/pull-secret

   # Or set custom location
   export PULL_SECRET_FILE="/path/to/your/pull-secret.json"
   ```

4. **Cluster creation timeout**
   ```bash
   # Increase timeout for slow environments
   export CLUSTER_TIMEOUT=120  # 2 hours
   ```

5. **S3 bucket creation fails**
   ```bash
   # Check AWS credentials and permissions
   aws sts get-caller-identity

   # Use custom bucket prefix to avoid conflicts
   export S3_BUCKET_PREFIX="yourcompany-mapt"
   ```

6. **S3 bucket left after failed cluster creation**
   ```bash
   # This is NORMAL and EXPECTED behavior!
   # The S3 bucket contains Pulumi state files needed for cleanup

   # First, try to destroy the cluster (even if creation failed)
   export CLUSTER_NAME="your-failed-cluster-name"
   ./create_mapt_cluster.sh --delete

   # Only delete S3 bucket AFTER cluster destruction succeeds
   # The script will do this automatically, or you can do it manually:
   aws s3 rb s3://your-bucket-name --force
   ```

**Finding Available OpenShift Versions**: To find available OpenShift versions with patch numbers, you can:
- Check using the AWS clie the AMI available for your account with the name openshift-local:
```bash
aws ec2 describe-images --filters "Name=name,Values=openshift-local-*" --query 'Images[*].[Name]' --output text | sort -V
openshift-local-4.19.0-arm64
openshift-local-4.19.0-x86_64
openshift-local-4.20.0-x86_64-d3cd1dd
```
Note: The openshift local team regularly updates these AMIs with the latest patches. It can be more available images that are not being copied to the shared account.

### Debug Mode

Use verbose mode and dry-run for debugging:

```bash
./create_mapt_cluster.sh --dry-run --verbose
```

This will show:
- Complete configuration
- Commands that would be executed
- Environment detection results
- File paths and permissions

### Manual Cleanup

If the script fails to clean up resources:

```bash
# Remove containers
podman rm -f mapt-create-* mapt-destroy-*

# Remove S3 bucket (if created)
aws s3 rb s3://your-bucket-name --force

# Remove local state files
rm -f kubeconfig *.log
```

## Security Considerations

### Credential Security
- AWS credentials are passed securely via environment variables
- Credentials are automatically cleared from memory on script exit
- No credentials are logged in any log files
- Log files are created with restricted permissions

### Network Security
- Clusters are created with default AWS security groups

### Resource Cleanup
- Automatic cleanup on script exit (success or failure)
- **S3 buckets are preserved until cluster is successfully destroyed** (critical for cleanup)
- Container cleanup prevents resource leaks
- Failed operations trigger cleanup procedures
- **Important**: S3 buckets contain Pulumi state files needed for cluster destruction

## More Information
