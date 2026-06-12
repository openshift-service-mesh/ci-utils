package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/example/user-api/services"
)

// UserHandler handles HTTP requests for user resources.
type UserHandler struct {
	svc services.UserService
}

// NewUserHandler constructs a UserHandler with the given service.
func NewUserHandler(svc services.UserService) *UserHandler {
	return &UserHandler{svc: svc}
}

// GetUser handles GET /users/:id
func (h *UserHandler) GetUser(c *gin.Context) {
	id := c.Param("id")
	user, err := h.svc.GetByID(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
		return
	}
	c.JSON(http.StatusOK, user)
}

// CreateUser handles POST /users
func (h *UserHandler) CreateUser(c *gin.Context) {
	var req services.CreateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	user, err := h.svc.Create(c.Request.Context(), req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create user"})
		return
	}
	c.JSON(http.StatusCreated, user)
}
