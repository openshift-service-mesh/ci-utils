package main

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/example/catalogservice/handlers"
)

func main() {
	r := gin.Default()

	productHandler := handlers.NewProductHandler()
	categoryHandler := handlers.NewCategoryHandler()

	r.GET("/products", productHandler.List)
	r.GET("/products/:id", productHandler.Get)
	r.POST("/products", productHandler.Create)

	r.GET("/categories", categoryHandler.List)
	r.POST("/categories", categoryHandler.Create)

	log.Println("Starting catalog service on :8080")
	if err := http.ListenAndServe(":8080", r); err != nil {
		log.Fatal(err)
	}
}
