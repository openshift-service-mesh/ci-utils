package main

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/example/orderservice/handlers"
)

func main() {
	r := gin.Default()

	orderHandler := handlers.NewOrderHandler()

	r.GET("/orders", orderHandler.List)
	r.GET("/orders/:id", orderHandler.Get)
	r.POST("/orders", orderHandler.Create)
	r.PUT("/orders/:id/status", orderHandler.UpdateStatus)

	log.Println("Starting order service on :8080")
	if err := http.ListenAndServe(":8080", r); err != nil {
		log.Fatal(err)
	}
}
