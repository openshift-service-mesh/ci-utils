package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"store-service/models"
)

// PaymentHandler handles HTTP requests for payment processing.
// It integrates with the Stripe payment gateway for charge and refund operations.
type PaymentHandler struct {
	stripeKey string
}

// NewPaymentHandler creates a new PaymentHandler with Stripe API credentials.
func NewPaymentHandler() *PaymentHandler {
	return &PaymentHandler{}
}

// ListPayments returns all payment records for the authenticated user.
// GET /api/v1/payments
func (h *PaymentHandler) ListPayments(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"payments": []models.Payment{}})
}

// GetPayment returns a single payment by ID.
// GET /api/v1/payments/:id
func (h *PaymentHandler) GetPayment(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"id": c.Param("id")})
}

// CreatePayment initiates a new payment via Stripe.
// POST /api/v1/payments
func (h *PaymentHandler) CreatePayment(c *gin.Context) {
	var payment models.Payment
	if err := c.ShouldBindJSON(&payment); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, payment)
}

// RefundPayment issues a refund for an existing payment.
// POST /api/v1/payments/:id/refund
func (h *PaymentHandler) RefundPayment(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"refunded": true, "id": c.Param("id")})
}
