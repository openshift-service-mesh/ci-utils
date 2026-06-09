package main

import (
	"log"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"

	"example.com/userservice/handlers"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	r := gin.Default()

	userHandler := handlers.NewUserHandler()

	v1 := r.Group("/api/v1")
	{
		v1.GET("/users/:id", userHandler.GetUser)
		v1.POST("/users", userHandler.CreateUser)
	}

	r.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	log.Printf("Starting server on port %s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
