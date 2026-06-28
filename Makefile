# Makefile for driving Terraform across environments.
#
# Pick an environment with env=<name>, then run one or more tf-* targets:
#
#   make tf-init tf-plan tf-apply env=do/vpn
#   make tf-apply env=vpn                  # 'vpn' is an alias for do/vpn
#   make tf-destroy env=do/vpn
#   make tf-plan env=do/vpn ARGS="-target=module.vpn"
#   make tf-apply env=do/vpn ARGS="-auto-approve"
#
# 'env' is resolved as: a short alias (see ALIAS_* below) if one matches,
# otherwise a path under environments/. So env=vpn and env=do/vpn both point
# at environments/do/vpn.

TF       ?= terraform
ENVS_DIR := environments
ARGS     ?=

# Accept either env=... or ENV=...
ENV ?= $(env)

# Short aliases: ALIAS_<name> := <path under environments/>
ALIAS_vpn := do/vpn

# Resolve alias first, then fall back to treating ENV as a direct subpath.
ENV_PATH := $(or $(ALIAS_$(ENV)),$(ENV))
ENV_DIR  := $(ENVS_DIR)/$(ENV_PATH)

TF_CHDIR := $(TF) -chdir=$(ENV_DIR)

.DEFAULT_GOAL := help

.PHONY: help list-envs guard-env \
        tf-init tf-plan tf-apply tf-destroy tf-validate tf-output tf-refresh \
        tf-show tf-fmt tf-fmt-check tf-clean

help: ## Show this help
	@echo "Usage: make <target> [env=<name>] [ARGS=\"...\"]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'
	@echo ""
	@echo "Environments (env=<name>):"
	@$(MAKE) --no-print-directory list-envs

list-envs: ## List available environments
	@find $(ENVS_DIR) -name '*.tf' -exec dirname {} \; 2>/dev/null | \
		sort -u | sed 's#^$(ENVS_DIR)/#  #' || true
	@echo "  aliases: vpn -> do/vpn"

# Ensure env is set and points at a real Terraform root.
guard-env:
	@if [ -z "$(ENV)" ]; then \
		echo "error: set env=<name>, e.g. make tf-plan env=vpn"; \
		echo "run 'make list-envs' to see available environments"; \
		exit 1; \
	fi
	@if [ ! -d "$(ENV_DIR)" ]; then \
		echo "error: environment directory not found: $(ENV_DIR)"; \
		echo "run 'make list-envs' to see available environments"; \
		exit 1; \
	fi
	@if ! ls "$(ENV_DIR)"/*.tf >/dev/null 2>&1; then \
		echo "error: $(ENV_DIR) has no Terraform config (placeholder environment?)"; \
		echo "run 'make list-envs' to see usable environments"; \
		exit 1; \
	fi

tf-init: guard-env ## Initialize the selected environment
	$(TF_CHDIR) init $(ARGS)

tf-plan: guard-env ## Show a plan for the selected environment
	$(TF_CHDIR) plan $(ARGS)

tf-apply: guard-env ## Apply changes to the selected environment
	$(TF_CHDIR) apply $(ARGS)

tf-destroy: guard-env ## Destroy the selected environment
	$(TF_CHDIR) destroy $(ARGS)

tf-validate: guard-env ## Validate the selected environment
	$(TF_CHDIR) validate $(ARGS)

tf-output: guard-env ## Show outputs for the selected environment
	$(TF_CHDIR) output $(ARGS)

tf-refresh: guard-env ## Refresh state for the selected environment
	$(TF_CHDIR) refresh $(ARGS)

tf-show: guard-env ## Show current state for the selected environment
	$(TF_CHDIR) show $(ARGS)

tf-clean: guard-env ## Remove .terraform/ and plan files in the selected environment
	rm -rf "$(ENV_DIR)/.terraform" "$(ENV_DIR)"/*.tfplan

tf-fmt: ## Format all Terraform files in the repo
	$(TF) fmt -recursive

tf-fmt-check: ## Check formatting of all Terraform files (CI-friendly)
	$(TF) fmt -recursive -check
