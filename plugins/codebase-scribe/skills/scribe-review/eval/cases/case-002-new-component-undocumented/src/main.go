package main

import (
	"log"

	"github.com/gin-gonic/gin"
	"store-service/handlers"
)

func main() {
	r := gin.Default()

	userHandler := handlers.NewUserHandler()
	paymentHandler := handlers.NewPaymentHandler()

	v1 := r.Group("/api/v1")
	{
		// User routes
		v1.GET("/users", userHandler.ListUsers)
		v1.GET("/users/:id", userHandler.GetUser)
		v1.POST("/users", userHandler.CreateUser)
		v1.PUT("/users/:id", userHandler.UpdateUser)
		v1.DELETE("/users/:id", userHandler.DeleteUser)

		// Payment routes
		v1.GET("/payments", paymentHandler.ListPayments)
		v1.GET("/payments/:id", paymentHandler.GetPayment)
		v1.POST("/payments", paymentHandler.CreatePayment)
		v1.POST("/payments/:id/refund", paymentHandler.RefundPayment)
	}

	if err := r.Run(":8080"); err != nil {
		log.Fatalf("failed to start server: %v", err)
	}
}
