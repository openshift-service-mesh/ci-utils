BINARY_NAME=userservice
MAIN_PKG=.

.PHONY: build test run clean lint

build:
	go build -o bin/$(BINARY_NAME) $(MAIN_PKG)

test:
	go test ./... -v -race -coverprofile=coverage.out

run:
	go run $(MAIN_PKG)

clean:
	rm -rf bin/ coverage.out

lint:
	golangci-lint run ./...

tidy:
	go mod tidy
