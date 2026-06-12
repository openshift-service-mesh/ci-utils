.PHONY: build test lint clean

build:
	go build -o bin/user-service ./...

test:
	go test ./... -v -race

lint:
	golangci-lint run ./...

clean:
	rm -rf bin/
