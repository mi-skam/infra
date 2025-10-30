#!/usr/bin/env bash
#
# Terraform Test Suite Runner
#
# Executes all Terraform validation tests in sequence and aggregates results.
# Tests include:
# 1. Syntax validation (tofu validate)
# 2. Plan validation (tofu plan with expected resources)
# 3. Import script validation (bash syntax and resource checks)
# 4. Output validation (tofu output structure)
#
# Exit codes:
#   0 - All tests passed
#   1 - One or more tests failed
#   2 - Test execution error

set -euo pipefail

# Logging functions
log_info() {
  echo "[INFO] $*"
}

log_success() {
  echo "[✓] $*"
}

log_error() {
  echo "[ERROR] $*" >&2
}

print_header() {
  echo ""
  echo "═══════════════════════════════════════"
  echo "  $*"
  echo "═══════════════════════════════════════"
}

# Main test execution
main() {
  # Get script directory
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  TESTS_DIR="${SCRIPT_DIR}/tests"

  print_header "Terraform Validation Test Suite"

  # Track test results
  PASSED=0
  FAILED=0
  TOTAL=4

  # Test execution function
  run_test() {
    local test_name="$1"
    local test_script="$2"

    echo ""
    echo "───────────────────────────────────────"
    echo "→ Running: ${test_name}"
    echo "───────────────────────────────────────"

    # Run test and capture exit code (don't fail the script on test failure)
    set +e
    "${test_script}"
    local exit_code=$?
    set -e

    if [ ${exit_code} -eq 0 ]; then
      log_success "${test_name} PASSED"
      PASSED=$((PASSED + 1))
    else
      log_error "${test_name} FAILED"
      FAILED=$((FAILED + 1))
    fi
  }

  # Execute all tests
  run_test "Syntax Validation" "${TESTS_DIR}/validate-syntax.sh"
  run_test "Plan Validation" "${TESTS_DIR}/validate-plan.sh"
  run_test "Import Script Validation" "${TESTS_DIR}/validate-imports.sh"
  run_test "Output Validation" "${TESTS_DIR}/validate-outputs.sh"

  # Print summary
  echo ""
  print_header "Test Suite Summary"
  echo ""
  echo "Total tests:  ${TOTAL}"
  echo "Passed:       ${PASSED}"
  echo "Failed:       ${FAILED}"
  echo ""

  # Return appropriate exit code
  if [ ${FAILED} -eq 0 ]; then
    log_success "ALL TESTS PASSED (${PASSED}/${TOTAL})"
    echo ""
    exit 0
  else
    log_error "TESTS FAILED (${FAILED}/${TOTAL} failed)"
    echo ""
    log_error "Review the error messages above for details"
    exit 1
  fi
}

# Execute main function
main "$@"
