package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/example/catalogservice/models"
)

// ProductHandler handles HTTP requests for product resources.
type ProductHandler struct{}

// NewProductHandler creates a new ProductHandler.
func NewProductHandler() *ProductHandler {
	return &ProductHandler{}
}

// List returns all products.
func (h *ProductHandler) List(c *gin.Context) {
	products := []models.Product{}
	c.JSON(http.StatusOK, products)
}

// Get returns a single product by ID.
func (h *ProductHandler) Get(c *gin.Context) {
	id := c.Param("id")
	product := models.Product{ID: id}
	c.JSON(http.StatusOK, product)
}

// Create adds a new product to the catalog.
func (h *ProductHandler) Create(c *gin.Context) {
	var product models.Product
	if err := c.ShouldBindJSON(&product); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, product)
}
