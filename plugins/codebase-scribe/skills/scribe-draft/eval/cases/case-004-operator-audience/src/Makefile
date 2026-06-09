IMAGE_NAME ?= platform-gateway
IMAGE_TAG  ?= latest
REGISTRY   ?= registry.example.com

.PHONY: build test run lint docker-build docker-push deploy

build:
	go build -o bin/gateway ./...

test:
	go test -v -race ./...

run:
	go run main.go

lint:
	golangci-lint run ./...

docker-build:
	docker build -t $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) .

docker-push:
	docker push $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)

deploy:
	kubectl apply -f deploy/kubernetes/
	kubectl rollout status deployment/platform-gateway
