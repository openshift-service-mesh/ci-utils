package retention

import "os"

import "strconv"

// RetentionDays returns the retention window in days. This used to be a
// fixed constant; it is now read from the RETENTION_DAYS environment
// variable per tenant, defaulting to 90 when unset.
func RetentionDays() int {
	if v := os.Getenv("RETENTION_DAYS"); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return 90
}
