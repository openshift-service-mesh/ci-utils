# Installing Istio Control Plane on OpenShift

This guide describes how to install the Istio control plane on an OpenShift cluster using the OpenShift Service Mesh (OSSM) operator.

## Prerequisites

- OpenShift cluster version 4.10 or later
- Cluster administrator privileges
- `oc` CLI tool installed and configured
- OpenShift Service Mesh operator installed from OperatorHub

## Installation Steps

### 1. Create the `istio-system` Namespace

Create the dedicated namespace for the Istio control plane components:

```bash
oc new-project istio-system
```

Expected output:

```
Now using project "istio-system" on server "https://api.cluster.example.com:6443".
```

### 2. Verify the Service Mesh Operator is Running

Confirm that the OpenShift Service Mesh operator pod is healthy before proceeding:

```bash
oc get pods -n openshift-operators | grep istio
```

Expected output:

```
istio-operator-6d5b8f9c7-xk2pq   1/1   Running   0   5m
```

### 3. Create the `ServiceMeshControlPlane` Custom Resource

Apply the `ServiceMeshControlPlane` (SMCP) resource to deploy the Istio control plane. Save the following manifest as `smcp.yaml`:

```yaml
apiVersion: maistra.io/v2
kind: ServiceMeshControlPlane
metadata:
  name: basic
  namespace: istio-system
spec:
  version: v2.4
  tracing:
    type: Jaeger
    sampling: 10000
  policy:
    type: Istiod
  telemetry:
    type: Istiod
  addons:
    jaeger:
      install:
        storage:
          type: Memory
    kiali:
      enabled: true
    grafana:
      enabled: true
```

Apply the manifest:

```bash
oc apply -f smcp.yaml
```

Expected output:

```
servicemeshcontrolplane.maistra.io/basic created
```

### 4. Wait for the Control Plane to Become Ready

Monitor the control plane installation progress. All components must reach `Ready` status:

```bash
oc wait --for condition=Ready smcp/basic -n istio-system --timeout=300s
```

Expected output:

```
servicemeshcontrolplane.maistra.io/basic condition met
```

You can also watch the pod rollout:

```bash
oc get pods -n istio-system -w
```

All pods should eventually show `Running` status with all containers ready (e.g., `2/2` or `1/1`).

### 5. Create the `ServiceMeshMemberRoll`

Register the application namespaces that will participate in the mesh by creating a `ServiceMeshMemberRoll` (SMMR):

```bash
cat <<EOF | oc apply -f -
apiVersion: maistra.io/v1
kind: ServiceMeshMemberRoll
metadata:
  name: default
  namespace: istio-system
spec:
  members:
    - bookinfo
    - my-application
EOF
```

Expected output:

```
servicemeshmemberroll.maistra.io/default created
```

### 6. Verify the Mesh Member Roll Status

Confirm that the member roll was accepted and all listed namespaces are configured:

```bash
oc get smmr default -n istio-system -o wide
```

Expected output:

```
NAME      READY   STATUS       AGE   MEMBERS
default   2/2     Configured   30s   ["bookinfo","my-application"]
```

### 7. Validate the Installation

Run a final check to ensure all control plane components are healthy:

```bash
oc get smcp basic -n istio-system
```

Expected output:

```
NAME    READY   STATUS            PROFILES      VERSION   AGE
basic   10/10   ComponentsReady   ["default"]   2.4.0     5m
```

## Troubleshooting

If the control plane does not reach `ComponentsReady` status within five minutes, inspect the operator logs:

```bash
oc logs -n openshift-operators -l name=istio-operator --tail=100
```

Check individual pod events for scheduling or image pull issues:

```bash
oc describe pods -n istio-system | grep -A 10 Events
```
