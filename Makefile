.PHONY: help build test lint format app run clean

APP_NAME := PlumageBar
CONFIG   := release
DIST_DIR := dist

help:
	@echo "Plumage Bar — make targets:"
	@echo "  make build   — build the executable (release config)"
	@echo "  make test    — run the test suite"
	@echo "  make lint    — run swift-format in lint mode"
	@echo "  make format  — run swift-format in write mode"
	@echo "  make app     — assemble $(APP_NAME).app into $(DIST_DIR)/"
	@echo "  make run     — assemble and launch $(APP_NAME).app"
	@echo "  make clean   — remove build artifacts"

build:
	swift build -c $(CONFIG) --arch arm64

test:
	swift test --parallel

lint:
	swift format lint --recursive --strict Sources Tests Package.swift

format:
	swift format --in-place --recursive Sources Tests Package.swift

app: build
	@scripts/make-app.sh $(CONFIG) $(DIST_DIR)

run: app
	open $(DIST_DIR)/$(APP_NAME).app

clean:
	swift package clean
	rm -rf .build $(DIST_DIR)
