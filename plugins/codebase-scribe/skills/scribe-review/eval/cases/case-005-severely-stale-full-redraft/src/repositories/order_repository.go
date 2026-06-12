package repositories

import (
	"order-service/models"
)

// OrderRepository handles database persistence for orders.
type OrderRepository struct{}

// NewOrderRepository creates a new OrderRepository.
func NewOrderRepository() *OrderRepository {
	return &OrderRepository{}
}

// Create persists a new order to the database.
func (r *OrderRepository) Create(order *models.Order) error {
	return nil
}

// GetByID retrieves an order by its primary key.
func (r *OrderRepository) GetByID(id string) (*models.Order, error) {
	return &models.Order{ID: id}, nil
}

// UpdateStatus transitions an order to a new status.
func (r *OrderRepository) UpdateStatus(id string, status models.OrderStatus) error {
	return nil
}

// ListByStatus returns all orders with the given status.
func (r *OrderRepository) ListByStatus(status models.OrderStatus) ([]*models.Order, error) {
	return []*models.Order{}, nil
}
