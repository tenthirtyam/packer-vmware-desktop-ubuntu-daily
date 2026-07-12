# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Ryan Johnson

PACKER_DIR := src
REPO_ROOT  := $(CURDIR)
OUTPUT_DIR := output
ISO_DIR    := iso

.DEFAULT_GOAL := help

.PHONY: help format fmt format-check lint init validate build clean clean-iso rebuild

help: ## List all targets
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make [target]\n\nTargets:\n"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  %-14s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

format: ## Format Packer templates and Prettier-supported files
	packer fmt -write -recursive $(PACKER_DIR)
	prettier --write .

fmt: format ## Alias for format

format-check: ## Check formatting (Packer + Prettier)
	packer fmt -check -recursive $(PACKER_DIR)
	prettier --check .

lint: ## Run shellcheck on the build script
	shellcheck $(PACKER_DIR)/ubuntu-daily.sh

init: ## Initialize Packer plugins
	packer init $(PACKER_DIR)

validate: init ## Validate Packer configuration
	packer validate -var-file=$(PACKER_DIR)/validate.pkrvars.hcl $(PACKER_DIR)

build: ## Build the virtual machine image
	$(PACKER_DIR)/ubuntu-daily.sh $(ARGS)

rebuild: clean build ## Remove output and build from scratch

clean: ## Remove built virtual machine output
	rm -rf $(OUTPUT_DIR)
	mkdir -p $(OUTPUT_DIR)

clean-iso: ## Remove downloaded ISO files
	rm -rf $(ISO_DIR)
	mkdir -p $(ISO_DIR)
