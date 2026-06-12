# Gateway and VirtualService Configuration

This guide covers configuring Istio Gateways, VirtualServices, and DestinationRules to control ingress traffic and inter-service routing within the OpenShift Service Mesh.

## Prerequisites

- OpenShift Service Mesh control plane deployed in `istio-system`
- Application namespace enrolled in the `ServiceMeshMemberRoll`
- Sample application (e.g., `bookinfo`) deployed

## Configuring an Ingress Gateway

### 1. Deploy the Ingress Gateway Resource

Create an Istio `Gateway` resource that accepts external HTTP and HTTPS traffic on the default ingress gateway:

```bash
cat <<EOF | oc apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: bookinfo-gateway
  namespace: bookinfo
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 80
        name: http
        protocol: HTTP
      hosts:
        - "bookinfo.apps.cluster.example.com"
    - port:
        number: 443
        name: https
        protocol: HTTPS
      tls:
        mode: SIMPLE
        credentialName: bookinfo-tls-secret
      hosts:
        - "bookinfo.apps.cluster.example.com"
EOF
```

Expected output:

```
gateway.networking.istio.io/bookinfo-gateway created
```

### 2. Create a VirtualService for the Productpage

Route external traffic arriving at the gateway to the `productpage` service:

```bash
cat <<EOF | oc apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: bookinfo
  namespace: bookinfo
spec:
  hosts:
    - "bookinfo.apps.cluster.example.com"
  gateways:
    - bookinfo-gateway
  http:
    - match:
        - uri:
            exact: /productpage
        - uri:
            prefix: /static
        - uri:
            exact: /login
        - uri:
            exact: /logout
        - uri:
            prefix: /api/v1/products
      route:
        - destination:
            host: productpage
            port:
              number: 9080
EOF
```

Expected output:

```
virtualservice.networking.istio.io/bookinfo created
```

### 3. Verify Gateway Connectivity

Retrieve the external hostname of the ingress gateway and confirm the route is reachable:

```bash
oc get route istio-ingressgateway -n istio-system -o jsonpath='{.spec.host}'
```

Then curl the productpage endpoint:

```bash
curl -s -o /dev/null -w "%{http_code}" http://bookinfo.apps.cluster.example.com/productpage
```

Expected output: `200`

## Traffic Routing with Weights

### 4. Create DestinationRules for the Reviews Service

Define subsets for the three versions of the `reviews` service so that traffic can be split between them:

```bash
cat <<EOF | oc apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: reviews
  namespace: bookinfo
spec:
  host: reviews
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        h2UpgradePolicy: UPGRADE
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
    - name: v3
      labels:
        version: v3
EOF
```

Expected output:

```
destinationrule.networking.istio.io/reviews created
```

### 5. Apply Weighted Traffic Split

Send 80% of reviews traffic to `v1` and 20% to `v2` for canary testing:

```bash
cat <<EOF | oc apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
  namespace: bookinfo
spec:
  hosts:
    - reviews
  http:
    - route:
        - destination:
            host: reviews
            subset: v1
          weight: 80
        - destination:
            host: reviews
            subset: v2
          weight: 20
EOF
```

Expected output:

```
virtualservice.networking.istio.io/reviews created
```

### 6. Validate the Traffic Split

Send repeated requests and observe the distribution across versions:

```bash
for i in $(seq 1 20); do
  curl -s http://bookinfo.apps.cluster.example.com/productpage | grep -o 'glyphicon-star' | wc -l
done
```

You should observe a mix of `0` (v1, no stars), `4` (v2, black stars), and `6` (v3, red stars) responses, with v1 responses appearing roughly four times more frequently than v2.

## TLS Configuration

### 7. Create a TLS Secret for the Ingress Gateway

Generate a self-signed certificate and store it as an OpenShift secret in the `istio-system` namespace:

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/bookinfo.key \
  -out /tmp/bookinfo.crt \
  -subj "/CN=bookinfo.apps.cluster.example.com"

oc create secret tls bookinfo-tls-secret \
  --cert=/tmp/bookinfo.crt \
  --key=/tmp/bookinfo.key \
  -n istio-system
```

Expected output:

```
secret/bookinfo-tls-secret created
```

### 8. Verify HTTPS Access

Confirm that the HTTPS endpoint responds correctly:

```bash
curl -k -o /dev/null -w "%{http_code}" \
  https://bookinfo.apps.cluster.example.com/productpage
```

Expected output: `200`
