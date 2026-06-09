package models

import "time"

// PaymentStatus represents the current state of a payment transaction.
type PaymentStatus string

const (
	PaymentStatusPending   PaymentStatus = "pending"
	PaymentStatusSucceeded PaymentStatus = "succeeded"
	PaymentStatusFailed    PaymentStatus = "failed"
	PaymentStatusRefunded  PaymentStatus = "refunded"
)

// Payment represents a payment transaction in the store.
type Payment struct {
	ID             string        `json:"id" db:"id"`
	UserID         string        `json:"user_id" db:"user_id"`
	AmountCents    int64         `json:"amount_cents" db:"amount_cents"`
	Currency       string        `json:"currency" db:"currency"`
	Status         PaymentStatus `json:"status" db:"status"`
	StripeChargeID string        `json:"stripe_charge_id" db:"stripe_charge_id"`
	CreatedAt      time.Time     `json:"created_at" db:"created_at"`
	RefundedAt     *time.Time    `json:"refunded_at,omitempty" db:"refunded_at"`
}
