.PHONY: build test lint migrate clean

build:
	go build -o bin/order-service ./...

test:
	go test ./... -v -race -coverprofile=coverage.out

lint:
	golangci-lint run ./...

# migrate applies pending database schema migrations
migrate:
	go run ./cmd/migrate/main.go

clean:
	rm -rf bin/ coverage.out
