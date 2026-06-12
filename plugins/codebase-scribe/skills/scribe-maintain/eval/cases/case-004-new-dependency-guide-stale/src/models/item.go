package models

// Item represents a physical inventory item.
type Item struct {
	ID       string  `json:"id"`
	Name     string  `json:"name"`
	SKU      string  `json:"sku"`
	Quantity int     `json:"quantity"`
	Price    float64 `json:"price"`
}
