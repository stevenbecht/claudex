# Makefile for managing the claudex Docker container

IMAGE_NAME = claudex-env
REMOTE_IMAGE_NAME = x
DOCKERFILE = Dockerfile

.PHONY: all build clean rebuild push help

all: build

# Build the Docker image
build:
	docker build --no-cache -t $(IMAGE_NAME) -f $(DOCKERFILE) .

# Remove local image
clean:
	docker rmi -f $(IMAGE_NAME) || true

# Force rebuild
rebuild: clean build

# (Optional) Push to registry (fill in as needed)
push:
	docker push $(IMAGE_NAME)

help:
	@echo "claudex container management"
	@echo "make            - Build the image"
	@echo "make build      - Build the image"
	@echo "make rebuild    - Rebuild the image from scratch"
	@echo "make clean      - Remove the image"
	@echo "make push       - Push image to registry (customize this)"

