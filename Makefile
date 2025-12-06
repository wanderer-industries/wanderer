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
	MIX_ENV=test mix test

# Run tests in 4 parallel partitions (useful for CI or faster local runs)
test-parallel tp:
	@echo "Running tests in 4 parallel partitions..."
	@mkdir -p /tmp/wanderer_test_results
	@rm -f /tmp/wanderer_test_results/partition_*.txt /tmp/wanderer_test_results/exit_*.txt
	@for i in 1 2 3 4; do \
		(MIX_TEST_PARTITION=$$i MIX_ENV=test mix test --partitions 4 2>&1; echo $$? > /tmp/wanderer_test_results/exit_$$i.txt) | \
		tee /tmp/wanderer_test_results/partition_$$i.txt | sed "s/^/[P$$i] /" & \
	done; \
	wait
	@echo ""
	@echo "========================================"
	@echo "        TEST RESULTS SUMMARY"
	@echo "========================================"
	@total_tests=0; total_failures=0; total_excluded=0; all_passed=true; \
	for i in 1 2 3 4; do \
		exit_code=$$(cat /tmp/wanderer_test_results/exit_$$i.txt 2>/dev/null || echo "1"); \
		if [ "$$exit_code" != "0" ]; then all_passed=false; fi; \
		summary=$$(grep -E "^[0-9]+ (tests?|doctest)" /tmp/wanderer_test_results/partition_$$i.txt | tail -1 || echo "No results"); \
		tests=$$(echo "$$summary" | grep -oE "^[0-9]+" || echo "0"); \
		failures=$$(echo "$$summary" | grep -oE "[0-9]+ failures?" | grep -oE "^[0-9]+" || echo "0"); \
		excluded=$$(echo "$$summary" | grep -oE "[0-9]+ excluded" | grep -oE "^[0-9]+" || echo "0"); \
		total_tests=$$((total_tests + tests)); \
		total_failures=$$((total_failures + failures)); \
		total_excluded=$$((total_excluded + excluded)); \
		if [ "$$exit_code" = "0" ]; then \
			echo "Partition $$i: ✓ $$summary"; \
		else \
			echo "Partition $$i: ✗ $$summary (exit code: $$exit_code)"; \
		fi; \
	done; \
	echo "========================================"; \
	echo "TOTAL: $$total_tests tests, $$total_failures failures, $$total_excluded excluded"; \
	echo "========================================"; \
	if [ "$$all_passed" = "true" ]; then \
		echo "✓ All partitions passed!"; \
	else \
		echo "✗ Some partitions failed. Details below:"; \
		echo ""; \
		for i in 1 2 3 4; do \
			exit_code=$$(cat /tmp/wanderer_test_results/exit_$$i.txt 2>/dev/null || echo "1"); \
			if [ "$$exit_code" != "0" ]; then \
				echo "======== PARTITION $$i FAILURES ========"; \
				grep -A 50 "Failures:" /tmp/wanderer_test_results/partition_$$i.txt 2>/dev/null || cat /tmp/wanderer_test_results/partition_$$i.txt; \
				echo ""; \
			fi; \
		done; \
		exit 1; \
	fi

coverage cover co:
	MIX_ENV=test mix test --cover

unit-tests ut:
	@echo "Running unit tests..."
	@find test/unit -name "*.exs" -exec elixir {} \;
	@echo "All unit tests completed."

versions v:
	@echo "Tool Versions"
	@cat .tool-versions
	@cat Aptfile
	@echo
