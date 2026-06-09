package main

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/example/userservice/handlers"
)

func main() {
	r := gin.Default()

	userHandler := handlers.NewUserHandler()
	paymentHandler := handlers.NewPaymentHandler()

	r.GET("/users", userHandler.List)
	r.GET("/users/:id", userHandler.Get)
	r.POST("/users", userHandler.Create)

	r.GET("/payments", paymentHandler.List)
	r.POST("/payments", paymentHandler.Create)
	r.GET("/payments/:id", paymentHandler.Get)

	log.Println("Starting user service on :8080")
	if err := http.ListenAndServe(":8080", r); err != nil {
		log.Fatal(err)
	}
}
