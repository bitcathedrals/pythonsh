Dockerfile.python: docker-python.org
	../scripts/org-compile.sh docker-python.org Dockerfile.python

Dockerfile: Dockerfile.python
	./replace-version.sh ../python.sh

build-python:  Dockerfile
	docker buildx build --platform=linux/amd64,linux/arm64 -t gaugesecurity/python:${DOCKER_VERSION} .
