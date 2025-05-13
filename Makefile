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
  dev-up           - run development environment without Grafana and Prometheus
  dev-down         - stop dev-up
  prod-up          - run project in production mode in docker-compose, see docs/prod.md
  prod-down        - as is

endef
export USAGE

define SETUP_HELP

This command will set up Combobox on the local machine. It requires sudo privileges to create required user and group.
See ./scripts/setup-ser.sh for details.

What it will do:
    - install dependencies and tools (linter)
    - create a local user for CMan (container manager)
    - create local directories for temporary and cache files
    - build CMan images

Press Enter to continue, Ctrl+C to quit
endef
export SETUP_HELP

define CAKE
   \e[1;31m. . .\e[0m
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
	./scripts/setup-user.sh
	./scripts/build-images.sh now

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

develop-up: 
	docker compose -f docker-compose.dev.yaml up -d

develop-down:
	docker compose -f docker-compose.dev.yaml down

dev-up:
	docker compose -f docker-compose.dev.short.yaml up -d

dev-down:
	docker compose -f docker-compose.dev.short.yaml down

prod-up: docker-build
	docker compose -f docker-compose.prod.yaml up -d

prod-down:
	docker compose -f docker-compose.prod.yaml down

cake:
	OSTYPE=$$(uname); [ "$$OSTYPE" = "Darwin" ] && CAKE=$$(printf '%b' "$$CAKE" | sed 's/\\e/\\x1B/g'); echo "$$CAKE"

.PHONY: all build run lint test docker-build docker develop-up develop-down prod-up prod-down cake update-deps

$(V).SILENT:
