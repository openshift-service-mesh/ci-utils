package cache

// NewKubeCache builds the in-memory object cache backed by shared informers.
func NewKubeCache() *Cache {
	return &Cache{}
}

// Cache holds a local mirror of watched object types.
type Cache struct {
	entries map[string]interface{}
}
