package payments

import "time"

// Payment represents a single payment attempt against the provider.
type Payment struct {
	ID         string
	OrderID    string
	AmountCent int64
	Currency   string
	CreatedAt  time.Time
}
