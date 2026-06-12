package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/example/catalogservice/models"
)

// CategoryHandler handles HTTP requests for product category resources.
type CategoryHandler struct{}

// NewCategoryHandler creates a new CategoryHandler.
func NewCategoryHandler() *CategoryHandler {
	return &CategoryHandler{}
}

// List returns all categories.
func (h *CategoryHandler) List(c *gin.Context) {
	categories := []models.Category{}
	c.JSON(http.StatusOK, categories)
}

// Create adds a new category.
func (h *CategoryHandler) Create(c *gin.Context) {
	var category models.Category
	if err := c.ShouldBindJSON(&category); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, category)
}
