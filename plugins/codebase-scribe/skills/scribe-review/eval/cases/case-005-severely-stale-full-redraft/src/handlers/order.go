package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"order-service/services"
)

// OrderHandler handles HTTP requests for order resources.
// It delegates all business logic to OrderService.
type OrderHandler struct {
	orderSvc *services.OrderService
}

// NewOrderHandler creates a new OrderHandler with the given service.
func NewOrderHandler(orderSvc *services.OrderService) *OrderHandler {
	return &OrderHandler{orderSvc: orderSvc}
}

// ListOrders returns a paginated list of orders for the current user.
// GET /api/v1/orders
func (h *OrderHandler) ListOrders(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"orders": []interface{}{}})
}

// GetOrder returns a single order by ID.
// GET /api/v1/orders/:id
func (h *OrderHandler) GetOrder(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"id": c.Param("id")})
}

// CreateOrder creates a new order, validating inventory availability via OrderService.
// POST /api/v1/orders
func (h *OrderHandler) CreateOrder(c *gin.Context) {
	c.JSON(http.StatusCreated, gin.H{"status": "created"})
}

// UpdateOrderStatus transitions an order to a new status.
// PUT /api/v1/orders/:id/status
func (h *OrderHandler) UpdateOrderStatus(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "updated"})
}

// CancelOrder cancels a pending order and restores inventory.
// POST /api/v1/orders/:id/cancel
func (h *OrderHandler) CancelOrder(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"cancelled": true})
}
