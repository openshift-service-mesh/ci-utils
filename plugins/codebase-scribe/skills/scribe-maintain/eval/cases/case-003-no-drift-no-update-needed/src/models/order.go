package models

// Order represents a customer order.
type Order struct {
	ID     string  `json:"id"`
	UserID string  `json:"user_id"`
	Total  float64 `json:"total"`
	Status string  `json:"status"`
}
