package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/example/userservice/models"
)

// UserHandler handles HTTP requests for user resources.
type UserHandler struct{}

// NewUserHandler creates a new UserHandler.
func NewUserHandler() *UserHandler {
	return &UserHandler{}
}

// List returns all users.
func (h *UserHandler) List(c *gin.Context) {
	users := []models.User{}
	c.JSON(http.StatusOK, users)
}

// Get returns a single user by ID.
func (h *UserHandler) Get(c *gin.Context) {
	id := c.Param("id")
	user := models.User{ID: id}
	c.JSON(http.StatusOK, user)
}

// Create creates a new user.
func (h *UserHandler) Create(c *gin.Context) {
	var user models.User
	if err := c.ShouldBindJSON(&user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, user)
}
