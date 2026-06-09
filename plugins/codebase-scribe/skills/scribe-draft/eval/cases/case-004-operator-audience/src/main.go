package main

import (
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/example/platform-gateway/server"
)

func main() {
	srv := server.New(server.Config{
		Port:        os.Getenv("PORT"),
		UpstreamURL: os.Getenv("UPSTREAM_URL"),
		JWKSEndpoint: os.Getenv("JWKS_ENDPOINT"),
	})

	go func() {
		if err := srv.Start(); err != nil {
			log.Fatalf("server failed: %v", err)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down...")
	srv.Shutdown()
}
