# Improved API Testing Scripts

This directory now uses a single, consolidated test suite for validating the Map System and Connection API functionality in the Wanderer application.

## Main Test Suite

### improved_api_tests.sh

**Purpose**: Comprehensive, modular, and DRY tests for all system and connection API endpoints.

**Usage**:
```bash
./improved_api_tests.sh           # Run with interactive menu
./improved_api_tests.sh create    # Run only creation tests
./improved_api_tests.sh update    # Run only update tests
./improved_api_tests.sh delete    # Run only deletion tests
./improved_api_tests.sh -v        # Run with verbose output
```

- All test logic (create, update, delete, list, etc.) is present in this script.
- The script supports both interactive and non-interactive use.
- State is managed between runs using /tmp/wanderer_test_systems.txt and /tmp/wanderer_test_connections.txt.

## Running All Tests

To run all manual API tests:
```bash
./improved_api_tests.sh
```

## Cleanup

All tests include proper cleanup procedures to ensure test data doesn't accumulate in the database. Cleanup happens:
- At the end of a full test run
- When manually running deletion tests
- On script exit via a trap handler (when running interactively)

## Requirements

- bash
- curl
- jq
- bc (for trigonometric functions in system positioning)

## Legacy Scripts

The previous modular scripts (1_create_systems.sh, 2_create_connections.sh, 3_update_systems.sh, 4_delete_everything.sh, run_manual_tests.sh) have been removed. All their logic is now covered by improved_api_tests.sh. 