.PHONY: build test lint clean

build:
	go build -o bin/store-service ./...

test:
	go test ./... -v -race

lint:
	golangci-lint run ./...

clean:
	rm -rf bin/
