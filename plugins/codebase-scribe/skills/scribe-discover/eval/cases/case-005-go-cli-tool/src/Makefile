BINARY_NAME=codeanalyzer
INSTALL_DIR=$(HOME)/.local/bin
MAIN_PKG=.

.PHONY: build install test clean lint

build:
	go build -ldflags="-s -w" -o bin/$(BINARY_NAME) $(MAIN_PKG)

install: build
	install -Dm755 bin/$(BINARY_NAME) $(INSTALL_DIR)/$(BINARY_NAME)

test:
	go test ./... -v -race

clean:
	rm -rf bin/

lint:
	golangci-lint run ./...

tidy:
	go mod tidy
