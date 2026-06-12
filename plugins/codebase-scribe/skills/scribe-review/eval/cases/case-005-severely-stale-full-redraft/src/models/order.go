package models

import "time"

// OrderStatus represents the lifecycle state of an order.
type OrderStatus string

const (
	OrderStatusPending   OrderStatus = "pending"
	OrderStatusFulfilled OrderStatus = "fulfilled"
	OrderStatusCancelled OrderStatus = "cancelled"
	OrderStatusShipped   OrderStatus = "shipped"
)

// OrderItem is a line item within an order.
type OrderItem struct {
	ProductID string `json:"product_id" db:"product_id"`
	Quantity  int    `json:"quantity" db:"quantity"`
	UnitPrice int64  `json:"unit_price_cents" db:"unit_price_cents"`
}

// Order represents a customer order.
type Order struct {
	ID         string      `json:"id" db:"id"`
	UserID     string      `json:"user_id" db:"user_id"`
	Items      []OrderItem `json:"items"`
	Status     OrderStatus `json:"status" db:"status"`
	TotalCents int64       `json:"total_cents" db:"total_cents"`
	CreatedAt  time.Time   `json:"created_at" db:"created_at"`
	UpdatedAt  time.Time   `json:"updated_at" db:"updated_at"`
}
