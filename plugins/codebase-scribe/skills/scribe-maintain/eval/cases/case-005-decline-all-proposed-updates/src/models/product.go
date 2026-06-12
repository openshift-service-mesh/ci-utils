package models

// Product represents a catalog product.
type Product struct {
	ID         string  `json:"id"`
	Name       string  `json:"name"`
	CategoryID string  `json:"category_id"`
	Price      float64 `json:"price"`
	InStock    bool    `json:"in_stock"`
}
