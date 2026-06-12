package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// ProductHandler handles HTTP requests for product catalog resources.
type ProductHandler struct{}

// NewProductHandler creates a new ProductHandler.
func NewProductHandler() *ProductHandler {
	return &ProductHandler{}
}

// ListProducts returns a paginated list of products.
func (h *ProductHandler) ListProducts(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"products": []interface{}{}})
}

// GetProduct returns a single product by ID.
func (h *ProductHandler) GetProduct(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"id": c.Param("id")})
}

// CreateProduct adds a new product to the catalog.
func (h *ProductHandler) CreateProduct(c *gin.Context) {
	c.JSON(http.StatusCreated, gin.H{"status": "created"})
}

// UpdateProduct updates an existing product in the catalog.
func (h *ProductHandler) UpdateProduct(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"status": "updated"})
}

// DeleteProduct removes a product from the catalog.
func (h *ProductHandler) DeleteProduct(c *gin.Context) {
	c.JSON(http.StatusNoContent, nil)
}
