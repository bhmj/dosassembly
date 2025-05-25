SHELL := /bin/bash

ifneq (,$(wildcard .env))
    include .env
    export $(shell sed 's/=.*//' .env)
endif

# application binary type for docker image
export DOCKER_GOOS=linux
export DOCKER_GOARCH=amd64

LDFLAGS = -s -w -X main.appVersion=dev-$(shell git rev-parse --short HEAD)-$(shell date +%y-%m-%d)
PROJECT = $(shell basename $(PWD))
BIN = ./bin
BINARY = $(BIN)/$(PROJECT)
MAIN_SRC = ./cmd/$(PROJECT)

define USAGE

Usage: make <target>

some of the <targets> are:

  setup            - Set up the project
  setup-ace        - Set up and update ACE editor

  all              - build + lint + test
  build            - build binaries into $(BIN)/
  lint             - run linters
  test             - run tests
  run              - run project locally ("make develop-up" must be run beforehand)

  update-deps      - update Go dependencies
  docker-build     - build docker image
  develop-up       - run development environment: postgresql + nginx + Prometheus + Grafana in docker-compose
  develop-down     - stop development environment
  prod-up          - run project in production mode in docker-compose, see docs/prod.md
  prod-down        - as is

endef
export USAGE

define SETUP_HELP

This command will set up DOSASM on the local machine. It requires sudo privileges to create required user and group.
See ./scripts/setup-ser.sh for details.

What it will do:
    - install dependencies and tools (linter)
	- install pipx
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
	sudo apt install pipx
	pipx install ng2web

setup-ace:
	./scripts/setup-ace.sh

update-deps:
	go get -u ./... && go mod tidy

all: build lint test

build:
	mkdir -p $(BIN)
	CGO_ENABLED=0 go build -ldflags "$(LDFLAGS)" -trimpath -o $(BINARY) $(MAIN_SRC)

run:
	CGO_ENABLED=0 go run -ldflags "$(LDFLAGS)" -trimpath $(MAIN_SRC) --config-file=config/config.yaml

lint:
	golangci-lint run

test:
	go test ./...	

# application binary type for docker image
export DOCKER_GOOS=linux
export DOCKER_GOARCH=amd64
# Go version to use while building binaries for docker image
export GOLANG_VERSION=1.24
# golang OS tag for building binaries for docker image
export GOLANG_IMAGE=alpine 
# target OS: the image type to run in production. Usually alpine fits OK.
export TARGET_DISTR_TYPE=alpine
# target OS version (codename)
export TARGET_DISTR_VERSION=latest
# a user created inside the container
# files created by those services on mounted volumes will be owned by this user
export DOCKER_USER=$(USER)

define DOCKER_PARAMS
--build-arg USER=$(DOCKER_USER) \
--build-arg GOOS=$(DOCKER_GOOS) \
--build-arg GOARCH=$(DOCKER_GOARCH) \
--build-arg GOLANG_VERSION=$(GOLANG_VERSION) \
--build-arg GOLANG_IMAGE=$(GOLANG_IMAGE) \
--build-arg TARGET_DISTR_TYPE=$(TARGET_DISTR_TYPE) \
--build-arg TARGET_DISTR_VERSION=$(TARGET_DISTR_VERSION) \
--build-arg LDFLAGS="$(LDFLAGS)" \
--file Dockerfile
endef
export DOCKER_PARAMS

ng2web:
	cd www/guides && ng2web -o x86 x86.ng
	cd www/guides && ng2web -o progref progref.ng
	cd www/guides && ng2web -o vgaregs vgaregs.ng

copy_static: ng2web
	if [ ! -d "/var/nginx-proxy" ]; then echo "/var/nginx-proxy/ does not exist"; exit 1; fi
	mkdir -p /var/nginx-proxy/static/$(DOSASM_DOMAIN)
	printf "copying $$(pwd)/www -> /var/nginx-proxy/static/$(DOSASM_DOMAIN)\n"
	find /var/nginx-proxy/static/$(DOSASM_DOMAIN)/ -mindepth 1 -delete
	cp -r $$(pwd)/www/. /var/nginx-proxy/static/$(DOSASM_DOMAIN)/

docker-build:
	@echo docker build --tag dosassembly --target dosasm $(DOCKER_PARAMS) .
	docker build --tag dosassembly --target dosasm $(DOCKER_PARAMS) .

develop-up: export DOSASM_UPSTREAM=host.docker.internal
develop-up: build copy_static
	docker compose -f docker-compose.dev.yaml up -d
	./scripts/install_nginx_config.sh docker-assets/dev/nginx/dosasm.conf dosasm

develop-down:
	docker compose -f docker-compose.dev.yaml down

prod-up: export DOSASM_UPSTREAM=dosasm
prod-up: docker-build copy_static
	docker compose -f docker-compose.prod.yaml up -d
	./scripts/install_nginx_config.sh "docker-assets/prod/nginx/*.*" dosasm

prod-down:
	docker compose -f docker-compose.prod.yaml down

db:
	docker volume create dosassembly_dosasm_db_data
	docker run -d --rm -v dosassembly_dosasm_db_data:/var/lib/postgresql/data -e POSTGRES_PASSWORD=$(DB_PASSWORD) --name dosasm_postgres postgres:14-alpine
	sleep 1
	docker exec dosasm_postgres sh -c 'psql -U postgres -c "create database dosasm_1;"'
	docker stop dosasm_postgres

cake:
	printf "%b\n" "$$CAKE"

.PHONY: all build run lint test docker-build docker develop-up develop-down prod-up prod-down cake update-deps

$(V).SILENT:
