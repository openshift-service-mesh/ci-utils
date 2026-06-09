package main

import (
	"log"

	"github.com/gin-gonic/gin"
	"order-service/handlers"
	"order-service/repositories"
	"order-service/services"
)

func main() {
	// Initialize repository layer (database access)
	orderRepo := repositories.NewOrderRepository()
	userRepo := repositories.NewUserRepository()
	inventoryRepo := repositories.NewInventoryRepository()

	// Initialize service layer (business logic)
	orderSvc := services.NewOrderService(orderRepo, inventoryRepo)
	userSvc := services.NewUserService(userRepo)
	notificationSvc := services.NewNotificationService()

	// Initialize handler layer (HTTP)
	orderHandler := handlers.NewOrderHandler(orderSvc)
	userHandler := handlers.NewUserHandler(userSvc)
	adminHandler := handlers.NewAdminHandler(orderSvc, notificationSvc)

	r := gin.Default()

	v1 := r.Group("/api/v1")
	{
		v1.GET("/orders", orderHandler.ListOrders)
		v1.GET("/orders/:id", orderHandler.GetOrder)
		v1.POST("/orders", orderHandler.CreateOrder)
		v1.PUT("/orders/:id/status", orderHandler.UpdateOrderStatus)
		v1.POST("/orders/:id/cancel", orderHandler.CancelOrder)

		v1.GET("/users", userHandler.ListUsers)
		v1.GET("/users/:id", userHandler.GetUser)
		v1.POST("/users", userHandler.CreateUser)

		admin := v1.Group("/admin")
		{
			admin.GET("/orders/pending", adminHandler.ListPendingOrders)
			admin.POST("/orders/:id/fulfill", adminHandler.FulfillOrder)
			admin.POST("/notifications/broadcast", adminHandler.BroadcastNotification)
		}
	}

	if err := r.Run(":8080"); err != nil {
		log.Fatalf("failed to start server: %v", err)
	}
}
