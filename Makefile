.PHONY: help test test-unit test-e2e test-arg docker-test docker-test-unit docker-test-e2e docker-test-arg
.EXPORT_ALL_VARIABLES:

# Configuration for our tests
DISTANT_ROOT_DIR?=$(abspath $(dir $(lastword $(MAKEFILE_LIST))))
DISTANT_HOST?=localhost
DISTANT_PORT?=22
DISTANT_IDENTITY_FILE?=
DISTANT_BIN?="$(HOME)/.cargo/bin/distant"

DOCKER_IMAGE=distant_nvim_test
DOCKER_NETWORK=distant_nvim_network
DOCKER_CLIENT=client
DOCKER_SERVER=server
DOCKER_OUT_DIR=/tmp
DOCKER_OUT_ARCHIVE=$(DOCKER_OUT_DIR)/distant_nvim_images.tar

COMMA:=,

# Function docker_exec runs tests within a docker container
# 
# Args:
#	1: The command to run inside the container such as `make test`
define docker_exec
@docker rm -f $(DOCKER_SERVER) > /dev/null 2>&1 || true
@docker network rm $(DOCKER_NETWORK) > /dev/null 2>&1 || true
@docker build . --file Dockerfile --tag $(DOCKER_IMAGE) --cache-from=$(DOCKER_IMAGE)
@docker network create $(DOCKER_NETWORK)
@docker run \
	--rm \
	--name $(DOCKER_SERVER) \
	-d \
	--network=$(DOCKER_NETWORK) \
	$(DOCKER_IMAGE) sudo /usr/sbin/sshd -D -e
@docker run \
	--rm \
	--name $(DOCKER_CLIENT) \
	--network=$(DOCKER_NETWORK) \
	-e DISTANT_HOST=$(DOCKER_SERVER) \
	-e DISTANT_PORT=22 \
	-e DISTANT_BIN=/usr/local/bin/distant \
	$(DOCKER_IMAGE) sh -c "cd app && $(1)"; \
	STATUS=$$?; \
	docker rm -f $(DOCKER_SERVER) > /dev/null 2>&1; \
	docker network rm $(DOCKER_NETWORK) > /dev/null 2>&1; \
	exit $$STATUS
endef

# Function test_exec runs tests using neovim
#
# Args:
#	1: The path within the spec directory such as e2e/fn/copy_spec.lua to run a
#	   specific test or e2e/ to run all e2e tests
#	2: Optional configuration to pass to PlenaryBustedDirectory such as `sequential = true`
define test_exec
@nvim \
	--headless \
	--noplugin \
	-u spec/spec.vim \
	-c "PlenaryBustedDirectory spec/$(1) { minimal_init = 'spec/spec.vim' $(if 2,$(COMMA)$(2)) }"
endef

###############################################################################
# HELP TARGET
###############################################################################

help: ## Display help information
	@printf 'usage: make [target] ...\n\ntargets:\n'
	@egrep '^(.+)\:\ .*##\ (.+)' $(MAKEFILE_LIST) | sed 's/:.*##/#/' | column -t -c 2 -s '#'

###############################################################################
# LOCAL TEST TARGETS
###############################################################################

test: test-unit test-e2e ## Runs all tests in a headless neovim instance on the local machine

test-arg: vendor ## Runs all tests for the given custom path (ARG) inside spec/ in a headless neovim instance on the local machine
	$(call test_exec,$(ARG))

test-unit: vendor ## Runs unit tests in a headless neovim instance on the local machine
	$(call test_exec,unit/)

test-e2e: vendor ## Runs e2e tests in a headless neovim instance on the local machine
	$(call test_exec,e2e/,sequential = true)

# Pulls in all of our dependencies for tests
vendor: vendor/plenary.nvim

# Pulls in the latest version of plenary.nvim, which we use to run our tests
vendor/plenary.nvim:
	git clone https://github.com/nvim-lua/plenary.nvim.git vendor/plenary.nvim || \
		( cd vendor/plenary.nvim && git pull --rebase; )

###############################################################################
# DOCKER TEST TARGETS
###############################################################################

docker-test: ## Runs all tests using a pair of docker containers that have shared SSH keys
	$(call docker_exec,make test)

docker-test-arg: ## Runs all tests for a custom path (ARG) inside spec/ using a pair of docker containers that have shared SSH keys
	$(call docker_exec,make test-arg ARG=$(ARG))

docker-test-unit: ## Runs all unit tests using a pair of docker containers that have shared SSH keys
	$(call docker_exec,make test-unit)

docker-test-e2e: ## Runs all e2e tests using a pair of docker containers that have shared SSH keys
	$(call docker_exec,make test-e2e)

docker-build:
	@docker build . --file Dockerfile --tag $(DOCKER_IMAGE) --cache-from=$(DOCKER_IMAGE)

docker-save:
	@docker save --output $(DOCKER_OUT_ARCHIVE) $(DOCKER_IMAGE):latest

docker-load:
	@docker load --input $(DOCKER_OUT_ARCHIVE)
