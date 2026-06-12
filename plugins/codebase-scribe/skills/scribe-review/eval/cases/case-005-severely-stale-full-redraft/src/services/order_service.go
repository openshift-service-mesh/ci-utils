package services

import (
	"fmt"

	"order-service/models"
	"order-service/repositories"
)

// OrderService implements business logic for order management.
// It coordinates between OrderRepository and InventoryRepository.
type OrderService struct {
	orderRepo     *repositories.OrderRepository
	inventoryRepo *repositories.InventoryRepository
}

// NewOrderService creates a new OrderService.
func NewOrderService(orderRepo *repositories.OrderRepository, inventoryRepo *repositories.InventoryRepository) *OrderService {
	return &OrderService{orderRepo: orderRepo, inventoryRepo: inventoryRepo}
}

// CreateOrder validates inventory availability, creates the order, and reserves stock.
func (s *OrderService) CreateOrder(order *models.Order) error {
	// Check inventory availability for all items
	for _, item := range order.Items {
		available, err := s.inventoryRepo.CheckAvailability(item.ProductID, item.Quantity)
		if err != nil {
			return fmt.Errorf("inventory check failed: %w", err)
		}
		if !available {
			return fmt.Errorf("insufficient stock for product %s", item.ProductID)
		}
	}

	// Persist the order
	if err := s.orderRepo.Create(order); err != nil {
		return fmt.Errorf("failed to create order: %w", err)
	}

	// Reserve inventory
	for _, item := range order.Items {
		if err := s.inventoryRepo.Reserve(item.ProductID, item.Quantity); err != nil {
			return fmt.Errorf("failed to reserve inventory: %w", err)
		}
	}

	return nil
}

// CancelOrder cancels a pending order and releases reserved inventory.
func (s *OrderService) CancelOrder(orderID string) error {
	order, err := s.orderRepo.GetByID(orderID)
	if err != nil {
		return fmt.Errorf("order not found: %w", err)
	}

	if order.Status != models.OrderStatusPending {
		return fmt.Errorf("cannot cancel order in status %s", order.Status)
	}

	// Release reserved inventory
	for _, item := range order.Items {
		if err := s.inventoryRepo.Release(item.ProductID, item.Quantity); err != nil {
			return fmt.Errorf("failed to release inventory: %w", err)
		}
	}

	return s.orderRepo.UpdateStatus(orderID, models.OrderStatusCancelled)
}

// ListPendingOrders returns all orders in PENDING status.
func (s *OrderService) ListPendingOrders() ([]*models.Order, error) {
	return s.orderRepo.ListByStatus(models.OrderStatusPending)
}
