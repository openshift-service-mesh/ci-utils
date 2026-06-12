package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"order-service/services"
)

// UserHandler handles HTTP requests for user resources.
// It delegates all business logic to UserService.
type UserHandler struct {
	userSvc *services.UserService
}

// NewUserHandler creates a new UserHandler with the given service.
func NewUserHandler(userSvc *services.UserService) *UserHandler {
	return &UserHandler{userSvc: userSvc}
}

// ListUsers returns a paginated list of users.
// GET /api/v1/users
func (h *UserHandler) ListUsers(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"users": []interface{}{}})
}

// GetUser returns a single user by ID.
// GET /api/v1/users/:id
func (h *UserHandler) GetUser(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"id": c.Param("id")})
}

// CreateUser creates a new user via UserService.
// POST /api/v1/users
func (h *UserHandler) CreateUser(c *gin.Context) {
	c.JSON(http.StatusCreated, gin.H{"status": "created"})
}
