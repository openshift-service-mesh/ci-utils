package main

import (
	"log"
	"os"

	"github.com/gin-gonic/gin"

	apiv1 "github.com/example/authservice/api/v1"
	"github.com/example/authservice/auth"
)

func main() {
	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		log.Fatal("JWT_SECRET environment variable is required")
	}

	tokenManager := auth.NewTokenManager([]byte(secret))
	router := gin.Default()

	apiv1.RegisterRoutes(router, tokenManager)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	if err := router.Run(":" + port); err != nil {
		log.Fatalf("server error: %v", err)
	}
}
