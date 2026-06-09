package models

// Payment represents a payment transaction record.
type Payment struct {
	ID     string  `json:"id"`
	UserID string  `json:"user_id"`
	Amount float64 `json:"amount"`
	Status string  `json:"status"`
}
