.PHONY: help test docker-test
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

docker-test: docker-cleanup docker-build docker-standup ## Runs all tests using a pair of docker containers that have shared SSH keys
	make docker-test-internal; STATUS=$$?; make docker-cleanup; exit $$STATUS

docker-build:
	@docker build . --file Dockerfile --tag $(DOCKER_IMAGE)

docker-cleanup: docker-test-server-remove docker-network-remove

docker-standup: docker-network-create docker-test-server

docker-network-create:
	@docker network create $(DOCKER_NETWORK)

docker-network-remove:
	@-docker network rm $(DOCKER_NETWORK)

docker-test-server:
	@docker run \
		--rm \
		--name $(DOCKER_SERVER) \
		-d \
		--network=$(DOCKER_NETWORK) \
		$(DOCKER_IMAGE) sudo /usr/sbin/sshd -D -e

docker-test-server-remove:
	@-docker rm -f $(DOCKER_SERVER)

docker-test-internal: 
	@docker run \
		--rm \
		--name $(DOCKER_CLIENT) \
		--network=$(DOCKER_NETWORK) \
		-e DISTANT_HOST=$(DOCKER_SERVER) \
		-e DISTANT_PORT=22 \
		-e DISTANT_BIN=/usr/local/bin/distant \
		$(DOCKER_IMAGE) sh -c "cd app && make test"

test: test-unit test-e2e ## Runs all tests in a headless neovim instance on the local machine

test-unit: vendor ## Runs unit tests in a headless neovim instance on the local machine
	@nvim \
		--headless \
		--noplugin \
		-u spec/spec.vim \
		-c "PlenaryBustedDirectory spec/unit/ { minimal_init = 'spec/spec.vim' }"

test-e2e: vendor ## Runs e2e tests in a headless neovim instance on the local machine
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
