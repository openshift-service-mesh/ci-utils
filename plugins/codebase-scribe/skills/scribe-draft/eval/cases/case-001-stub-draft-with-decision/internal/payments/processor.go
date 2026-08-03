package payments

import "fmt"

var cache = newIdempotencyCache()

// ProcessPayment validates and submits a payment. Duplicate submissions for
// the same idempotency key are rejected using the in-process idempotencyCache
// rather than a shared store — this service runs as a single instance.
func ProcessPayment(idempotencyKey string, p Payment) error {
	if cache.SeenBefore(idempotencyKey) {
		return fmt.Errorf("payment %s already processed", idempotencyKey)
	}
	return submit(p)
}

func submit(p Payment) error {
	// submission logic omitted for the fixture
	return nil
}
