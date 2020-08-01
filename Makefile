# Copyright 2019 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# TODO(wgrzelak): Invoke targets into the container.

.DEFAULT_GOAL := help

.PHONY: help
help: ## Shows help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: python-test
python-test: ## Runs tests for Python scripts
	@python --version
	@python -m unittest discover -s scripts -p "*_test.py"

.PHONY: vm-lint
vm-lint: ## Runs lint for Chef cookbooks
	@docker pull chef/chefdk
	# cookstyle print version
	@docker run --rm -it --entrypoint cookstyle -v $(PWD)/vm/chef:/chef:ro chef/chefdk --version
	# cookstyle on cookbooks
	@docker run --rm -it --entrypoint cookstyle -v $(PWD)/vm/chef:/chef:ro chef/chefdk /chef/cookbooks
	# cookstyle on tests
	@docker run --rm -it --entrypoint cookstyle -v $(PWD)/vm/tests:/tests:ro chef/chefdk /tests/solutions
	# foodcritic print version
	@docker run --rm -it --entrypoint foodcritic -v $(PWD)/vm/chef:/chef:ro chef/chefdk --version
	# foodcritic on cookbooks
	@docker run --rm -it --entrypoint foodcritic -v $(PWD)/vm/chef:/chef:ro chef/chefdk --cookbook-path=/chef/cookbooks --rule-file=/chef/.foodcritic --epic-fail=any

.PHONY: vm-generate-triggers
vm-generate-triggers: ## Generates and displays GCB triggers for VM
	@python scripts/triggers_vm_generator.py

# Helper to test whether the environment variable is set
# Params:
#   	 1. Variable name(s) to test.
#     	 2. (optional) Error message to print.
# Credit from: https://stackoverflow.com/a/10858332
check_defined = \
	$(strip $(foreach 1,$1, \
		$(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = \
	$(if $(value $1),, \
		$(error Undefined $1$(if $2, ($2))$(if $(value @), \
			required by target `$@`)))

.PHONY: cloud-build-vm
cloud-build-vm: ## Runs cloud build to create target machine image
	@$(call check_defined, GCP_PROJECT_TO_RUN_CLOUD_BUILD, Your GCP project ID)
	@$(call check_defined, PACKER_LOGS_GCS_BUCKET_NAME, Bucket to export Packer logs)
	@$(call check_defined, SERVICE_ACCOUNT_KEY_JSON_GCS, GCS URL to the service account)
	@$(call check_defined, SOLUTION_NAME, VM image to build)
	@gcloud builds submit . \
		--config cloudbuild-vm.yaml \
		--substitutions _LOGS_BUCKET=$$PACKER_LOGS_GCS_BUCKET_NAME,_SERVICE_ACCOUNT_JSON_GCS=$$SERVICE_ACCOUNT_KEY_JSON_GCS,_SOLUTION_NAME=$$SOLUTION_NAME \
		--project $$GCP_PROJECT_TO_RUN_CLOUD_BUILD
