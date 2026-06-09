# Configuring Mutual TLS (mTLS) in OpenShift Service Mesh

This guide walks through enabling strict mutual TLS (mTLS) authentication between services in the OpenShift Service Mesh. mTLS ensures that both the client and server present valid certificates before communication is allowed.

## Prerequisites

- OpenShift Service Mesh control plane running in `istio-system`
- Application namespace (e.g., `my-app`) enrolled in the `ServiceMeshMemberRoll`
- `oc` CLI configured with cluster-admin or mesh-admin privileges

## Enable Strict mTLS Mesh-Wide

### 1. Apply a Mesh-Wide PeerAuthentication Policy

Set the default mTLS mode to `STRICT` across the entire mesh. This prevents any unencrypted traffic between mesh-enrolled services.

<!-- TEST-TIMEOUT: 60s -->

```bash
cat <<EOF | oc apply -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT
EOF
```

Expected output:

```
peerauthentication.security.istio.io/default created
```

### 2. Verify the PeerAuthentication Policy is Active

Confirm the policy has been created and is visible in the `istio-system` namespace:

```bash
oc get peerauthentication default -n istio-system -o jsonpath='{.spec.mtls.mode}'
```

Expected output:

```
STRICT
```

## Configure DestinationRule for mTLS

### 3. Create a Mesh-Wide DestinationRule Requiring mTLS

Apply a `DestinationRule` that instructs all sidecar proxies to use `ISTIO_MUTUAL` when connecting to any host within the mesh:

```bash
cat <<EOF | oc apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: default
  namespace: istio-system
spec:
  host: "*.local"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
EOF
```

Expected output:

```
destinationrule.networking.istio.io/default created
```

## Verify mTLS Certificate Issuance

### 4. Inspect Sidecar Certificate via istioctl

<!-- TEST-TIMEOUT: 120s -->

Use `istioctl` to confirm that the Envoy sidecar in the application pod has been issued a valid SPIFFE certificate from Istiod:

```bash
istioctl proxy-config secret \
  $(oc get pod -n my-app -l app=my-service -o jsonpath='{.items[0].metadata.name}') \
  -n my-app
```

Expected output (excerpt):

```
RESOURCE NAME   TYPE           STATUS    VALID CERT   SERIAL NUMBER   NOT AFTER                NOT BEFORE
default         Cert Chain     ACTIVE    true          ...             2024-12-31T00:00:00Z     2024-01-01T00:00:00Z
ROOTCA          CA             ACTIVE    true          ...             2034-01-01T00:00:00Z     2024-01-01T00:00:00Z
```

The `VALID CERT` column must show `true` for both the `default` certificate chain and the `ROOTCA`.

### 5. Validate mTLS Enforcement with a Test Request

<!-- TEST-RETRY: 3 -->

Send a request from a pod without a sidecar proxy to confirm that non-mTLS connections are rejected. First, launch a debug pod without injection:

```bash
oc run mtls-test --image=curlimages/curl:8.1.0 \
  -n my-app \
  --restart=Never \
  --annotations=sidecar.istio.io/inject="false" \
  -- sleep 3600
```

Then attempt to reach the service directly:

```bash
oc exec mtls-test -n my-app -- \
  curl -s -o /dev/null -w "%{http_code}" http://my-service.my-app.svc.cluster.local:8080/health
```

Expected output: `000` or a connection reset error, confirming that the unencrypted connection was rejected by the Envoy proxy.

Clean up the test pod:

```bash
oc delete pod mtls-test -n my-app
```

## Namespace-Scoped mTLS Override

### 6. Apply a Namespace-Level PeerAuthentication Policy

To allow a specific namespace to use `PERMISSIVE` mode (accepting both mTLS and plain text) while the mesh default is `STRICT`, apply a namespace-scoped policy:

```bash
cat <<EOF | oc apply -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: namespace-permissive
  namespace: legacy-app
spec:
  mtls:
    mode: PERMISSIVE
EOF
```

Expected output:

```
peerauthentication.security.istio.io/namespace-permissive created
```

### 7. Confirm the Namespace Policy Takes Precedence

<!-- TEST-RETRY: 3 -->

Verify that a non-injected pod can still reach a service in `legacy-app` after the namespace-level override:

```bash
oc exec mtls-test -n legacy-app -- \
  curl -s -o /dev/null -w "%{http_code}" http://legacy-service.legacy-app.svc.cluster.local:8080/health
```

Expected output: `200`

## Troubleshooting

If mTLS validation fails, check whether the namespace is enrolled in the `ServiceMeshMemberRoll`:

```bash
oc get smmr default -n istio-system -o jsonpath='{.status.members}'
```

Verify that sidecar injection is enabled for the namespace:

```bash
oc get namespace my-app --show-labels | grep istio-injection
```

Examine Envoy proxy logs for TLS handshake errors:

```bash
oc logs -n my-app -l app=my-service -c istio-proxy | grep -i "tls\|handshake\|certificate"
```
