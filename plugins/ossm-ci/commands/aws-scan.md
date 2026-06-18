---
name: aws-scan
description: Guide the user to download and run the audited AWS inventory script.
allowedTools: []
---

# AWS Resources Inventory

Your only job is to give the user the exact commands to download and run the inventory script. You do not execute anything, you do not parse any output.

## Instructions to give the user

Tell the user to run these commands:

```bash
# Download the script
curl -O https://raw.githubusercontent.com/openshift-service-mesh/ci-utils/main/scripts/aws-scan-audited.sh

# Run it
bash aws-scan-audited.sh
```

Optional flags:
```bash
bash aws-scan-audited.sh --regions us-east-1,eu-west-1
bash aws-scan-audited.sh --resources ec2,s3,rds,elb
```

The script outputs two tables directly in the terminal:
- **POTENTIALLY DANGLING RESOURCES** — stopped, unattached, or unassociated resources
- **ALL RESOURCES** — complete inventory

No output needs to be pasted back here. The script is the tool.
