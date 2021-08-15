.PHONY: help test
.EXPORT_ALL_VARIABLES:

# Configuration for our tests
DISTANT_ROOT_DIR?=$(abspath $(dir $(lastword $(MAKEFILE_LIST))))
DISTANT_HOST?=localhost
DISTANT_PORT?=22
DISTANT_IDENTITY_FILE?=
DISTANT_BIN?="${HOME}/.cargo/bin/distant"

DOCKER_IMAGE=distant_nvim_test
DOCKER_NETWORK=distant_nvim_network
DOCKER_CLIENT=client
DOCKER_SERVER=server

help: ## Display help information
	@printf 'usage: make [target] ...\n\ntargets:\n'
	@egrep '^(.+)\:\ .*##\ (.+)' ${MAKEFILE_LIST} | sed 's/:.*##/#/' | column -t -c 2 -s '#'

docker: ## Builds test docker image
	@docker build . --file Dockerfile --tag $(DOCKER_IMAGE)

test: docker ## Runs all tests using a pair of docker containers that have shared SSH keys
	@docker network create $(DOCKER_NETWORK)
	@docker run \
		--rm \
		--name $(DOCKER_SERVER) \
		-itd \
		--network=$(DOCKER_NETWORK) \
		$(DOCKER_IMAGE) sudo /usr/sbin/sshd -D -e
	@-docker run \
		--rm \
		--name $(DOCKER_CLIENT) \
		-it \
		--network=$(DOCKER_NETWORK) \
		-e DISTANT_HOST=$(DOCKER_SERVER) \
		-e DISTANT_PORT=22 \
		-e DISTANT_BIN=/usr/local/bin/distant \
		$(DOCKER_IMAGE) sh -c "cd app && make test-local"
	@-docker rm -f $(DOCKER_SERVER)
	@-docker network rm $(DOCKER_NETWORK)

test-local: test-local-unit test-local-e2e ## Runs all tests in a headless neovim instance on the local machine

test-local-unit: vendor ## Runs unit tests in a headless neovim instance on the local machine
	@nvim \
		--headless \
		--noplugin \
		-u spec/spec.vim \
		-c "PlenaryBustedDirectory spec/unit/ { minimal_init = 'spec/spec.vim' }"

test-local-e2e: vendor ## Runs e2e tests in a headless neovim instance on the local machine
	@nvim \
		--headless \
		--noplugin \
		-u spec/spec.vim \
		-c "PlenaryBustedDirectory spec/e2e/ { minimal_init = 'spec/spec.vim' }"

# Pulls in all of our dependencies for tests
vendor: vendor/plenary.nvim

# Pulls in the latest version of plenary.nvim, which we use to run our tests
vendor/plenary.nvim:
	git clone https://github.com/nvim-lua/plenary.nvim.git vendor/plenary.nvim || \
		( cd vendor/plenary.nvim && git pull --rebase; )
