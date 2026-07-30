package payments

import "sync"

// idempotencyCache is an in-process, non-persistent cache of processed
// payment keys. It is intentionally not backed by Redis or another shared
// store — see ProcessPayment for the call site.
type idempotencyCache struct {
	mu   sync.Mutex
	seen map[string]struct{}
}

func newIdempotencyCache() *idempotencyCache {
	return &idempotencyCache{seen: make(map[string]struct{})}
}

func (c *idempotencyCache) SeenBefore(key string) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	_, ok := c.seen[key]
	c.seen[key] = struct{}{}
	return ok
}
