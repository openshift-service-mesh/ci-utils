# Report Portal Results Sender

A generic tool for sending JUnit XML test results to any Report Portal instance via Data Router. This tool can be used across different repositories and CI environments.

## Prerequisites

- `jq` - JSON processor for handling metadata
- `droute` - Data Router command-line tool
- Access to Data Router credentials

## Installation

1. Copy the script to your desired location
2. Make it executable: `chmod +x send_report_portal_results.sh`
3. Ensure `jq` and `droute` are available in your PATH

## Usage

### Basic Usage

```bash
# Set required environment variables
export REPORT_PORTAL_HOSTNAME="reportportal.example.com"
export REPORT_PORTAL_PROJECT="my_project"
# With this minimal setup, the script will use default values for other parameters

# Run the script
./send_report_portal_results.sh
```

### Advanced Usage

```bash
# Set all environment variables
export REPORT_PORTAL_HOSTNAME="reportportal.example.com"
export REPORT_PORTAL_PROJECT="my_project"
export TESTRUN_NAME="Integration Tests"
export TESTRUN_DESCRIPTION="Full integration test suite"
export TEST_FILE_NAME="integration-results.xml"
export PRODUCT_VERSION="v2.1.0"
export TEST_SUITE="integration-tests"
export TEST_STAGE="staging"
# Add any extra attributes as a JSON array, this will be added as key/value pairs in Report Portal launch
export EXTRA_ATTRIBUTES='[{"key": "environment", "value": "staging"}, {"key": "browser", "value": "chrome"}]'

# Run with verbose output
./send_report_portal_results.sh --verbose
```

### Dry Run

Test the configuration without actually sending data:

```bash
export REPORT_PORTAL_HOSTNAME="reportportal.example.com"
export REPORT_PORTAL_PROJECT="my_project"
./send_report_portal_results.sh --dry-run --verbose
```

## Environment Variables

### Required

| Variable | Description | Example |
|----------|-------------|---------|
| `REPORT_PORTAL_HOSTNAME` | Report Portal hostname | `reportportal.example.com` |
| `REPORT_PORTAL_PROJECT` | Report Portal project name | `my_project` |

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `TESTRUN_NAME` | `"Test Run"` | Name of the test run |
| `TESTRUN_DESCRIPTION` | `"Automated test run"` | Description of the test run |
| `ARTIFACT_DIR` | `"/tmp/artifacts"` | Directory containing test artifacts |
| `TEST_FILE_NAME` | `"junit.xml"` | Name of the JUnit XML test result file |
| `PRODUCT_VERSION` | `"unknown"` | Version of the product being tested |
| `TEST_SUITE` | `"automated-tests"` | Name of the test suite |
| `TEST_REPO` | Current git repo or `"unknown"` | Repository being tested |
| `INSTALLATION_METHOD` | `"unknown"` | Method used for installation or deploy for OSSM. For example: sail-operator, OSSM OLM, Kiali, Istio upstream, Istio converter |
| `TEST_STAGE` | `"ci"` | Testing stage (e.g., ci, staging, production) |
| `DATA_ROUTER_URL` | `"https://datarouter.ccitredhat.com"` | Data Router URL |
| `DATA_ROUTER_USERNAME` | `""` | Data Router username (alternative to file-based credentials) |
| `DATA_ROUTER_PASSWORD` | `""` | Data Router password/token (alternative to file-based credentials) |
| `EXTRA_ATTRIBUTES` | `""` | JSON array of additional key/value pairs |

### Extra Attributes Format

The `EXTRA_ATTRIBUTES` variable should contain a JSON array of objects with `key` and `value` properties:

```bash
export EXTRA_ATTRIBUTES='[
  {"key": "environment", "value": "staging"},
  {"key": "browser", "value": "chrome"},
  {"key": "region", "value": "us-east-1"}
]'
```

## Credentials

The script supports two methods for providing Data Router credentials:

### Method 1: Environment Variables (Recommended)

Set the credentials as environment variables:

```bash
export DATA_ROUTER_USERNAME="your_username"
export DATA_ROUTER_PASSWORD="your_token"
```

This method is more secure and flexible, especially for local development and CI environments that support secure environment variable management.

### Method 2: File-based Credentials

The script can also read credentials from files (fallback method):

- `/creds-data-router/username` - Data Router username
- `/creds-data-router/token` - Data Router password/token

