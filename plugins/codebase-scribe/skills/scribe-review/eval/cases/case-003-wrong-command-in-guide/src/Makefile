.PHONY: build test docker-build deploy clean

build:
	go build -o bin/catalog-service ./...

test:
	go test ./... -v -race

# docker-build replaces the old 'run' target.
# Use 'make docker-build && make deploy' to run locally via Docker.
docker-build:
	docker build -t catalog-service:local .

deploy:
	docker run -p 8080:8080 \
		-e DATABASE_URL=$(DATABASE_URL) \
		catalog-service:local

clean:
	rm -rf bin/
	docker rmi catalog-service:local 2>/dev/null || true
