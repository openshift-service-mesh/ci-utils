package main

import (
	"log"
	"os"

	"github.com/example/user-api/router"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	r := router.New()
	log.Printf("Starting user-api on :%s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatalf("server error: %v", err)
	}
}
