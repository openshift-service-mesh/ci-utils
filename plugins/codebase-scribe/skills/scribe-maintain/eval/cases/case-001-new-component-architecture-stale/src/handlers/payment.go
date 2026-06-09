package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/example/userservice/models"
)

// PaymentHandler handles HTTP requests for payment resources.
type PaymentHandler struct{}

// NewPaymentHandler creates a new PaymentHandler.
func NewPaymentHandler() *PaymentHandler {
	return &PaymentHandler{}
}

// List returns all payments.
func (h *PaymentHandler) List(c *gin.Context) {
	payments := []models.Payment{}
	c.JSON(http.StatusOK, payments)
}

// Get returns a single payment by ID.
func (h *PaymentHandler) Get(c *gin.Context) {
	id := c.Param("id")
	payment := models.Payment{ID: id}
	c.JSON(http.StatusOK, payment)
}

// Create creates a new payment record.
func (h *PaymentHandler) Create(c *gin.Context) {
	var payment models.Payment
	if err := c.ShouldBindJSON(&payment); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, payment)
}
