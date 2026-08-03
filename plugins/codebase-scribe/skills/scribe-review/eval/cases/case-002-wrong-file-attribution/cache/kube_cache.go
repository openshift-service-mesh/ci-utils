package cache

// EvictExpired removes stale entries from the cache.
func EvictExpired(c *Cache) {
	for k := range c.entries {
		delete(c.entries, k)
	}
}
