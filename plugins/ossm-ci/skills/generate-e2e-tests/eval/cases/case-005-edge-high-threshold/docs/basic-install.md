# Basic Service Mesh Installation

This guide explains how to install OpenShift Service Mesh on an OpenShift cluster.

## Prerequisites

- OpenShift 4.10 or later
- Administrator access to the cluster
- Service Mesh operator installed

## Installation

### 1. Create the Control Plane Namespace

Create the namespace where the control plane will be installed:

```bash
oc new-project istio-system
```

### 2. Create the ServiceMeshControlPlane

Apply the control plane resource:

```bash
cat <<EOF | oc apply -f -
apiVersion: maistra.io/v2
kind: ServiceMeshControlPlane
metadata:
  name: basic
  namespace: istio-system
spec:
  version: v2.4
EOF
```

### 3. Wait for the Installation to Complete

Check the status of the control plane:

```bash
oc get smcp -n istio-system
```

Wait until the STATUS column shows `ComponentsReady`. This may take a few minutes.

### 4. Create the Member Roll

Add your application namespaces to the mesh:

```bash
cat <<EOF | oc apply -f -
apiVersion: maistra.io/v1
kind: ServiceMeshMemberRoll
metadata:
  name: default
  namespace: istio-system
spec:
  members:
    - my-app
EOF
```

### 5. Verify the Installation

Check that all components are running:

```bash
oc get pods -n istio-system
```

All pods should be in `Running` state. Then verify the member roll:

```bash
oc get smmr -n istio-system
```

The STATUS column should show `Configured`.

## Summary

You have installed the OpenShift Service Mesh control plane and enrolled your first application namespace. For more advanced configuration such as mTLS policies, traffic management, and observability setup, refer to the advanced configuration guide.
