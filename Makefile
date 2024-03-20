# Get current branch by default
tag := $(shell git rev-parse --abbrev-ref HEAD)

build:
	docker build -t ghcr.io/byrn-baker/nautobot-kubernetes:$(tag) .

push:
	docker push ghcr.io/byrn-baker/nautobot-kubernetes:$(tag)

pull:
	docker pull ghcr.io/byrn-baker/nautobot-kubernetes:$(tag)

lint:
	@echo "Linting..."
	@sleep 1
	@echo "Done."

test:
	@echo "Testing..."
	@sleep 1
	@echo "Done."

update-tag:
	sed -i 's/tag: \".*\"/tag: \"$(tag)\"/g' $(values)