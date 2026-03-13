SHELL := /bin/bash

GO_VERSION=$(shell grep "^go " go.mod | awk '{print $$2}')

# load envs from a file (1st arg) and runs a make target with those vars (2nd arg)
define load_env
	@set -a && . $(1) && set +a && \
	$(MAKE) --no-print-directory $(2)
endef

GIT_SHA=$(shell git rev-parse --short HEAD)
NEW_APP_VERSION=$$(awk -F. '{printf "%d.%d\n",$$1,$$2+1}' version)

LDFLAGS = -s -w -X main.appVersion=dev-$(GIT_SHA)
PROJECT = $(shell basename $(PWD))
BIN = ./bin

REGISTRY := registry.combobox.cc
REGISTRY_USER ?= combobox
IMAGE_STATIC := dosassembly-static
IMAGE_BACKEND := dosassembly-backend
VERSION_FILE := version
NEW_APP_VERSION := $(shell test -f $(VERSION_FILE) && awk -F. '{printf "%d.%d\n",$$1,$$2+1}' $(VERSION_FILE) || echo "0.1")

APP_USER ?= dummy
GOOS ?= linux
GOARCH ?= amd64
GOLANG_VERSION ?= $(GO_VERSION)
GOLANG_IMAGE ?= alpine
TARGET_DISTR_TYPE ?= alpine
TARGET_DISTR_VERSION ?= latest

DOCKER_BUILD_ARGS := \
	--build-arg APP_USER=$(APP_USER) \
	--build-arg GOOS=$(GOOS) \
	--build-arg GOARCH=$(GOARCH) \
	--build-arg GOLANG_VERSION=$(GOLANG_VERSION) \
	--build-arg GOLANG_IMAGE=$(GOLANG_IMAGE) \
	--build-arg TARGET_DISTR_TYPE=$(TARGET_DISTR_TYPE) \
	--build-arg TARGET_DISTR_VERSION=$(TARGET_DISTR_VERSION) \
	--build-arg LDFLAGS='$(LDFLAGS)' \
	--platform $(GOOS)/$(GOARCH)

define USAGE
DOS Assembly project. Check it out at https://dosasm.com

Usage: make <target>

some of the <targets> are:

  setup            - Set up the project
  setup-ace        - Set up and update ACE editor

  all              - build + lint + test
  build            - build binaries into $(BIN)/
  lint             - run linters
  test             - run tests
  run              - run project locally ("make dev-up" must be run beforehand)

  update-deps      - update Go dependencies
  docker-login     - login to registry.combobox.cc
  docker-build     - build docker image
  release          - build and push Docker images for k8s (registry.combobox.cc)
  dev-up           - run development environment: DB + Prometheus + Grafana in docker (main app in IDE).
  dev-down         - stop development environment
  stage-up         - run staging environment: like prod, but locally with self-signed certs.
  stage-down       - stop development environment
  prod-up          - run production: all components in docker, see docs/prod.md.
  prod-down        - stop production

endef
export USAGE

define SETUP_HELP

This command will set up DOSASM on the local machine. It requires sudo privileges to create required user and group.
See ./scripts/setup-ser.sh for details.

What it will do:
    - install dependencies and tools (linter)
	- install ng2web

Press Enter to continue, Ctrl+C to quit
endef
export SETUP_HELP

