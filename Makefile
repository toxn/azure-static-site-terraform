SHELL := /bin/bash
.DEFAULT_GOAL := help

TF        := terraform
INFRA     := infra
BOOTSTRAP := bootstrap

# State coordinates are read from the bootstrap stack so nothing has to be
# copy/pasted. Override any of them: make plan STATE_KEY=staging.tfstate
STATE_RG        ?= $(shell $(TF) -chdir=$(BOOTSTRAP) output -raw state_resource_group_name 2>/dev/null)
STATE_SA        ?= $(shell $(TF) -chdir=$(BOOTSTRAP) output -raw state_storage_account_name 2>/dev/null)
STATE_CONTAINER ?= $(shell $(TF) -chdir=$(BOOTSTRAP) output -raw state_container_name 2>/dev/null)
STATE_KEY       ?= app.tfstate

BACKEND_CONFIG := \
	-backend-config="resource_group_name=$(STATE_RG)" \
	-backend-config="storage_account_name=$(STATE_SA)" \
	-backend-config="container_name=$(STATE_CONTAINER)" \
	-backend-config="key=$(STATE_KEY)"

.PHONY: help bootstrap init fmt validate plan apply destroy output site-url check clean

help: ## Show this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

bootstrap: ## One-time: create remote state + GitHub OIDC identity
	@test -f $(BOOTSTRAP)/terraform.tfvars || { echo "Create $(BOOTSTRAP)/terraform.tfvars first (see terraform.tfvars.example)"; exit 1; }
	$(TF) -chdir=$(BOOTSTRAP) init -input=false
	$(TF) -chdir=$(BOOTSTRAP) apply -input=false
	@echo
	@echo "Next: run the commands printed by 'terraform -chdir=$(BOOTSTRAP) output github_variable_commands'"

init: ## Initialise the infra stack against the remote backend
	$(TF) -chdir=$(INFRA) init -input=false $(BACKEND_CONFIG)

fmt: ## Format all Terraform code
	$(TF) fmt -recursive

check: ## Format check + validate (what CI runs first)
	$(TF) fmt -check -recursive -diff
	$(TF) -chdir=$(INFRA) validate
	$(TF) -chdir=$(BOOTSTRAP) validate

validate: check ## Alias for check

plan: init ## Show the plan
	$(TF) -chdir=$(INFRA) plan -input=false -lock-timeout=5m -out=tfplan

apply: ## Apply the saved plan
	$(TF) -chdir=$(INFRA) apply -input=false tfplan

destroy: ## Destroy the app (state and bootstrap resources are kept)
	$(TF) -chdir=$(INFRA) destroy -input=false -lock-timeout=5m

output: ## Print the stack outputs
	$(TF) -chdir=$(INFRA) output

site-url: ## Print the live site URL
	@$(TF) -chdir=$(INFRA) output -raw site_url && echo

clean: ## Remove local Terraform caches (keeps lock files)
	rm -rf $(INFRA)/.terraform $(BOOTSTRAP)/.terraform
	rm -f $(INFRA)/tfplan $(INFRA)/plan.txt
