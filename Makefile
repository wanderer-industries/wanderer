.PHONY: deploy install cleanup start yarn migrate format test coverage versions standalone-tests test-performance test-smoke test-comprehensive test-benchmark test-regression

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

# Performance Testing Targets
test-performance tp:
	@echo "🚀 Running performance-optimized tests..."
	@time mix test --seed 0

test-smoke ts:
	@echo "💨 Running smoke tests..."
	@elixir test/scripts/automated_test_runner.exs smoke

test-comprehensive tc:
	@echo "📋 Running comprehensive test suite..."
	@elixir test/scripts/automated_test_runner.exs comprehensive

test-benchmark tb:
	@echo "📊 Running performance benchmarks..."
	@elixir test/scripts/automated_test_runner.exs benchmark

test-regression tr:
	@echo "🔄 Running regression tests..."
	@elixir test/scripts/automated_test_runner.exs regression

test-fast tf:
	@echo "⚡ Running fastest test configuration..."
	@time mix test test/unit --seed 0 --max-cases 12

test-integration-fast tif:
	@echo "⚡ Running optimized integration tests..."
	@time mix test test/integration --seed 0 --max-cases 8

