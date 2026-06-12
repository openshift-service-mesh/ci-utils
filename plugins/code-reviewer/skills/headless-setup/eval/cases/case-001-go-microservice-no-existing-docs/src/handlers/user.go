package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"example.com/userservice/models"
)

// UserHandler holds dependencies for user-related HTTP handlers.
type UserHandler struct {
	users map[int]*models.User
	nextID int
}

// NewUserHandler creates a new UserHandler with an in-memory store.
func NewUserHandler() *UserHandler {
	return &UserHandler{
		users:  make(map[int]*models.User),
		nextID: 1,
	}
}

// GetUser handles GET /api/v1/users/:id requests.
func (h *UserHandler) GetUser(c *gin.Context) {
	idStr := c.Param("id")
	id, err := strconv.Atoi(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user id"})
		return
	}

	user, ok := h.users[id]
	if !ok {
		c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
		return
	}

	c.JSON(http.StatusOK, user)
}

// CreateUser handles POST /api/v1/users requests.
func (h *UserHandler) CreateUser(c *gin.Context) {
	var req models.CreateUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if req.Name == "" || req.Email == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "name and email are required"})
		return
	}

	user := &models.User{
		ID:    h.nextID,
		Name:  req.Name,
		Email: req.Email,
	}
	h.users[h.nextID] = user
	h.nextID++

	c.JSON(http.StatusCreated, user)
}
