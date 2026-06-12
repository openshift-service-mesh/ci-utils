# Traffic Management: Circuit Breakers, Retries, and Timeouts

This guide covers advanced traffic management policies in OpenShift Service Mesh, including circuit breaking, automatic retries, and request timeouts. These policies are configured through `DestinationRule` and `VirtualService` resources.

## Prerequisites

- OpenShift Service Mesh installed with `bookinfo` sample app running
- `reviews`, `ratings`, and `productpage` services deployed in the `bookinfo` namespace

## Circuit Breaker Configuration

Circuit breakers protect services from cascading failures by temporarily stopping traffic to an unhealthy upstream.

### 1. Apply a Circuit Breaker DestinationRule

Configure outlier detection on the `ratings` service. If a host returns five consecutive 5xx errors within 10 seconds, it is ejected from the load-balancing pool for 30 seconds:

```bash
cat <<EOF | oc apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: ratings-circuit-breaker
  namespace: bookinfo
spec:
  host: ratings
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 10
      http:
        http1MaxPendingRequests: 5
        maxRequestsPerConnection: 2
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 10s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
EOF
```

Expected output:

```
destinationrule.networking.istio.io/ratings-circuit-breaker created
```

### 2. Verify the DestinationRule

Confirm the resource was accepted by the mesh control plane:

```bash
oc get destinationrule ratings-circuit-breaker -n bookinfo -o jsonpath='{.spec.trafficPolicy.outlierDetection}'
```

Expected output:

```json
{"baseEjectionTime":"30s","consecutive5xxErrors":5,"interval":"10s","maxEjectionPercent":50}
```

### 3. Trigger the Circuit Breaker

Use the `fortio` load testing tool to simulate concurrent requests that exceed the connection pool limit:

```bash
oc run fortio --image=fortio/fortio:latest -n bookinfo --restart=Never -- \
  load -c 20 -qps 0 -n 50 -loglevel Warning \
  http://ratings.bookinfo.svc.cluster.local:9080/ratings/1
```

Wait for the pod to complete, then check results:

```bash
oc logs fortio -n bookinfo | grep "Code 200\|Code 503"
```

You should observe a mix of `200` and `503` responses, with `503` codes indicating circuit breaker rejections when the connection pool is saturated.

Clean up the load testing pod:

```bash
oc delete pod fortio -n bookinfo
```

## Retry Configuration

### 4. Add Automatic Retries to a VirtualService

Configure the `productpage` VirtualService to automatically retry on `5xx` errors and `retriable-4xx` errors, up to three times with a 2-second per-try timeout:

```bash
cat <<EOF | oc apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: productpage-retries
  namespace: bookinfo
spec:
  hosts:
    - productpage
  http:
    - route:
        - destination:
            host: productpage
            port:
              number: 9080
      retries:
        attempts: 3
        perTryTimeout: 2s
        retryOn: "5xx,retriable-4xx,connect-failure,reset"
EOF
```

Expected output:

```
virtualservice.networking.istio.io/productpage-retries created
```

### 5. Validate Retry Behavior via Proxy Metrics

After generating some traffic, inspect the Envoy proxy stats for the `productpage` pod to confirm retries are being recorded:

```bash
PRODUCTPAGE_POD=$(oc get pod -n bookinfo -l app=productpage -o jsonpath='{.items[0].metadata.name}')
oc exec "$PRODUCTPAGE_POD" -n bookinfo -c istio-proxy -- \
  pilot-agent request GET stats | grep upstream_rq_retry
```

Expected output (example):

```
cluster.outbound|9080||productpage.bookinfo.svc.cluster.local.upstream_rq_retry: 0
cluster.outbound|9080||productpage.bookinfo.svc.cluster.local.upstream_rq_retry_success: 0
```

The counters will increment when upstream failures trigger the retry logic.

## Timeout Configuration

### 6. Set a Request Timeout on the Reviews VirtualService

Apply a 1-second global timeout on requests routed to the `reviews` service. Requests that take longer than 1 second will receive a `504 Gateway Timeout` response:

```bash
cat <<EOF | oc apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews-timeout
  namespace: bookinfo
spec:
  hosts:
    - reviews
  http:
    - route:
        - destination:
            host: reviews
            subset: v2
      timeout: 1s
EOF
```

Expected output:

```
virtualservice.networking.istio.io/reviews-timeout created
```

### 7. Introduce a Delay Fault to Test the Timeout

Inject a 2-second delay into the `ratings` service to simulate slowness and observe the timeout:

```bash
cat <<EOF | oc apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ratings-delay
  namespace: bookinfo
spec:
  hosts:
    - ratings
  http:
    - fault:
        delay:
          percentage:
            value: 100
          fixedDelay: 2s
      route:
        - destination:
            host: ratings
            port:
              number: 9080
EOF
```

Expected output:

```
virtualservice.networking.istio.io/ratings-delay created
```

### 8. Verify the Timeout is Enforced

Send a request to the productpage and confirm that it returns within approximately 1 second with an error message (the `reviews` section will show an error because `ratings` timed out):

```bash
time curl -s http://bookinfo.apps.cluster.example.com/productpage | grep -i "error\|unavailable\|timeout"
```

Expected output: The page loads quickly (within ~1 second) and displays a message such as "Sorry, product reviews are currently unavailable for this book."

### 9. Clean Up Fault Injection

Remove the delay fault injection to restore normal behavior:

```bash
oc delete virtualservice ratings-delay -n bookinfo
```

Expected output:

```
virtualservice.networking.istio.io/ratings-delay deleted
```

Verify that the productpage renders normally again:

```bash
curl -s -o /dev/null -w "%{http_code}" http://bookinfo.apps.cluster.example.com/productpage
```

Expected output: `200`
