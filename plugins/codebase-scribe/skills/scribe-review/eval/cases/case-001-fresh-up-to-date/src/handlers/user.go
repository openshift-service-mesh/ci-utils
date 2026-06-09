package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"user-service/models"
)

// UserHandler handles HTTP requests for user resources.
type UserHandler struct {
	db interface{}
}

// NewUserHandler creates a new UserHandler with a database connection.
func NewUserHandler() *UserHandler {
	return &UserHandler{}
}

// ListUsers returns a paginated list of users.
// GET /api/v1/users
func (h *UserHandler) ListUsers(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"users": []models.User{}})
}

// GetUser returns a single user by ID.
// GET /api/v1/users/:id
func (h *UserHandler) GetUser(c *gin.Context) {
	id := c.Param("id")
	c.JSON(http.StatusOK, gin.H{"id": id})
}

// CreateUser creates a new user record.
// POST /api/v1/users
func (h *UserHandler) CreateUser(c *gin.Context) {
	var user models.User
	if err := c.ShouldBindJSON(&user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, user)
}

// UpdateUser updates an existing user record.
// PUT /api/v1/users/:id
func (h *UserHandler) UpdateUser(c *gin.Context) {
	id := c.Param("id")
	var user models.User
	if err := c.ShouldBindJSON(&user); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	user.ID = id
	c.JSON(http.StatusOK, user)
}

// DeleteUser removes a user record.
// DELETE /api/v1/users/:id
func (h *UserHandler) DeleteUser(c *gin.Context) {
	c.JSON(http.StatusNoContent, nil)
}