define CAKE
   \033[1;31m. . .\033[0m
   i i i
  %~%~%~%
  |||||||
-=========-
endef
export CAKE

help:
	@echo "$$USAGE"

setup:
	@echo "$$SETUP_HELP"
	read
	docker volume create dosassembly_dosasm_grafana
	docker volume create dosassembly_dosasm_prometheus
	go install github.com/golangci/golangci-lint@latest
	git clone https://github.com/bhmj/ng2web.git
	echo "You'll have to install ng2web manually in your system; i just don't rememeber how to do it )"

setup-ace:
	./scripts/setup-ace.sh

update-deps:
	go get -u ./... && go mod tidy && go mod vendor

all: build lint test

build:
	mkdir -p $(BIN)
	CGO_ENABLED=0 go build -ldflags "$(LDFLAGS)" -trimpath -o $(BIN)/dosasm ./cmd/

run:
	mkdir -p $(BIN)
	CGO_ENABLED=0 go run -ldflags "$(LDFLAGS)" -trimpath ./cmd/ --config-file=config/config.yaml

lint:
	golangci-lint run

test:
	go test ./...	

ng2web:
	cd www/guides && ng2web -o x86 x86.ng > /dev/null
	cd www/guides && ng2web -o progref progref.ng > /dev/null
	cd www/guides && ng2web -o vgaregs vgaregs.ng > /dev/null
	cd www/guides && ng2web -o ints ints.ng > /dev/null

copy_static: ng2web
	if [ ! -d "/var/nginx-proxy" ]; then echo "/var/nginx-proxy/ does not exist"; exit 1; fi
	mkdir -p /var/nginx-proxy/static/$(DOSASM_DOMAIN)
	printf "copying $$(pwd)/www -> /var/nginx-proxy/static/$(DOSASM_DOMAIN)\n"
	find /var/nginx-proxy/static/$(DOSASM_DOMAIN)/ -mindepth 1 -delete
	cp -r $$(pwd)/www/. /var/nginx-proxy/static/$(DOSASM_DOMAIN)/

pub_guides:
	$(call load_env,.env_stage,publish)

publish_guides:
	cp -r $$(pwd)/www/guides/. /var/nginx-proxy/static/$(DOSASM_DOMAIN)/guides/

pub:
	$(call load_env,.env_stage,publish)
publish:
	cp -f $$(pwd)/www/js/*.js /var/nginx-proxy/static/$(DOSASM_DOMAIN)/js/
	cp -f $$(pwd)/www/styles/*.css /var/nginx-proxy/static/$(DOSASM_DOMAIN)/styles/
	cp -f $$(pwd)/www/templates/index.html /var/nginx-proxy/static/$(DOSASM_DOMAIN)/templates/

docker-login:
	@echo "Logging in to $(REGISTRY)"
	docker login --username "$(REGISTRY_USER)" $(REGISTRY)

docker-build:
	docker build --tag dosassembly --target dosasm $(DOCKER_BUILD_ARGS) .

docker-build-k8s: ng2web
	echo Go version: $(GO_VERSION)
	docker build --tag $(REGISTRY)/$(IMAGE_BACKEND):$(NEW_APP_VERSION) $(DOCKER_BUILD_ARGS) --target dosasm-k8s -f Dockerfile.backend .
	docker build --platform $(GOOS)/$(GOARCH) --tag $(REGISTRY)/$(IMAGE_STATIC):$(NEW_APP_VERSION) -f Dockerfile.static .

release: docker-build-k8s
	echo "Pushing images..."
	docker push $(REGISTRY)/$(IMAGE_BACKEND):$(NEW_APP_VERSION)
	docker push $(REGISTRY)/$(IMAGE_STATIC):$(NEW_APP_VERSION)
	printf "\n\nApplication version released: %s\n" "$(NEW_APP_VERSION)" && echo "$(NEW_APP_VERSION)" > version

dev-up:
	$(call load_env,.env_dev,run-dev-up)

run-dev-up: export DOSASM_UPSTREAM=host.docker.internal
run-dev-up: build # copy_static
	envsubst < docker-assets/dev/prometheus/prometheus.yml.template > docker-assets/dev/prometheus/prometheus.yml
	docker compose -f docker-compose.dev.yaml up -d
	sleep 0.8
	docker exec nginx-proxy cat /app/scripts/install-nginx-config.sh | bash -s -- dosasm docker-assets/stage/nginx/dosasm.conf

dev-down:
	docker compose -f docker-compose.dev.yaml down
	docker exec nginx-proxy cat /app/scripts/remove-nginx-config.sh | bash -s -- dosasm docker-assets/stage/nginx/dosasm.conf

stage-up:
	$(call load_env,.env_stage,run-stage-up)

run-stage-up: export DOSASM_UPSTREAM=dosasm
run-stage-up: docker-build copy_static
	envsubst < docker-assets/stage/prometheus/prometheus.yml.template > docker-assets/stage/prometheus/prometheus.yml
	docker compose -f docker-compose.stage.yaml up -d
	sleep 0.8
	docker exec nginx-proxy cat /app/scripts/install-nginx-config.sh | bash -s -- dosasm docker-assets/stage/nginx/dosasm.conf

stage-down:
	docker compose -f docker-compose.stage.yaml down
	docker exec nginx-proxy cat /app/scripts/remove-nginx-config.sh | bash -s -- dosasm docker-assets/stage/nginx/dosasm.conf

prod-up:
	$(call load_env,.env_prod,run-prod-up)

run-prod-up: export DOSASM_UPSTREAM=dosasm
run-prod-up: docker-build copy_static
	envsubst < docker-assets/prod/prometheus/prometheus.yml.template > docker-assets/prod/prometheus/prometheus.yml
	docker compose -f docker-compose.prod.yaml up -d
	sleep 1
	docker exec nginx-proxy cat /app/scripts/install-nginx-config.sh | bash -s -- dosasm "docker-assets/prod/nginx/*.*"

prod-down:
	docker compose -f docker-compose.prod.yaml down
	docker exec nginx-proxy cat /app/scripts/remove-nginx-config.sh | bash -s -- dosasm "docker-assets/prod/nginx/*.*"

db:
	docker volume create dosassembly_dosasm_db_data
	docker run -d --rm -v dosassembly_dosasm_db_data:/var/lib/postgresql/data -e POSTGRES_PASSWORD=$(DB_PASSWORD) --name dosasm_postgres postgres:14-alpine
	sleep 1
	docker exec dosasm_postgres sh -c 'psql -U postgres -c "create database dosasm_1;"'
	docker stop dosasm_postgres

cake:
	printf "%b\n" "$$CAKE"

.PHONY: help all build run lint test setup setup-ace docker-build docker-build-k8s docker-login release dev-up dev-down stage-up stage-down prod-up prod-down cake update-deps db

$(V).SILENT:
