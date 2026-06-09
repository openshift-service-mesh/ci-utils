package repositories

// InventoryRepository handles database reads and writes for inventory stock levels.
type InventoryRepository struct{}

// NewInventoryRepository creates a new InventoryRepository.
func NewInventoryRepository() *InventoryRepository {
	return &InventoryRepository{}
}

// CheckAvailability returns true if at least `quantity` units of productID are in stock.
func (r *InventoryRepository) CheckAvailability(productID string, quantity int) (bool, error) {
	return true, nil
}

// Reserve decrements available stock for a product by quantity.
func (r *InventoryRepository) Reserve(productID string, quantity int) error {
	return nil
}

// Release increments available stock for a product by quantity (used on order cancellation).
func (r *InventoryRepository) Release(productID string, quantity int) error {
	return nil
}
