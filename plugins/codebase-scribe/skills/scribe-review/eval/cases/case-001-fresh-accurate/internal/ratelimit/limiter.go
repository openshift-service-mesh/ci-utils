package ratelimit

import (
	"sync"
	"time"
)

// Limiter implements a per-key token-bucket rate limiter, entirely
// in-process — there is no shared/distributed bucket.
type Limiter struct {
	mu      sync.Mutex
	buckets map[string]int
	max     int
	ticker  *time.Ticker
}

// NewLimiter builds a Limiter whose buckets hold at most max tokens and
// starts the refill loop that tops them back up every interval.
func NewLimiter(max int, interval time.Duration) *Limiter {
	l := &Limiter{
		buckets: make(map[string]int),
		max:     max,
		ticker:  time.NewTicker(interval),
	}
	go l.refillLoop()
	return l
}

// refillLoop drives refill from the limiter's ticker: every bucket is topped
// back up once per interval for as long as the limiter lives.
func (l *Limiter) refillLoop() {
	for range l.ticker.C {
		l.refill()
	}
}

// Allow checks and decrements the bucket for key, returning false if the
// caller is over the limit.
func (l *Limiter) Allow(key string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.buckets[key] <= 0 {
		return false
	}
	l.buckets[key]--
	return true
}

// refill tops every bucket back up to max. refillLoop calls it once per tick.
func (l *Limiter) refill() {
	l.mu.Lock()
	defer l.mu.Unlock()
	for k := range l.buckets {
		l.buckets[k] = l.max
	}
}
