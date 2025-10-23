# ci-utils
Shared utilities to standardize and simplify build, test, and deployment pipelines.

## Overview
This repository contains a collection of scripts, configurations, and tools designed to streamline continuous integration (CI) processes across various projects. By utilizing these shared utilities, teams can ensure consistency, reduce duplication of effort, and accelerate development workflows.

## Tools Available

### Report Portal Integration
**Location**: `report_portal/`

Generic tool for sending JUnit XML test results to any Report Portal instance via Data Router. Supports both local development and CI/CD environments with secure credential handling.

[View Documentation](report_portal/README.md)

### MAPT Cluster Management
**Location**: `mapt_cluster/`

Standardized tool for creating and managing OpenShift clusters using MAPT across different environments. Automatically detects local vs CI environments and handles S3 bucket management.

[View Documentation](mapt_cluster/README.md)

## Getting Started

1. Clone the repository and navigate to the desired tool directory
2. Make the script executable: `chmod +x script_name.sh`
3. Configure required environment variables (see individual tool documentation)
4. Test with `--dry-run --verbose` to verify configuration
5. Run the tool according to its documentation

## Security Considerations

All tools in this repository follow security best practices:

- **No credential logging**: Sensitive information is never logged and appears as `[REDACTED]`
- **Automatic cleanup**: Credentials and temporary resources are cleaned up automatically
- **Secure environment variables**: Preferred over file-based credential storage
- **Error handling**: Proper cleanup occurs even when operations fail
- **Restricted file permissions**: Log files and sensitive data have appropriate permissions

## Contributing

When adding new tools or improving existing ones:

1. **Follow the established patterns**: Look at existing tools for structure and security practices
2. **Include comprehensive documentation**: README with examples, security notes, and troubleshooting
3. **Add help functionality**: `--help` flag with usage examples
4. **Implement dry-run mode**: `--dry-run` for testing without executing operations
5. **Security first**: Never log credentials, implement automatic cleanup
6. **Test in multiple environments**: Verify local and CI environment compatibility

## Support

For issues, questions, or contributions:

1. Check the individual tool's README for specific guidance
2. Look at the troubleshooting sections in each tool's documentation
3. Open an issue in this repository with:
   - Tool name and version
   - Environment details (local/CI platform)
   - Error logs (with credentials redacted)
   - Steps to reproduce