These files are typically mounted via secrets configuration in CI environments. For local testing, you would need to create these files manually, but be aware that having credentials in plain text files may have security implications.

**Note**: The script tries environment variables first, and only falls back to files if the environment variables are not set.

### Security Considerations

**Important Security Notes:**

1. **Command Line Visibility**: Please be aware that command line arguments (including credentials) may be visible in process lists (`ps aux`). The script does its best to minimize exposure but use appropriate security measures in your environment.

2. **Credential Cleanup**: The script automatically clears credentials from memory after use and sets up traps to clean up on script exit.

3. **Logging Safety**: Credentials are never logged in plain text - they appear as `[REDACTED]` in all log output including dry-run mode.

4. **Environment Variables**: Use secure methods to set environment variables in CI/CD systems:
   - GitLab CI: Use CI/CD variables with "Masked" and "Protected" flags
   - GitHub Actions: Use repository secrets (`${{ secrets.VARIABLE_NAME }}`)
   - Jenkins: Use credentials binding or secret text
   - Local development: Consider using tools like `direnv` or `.env` files (not committed to git)

5. **File Permissions**: If using file-based credentials, ensure proper file permissions (600 or 400) to prevent unauthorized access.

## Command Line Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help message and exit |
| `-v, --verbose` | Enable verbose output |
| `--dry-run` | Show what would be sent without actually sending |

## Examples

### CI Pipeline Usage

```yaml
# GitLab CI example with environment variable credentials
report_to_portal:
  stage: report
  script:
    - export REPORT_PORTAL_HOSTNAME="reportportal.company.com"
    - export REPORT_PORTAL_PROJECT="my-product"
    - export TESTRUN_NAME="Pipeline ${CI_PIPELINE_ID}"
    - export PRODUCT_VERSION="${CI_COMMIT_TAG:-${CI_COMMIT_SHORT_SHA}}"
    - export TEST_STAGE="ci"
    - export DATA_ROUTER_USERNAME="${DATA_ROUTER_USER}"  # From CI variables
    - export DATA_ROUTER_PASSWORD="${DATA_ROUTER_TOKEN}"  # From CI variables
    - ./report_portal/send_report_portal_results.sh --verbose
  artifacts:
    when: always
    paths:
      - artifacts/
```

### GitHub Actions Usage

```yaml
- name: Send results to Report Portal
  env:
    REPORT_PORTAL_HOSTNAME: reportportal.company.com
    REPORT_PORTAL_PROJECT: my-product
    TESTRUN_NAME: "GitHub Action Run ${{ github.run_number }}"
    PRODUCT_VERSION: ${{ github.ref_name }}
    TEST_STAGE: ci
    DATA_ROUTER_USERNAME: ${{ secrets.DATA_ROUTER_USERNAME }}
    DATA_ROUTER_PASSWORD: ${{ secrets.DATA_ROUTER_PASSWORD }}
  run: |
    ./report_portal/send_report_portal_results.sh --verbose
```

### Local Development

```bash
# For local testing with custom test results and environment variable credentials
export REPORT_PORTAL_HOSTNAME="reportportal.example.com"
export REPORT_PORTAL_PROJECT="my_project"
export ARTIFACT_DIR="./test-results"
export TEST_FILE_NAME="my-tests.xml"
export TESTRUN_NAME="Local Development Test"
export PRODUCT_VERSION="dev"
export TEST_STAGE="local"
export DATA_ROUTER_USERNAME="your_username"
export DATA_ROUTER_PASSWORD="your_token"

# Use dry-run for testing configuration
./send_report_portal_results.sh --dry-run --verbose
```

## Troubleshooting

### Common Issues

1. **Missing jq**: Install jq using your package manager
   ```bash
   # Ubuntu/Debian
   sudo apt-get install jq

   # macOS
   brew install jq
   ```

2. **Missing droute**: Ensure droute is installed and available in PATH

3. **File not found**: Check that the test results file exists and the path is correct

4. **Credential errors**: Verify that credential files exist and are readable

5. **JSON format errors**: Validate `EXTRA_ATTRIBUTES` JSON format using `jq`

### Debug Mode

Use verbose mode and dry-run for debugging:

```bash
./send_report_portal_results.sh --dry-run --verbose
```

This will show the complete configuration and metadata that would be sent without actually sending it.