.PHONY: shellcheck lint test-unit test-integration test

# Run shellcheck on all bash files
shellcheck:
	shellcheck bin/ckad-drill lib/*.sh

# Alias for shellcheck
lint: shellcheck

# Run unit tests (no cluster required)
test-unit:
	bats test/unit/

# Run integration tests (requires running kind cluster)
test-integration:
	bats test/integration/

# Run all tests
test: test-unit test-integration
