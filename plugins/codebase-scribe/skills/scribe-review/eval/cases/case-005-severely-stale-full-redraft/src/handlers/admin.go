package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"order-service/services"
)

// AdminHandler handles privileged administrative operations.
// It delegates to OrderService and NotificationService.
type AdminHandler struct {
	orderSvc        *services.OrderService
	notificationSvc *services.NotificationService
}

// NewAdminHandler creates a new AdminHandler.
func NewAdminHandler(orderSvc *services.OrderService, notificationSvc *services.NotificationService) *AdminHandler {
	return &AdminHandler{orderSvc: orderSvc, notificationSvc: notificationSvc}
}

// ListPendingOrders returns all orders awaiting fulfillment.
// GET /api/v1/admin/orders/pending
func (h *AdminHandler) ListPendingOrders(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"orders": []interface{}{}})
}

// FulfillOrder marks an order as fulfilled and triggers shipment.
// POST /api/v1/admin/orders/:id/fulfill
func (h *AdminHandler) FulfillOrder(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"fulfilled": true})
}

// BroadcastNotification sends a notification to all users.
// POST /api/v1/admin/notifications/broadcast
func (h *AdminHandler) BroadcastNotification(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"sent": true})
}
