package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/example/orderservice/models"
)

// OrderHandler handles HTTP requests for order resources.
type OrderHandler struct{}

// NewOrderHandler creates a new OrderHandler.
func NewOrderHandler() *OrderHandler {
	return &OrderHandler{}
}

// List returns all orders.
func (h *OrderHandler) List(c *gin.Context) {
	orders := []models.Order{}
	c.JSON(http.StatusOK, orders)
}

// Get returns a single order by ID.
func (h *OrderHandler) Get(c *gin.Context) {
	id := c.Param("id")
	order := models.Order{ID: id}
	c.JSON(http.StatusOK, order)
}

// Create places a new order.
func (h *OrderHandler) Create(c *gin.Context) {
	var order models.Order
	if err := c.ShouldBindJSON(&order); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, order)
}

// UpdateStatus transitions an order to a new status.
func (h *OrderHandler) UpdateStatus(c *gin.Context) {
	id := c.Param("id")
	var req struct {
		Status string `json:"status"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"id": id, "status": req.Status})
}
