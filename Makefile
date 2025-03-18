.PHONY: deploy install cleanup start yarn migrate format test coverage versions standalone-tests

ROOT_DIR:=$(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
SHELL := /bin/bash

evn e:
	export ERL_AFLAGS="-kernel shell_history enabled"

install i:
	mix deps.get
	cd assets && yarn install

deploy d:
	mix assets.build && mix assets.deploy

cleanup c:
	-pkill -SIGTERM -f 'tailwind'

yarn y:
	cd assets && yarn

start server s:
	make cleanup
	source .env && MIX_ENV=dev iex -S mix phx.server

migrate m:
	MIX_ENV=dev mix ash.migrate

format f:
	mix format

test t:
	mix test

coverage cover co:
	mix test --cover

unit-tests ut:
	@echo "Running unit tests..."
	@find test/unit -name "*.exs" -exec elixir {} \;
	@echo "All unit tests completed."

versions v:
	@echo "Tool Versions"
	@cat .tool-versions
	@cat Aptfile
	@echo

