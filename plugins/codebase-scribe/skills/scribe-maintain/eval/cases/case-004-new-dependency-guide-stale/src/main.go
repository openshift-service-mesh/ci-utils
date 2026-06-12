package main

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus/promhttp"

	"github.com/example/inventoryservice/handlers"
	"github.com/example/inventoryservice/metrics"
)

func main() {
	metrics.Init()

	r := gin.Default()

	inventoryHandler := handlers.NewInventoryHandler()

	r.GET("/items", inventoryHandler.List)
	r.GET("/items/:id", inventoryHandler.Get)
	r.POST("/items", inventoryHandler.Create)

	// Prometheus metrics endpoint
	r.GET("/metrics", gin.WrapH(promhttp.Handler()))

	log.Println("Starting inventory service on :8080")
	if err := http.ListenAndServe(":8080", r); err != nil {
		log.Fatal(err)
	}
}
