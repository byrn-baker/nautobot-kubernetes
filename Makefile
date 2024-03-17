# Get current branch by default
tag := $(shell git rev-parse --abbrev-ref HEAD)

build:
	docker build -t ghcr.io/byrn-baker/nautobot-kubernetes:$(tag) .

push:
	docker push ghcr.io/byrn-baker/nautobot-kubernetes:$(tag)

pull:
	docker pull ghcr.io/byrn-baker/nautobot-kubernetes:$(tag)