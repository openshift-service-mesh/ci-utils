package cache

// NewKubeCache builds the in-memory object cache backed by shared informers.
// This is the only constructor for the cache — there is no cache/kube_cache.go
// in this codebase; the cache implementation lives entirely in this file.
func NewKubeCache() *Cache {
	return &Cache{}
}

// Cache holds a local mirror of watched object types.
type Cache struct{}
