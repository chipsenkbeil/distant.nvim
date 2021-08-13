.PHONY: help test
.EXPORT_ALL_VARIABLES:

# Configuration for our tests
DISTANT_ROOT_DIR?=$(abspath $(dir $(lastword $(MAKEFILE_LIST))))
DISTANT_HOST?=localhost
DISTANT_PORT?=22
DISTANT_IDENTITY_FILE?=
DISTANT_BIN?="${HOME}/.cargo/bin/distant"

help: ## Display help information
	@printf 'usage: make [target] ...\n\ntargets:\n'
	@egrep '^(.+)\:\ .*##\ (.+)' ${MAKEFILE_LIST} | sed 's/:.*##/#/' | column -t -c 2 -s '#'

test: test-unit test-e2e ## Runs all tests in a headless neovim instance

test-unit: vendor ## Runs unit tests in a headless neovim instance
	@nvim \
		--headless \
		--noplugin \
		-u spec/spec.vim \
		-c "PlenaryBustedDirectory spec/unit/ { minimal_init = 'spec/spec.vim' }"

test-e2e: vendor ## Runs e2e tests in a headless neovim instance
	@nvim \
		--headless \
		--noplugin \
		-u spec/spec.vim \
		-c "PlenaryBustedDirectory spec/e2e/ { minimal_init = 'spec/spec.vim' }"

test-docker: ## Runs all tests using a pair of docker containers that have shared SSH keys
	@docker-compose build
	@docker-compose up -d server
	@-docker-compose run client
	@-docker-compose rm -f client
	@-docker-compose stop server
	@-docker-compose rm -f server

# Pulls in all of our dependencies for tests
vendor: vendor/plenary.nvim

# Pulls in the latest version of plenary.nvim, which we use to run our tests
vendor/plenary.nvim:
	git clone https://github.com/nvim-lua/plenary.nvim.git vendor/plenary.nvim || \
		( cd vendor/plenary.nvim && git pull --rebase; )
