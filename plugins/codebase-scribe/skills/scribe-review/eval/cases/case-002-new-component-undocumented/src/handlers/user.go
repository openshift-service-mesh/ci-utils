package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"store-service/models"
)

// UserHandler handles HTTP requests for user resources.
type UserHandler struct{}

// NewUserHandler creates a new UserHandler.
func NewUserHandler() *UserHandler {
	return &UserHandler{}
}

// ListUsers returns a paginated list of users.
func (h *UserHandler) ListUsers(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"users": []models.User{}})
}

// GetUser returns a single user by ID.
func (h *UserHandler) GetUser(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"id": c.Param("id")})
}

// CreateUser creates a new user record.
func (h *UserHandler) CreateUser(c *gin.Context) {
	var user models.User
	if err := c.ShouldBindJSON(&user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, user)
}

// UpdateUser updates an existing user record.
func (h *UserHandler) UpdateUser(c *gin.Context) {
	var user models.User
	if err := c.ShouldBindJSON(&user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, user)
}

// DeleteUser removes a user record.
func (h *UserHandler) DeleteUser(c *gin.Context) {
	c.JSON(http.StatusNoContent, nil)
}
