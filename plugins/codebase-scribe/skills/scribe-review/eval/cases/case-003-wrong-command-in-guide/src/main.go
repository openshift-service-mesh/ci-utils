package main

import (
	"log"

	"github.com/gin-gonic/gin"
	"catalog-service/handlers"
)

func main() {
	r := gin.Default()

	productHandler := handlers.NewProductHandler()

	v1 := r.Group("/api/v1")
	{
		v1.GET("/products", productHandler.ListProducts)
		v1.GET("/products/:id", productHandler.GetProduct)
		v1.POST("/products", productHandler.CreateProduct)
		v1.PUT("/products/:id", productHandler.UpdateProduct)
		v1.DELETE("/products/:id", productHandler.DeleteProduct)
	}

	if err := r.Run(":8080"); err != nil {
		log.Fatalf("failed to start server: %v", err)
	}
}
