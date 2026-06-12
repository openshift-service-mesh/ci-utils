package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/example/inventoryservice/models"
)

// InventoryHandler handles HTTP requests for inventory item resources.
type InventoryHandler struct{}

// NewInventoryHandler creates a new InventoryHandler.
func NewInventoryHandler() *InventoryHandler {
	return &InventoryHandler{}
}

// List returns all inventory items.
func (h *InventoryHandler) List(c *gin.Context) {
	items := []models.Item{}
	c.JSON(http.StatusOK, items)
}

// Get returns a single inventory item by ID.
func (h *InventoryHandler) Get(c *gin.Context) {
	id := c.Param("id")
	item := models.Item{ID: id}
	c.JSON(http.StatusOK, item)
}

// Create adds a new inventory item.
func (h *InventoryHandler) Create(c *gin.Context) {
	var item models.Item
	if err := c.ShouldBindJSON(&item); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, item)
}
