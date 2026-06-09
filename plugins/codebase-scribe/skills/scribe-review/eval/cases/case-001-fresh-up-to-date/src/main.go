package main

import (
	"log"

	"github.com/gin-gonic/gin"
	"user-service/handlers"
)

func main() {
	r := gin.Default()

	userHandler := handlers.NewUserHandler()

	v1 := r.Group("/api/v1")
	{
		v1.GET("/users", userHandler.ListUsers)
		v1.GET("/users/:id", userHandler.GetUser)
		v1.POST("/users", userHandler.CreateUser)
		v1.PUT("/users/:id", userHandler.UpdateUser)
		v1.DELETE("/users/:id", userHandler.DeleteUser)
	}

	if err := r.Run(":8080"); err != nil {
		log.Fatalf("failed to start server: %v", err)
	}
}
