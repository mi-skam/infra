#!/usr/bin/env bash
#
# Terraform Syntax Validation Test
#
# Validates that Terraform configuration files are syntactically correct
# using 'tofu validate'. This test does not require API access or backend
# initialization.
#
# Exit codes:
#   0 - Syntax is valid
#   1 - Syntax validation failed
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
  print_header "Terraform Syntax Validation"

  # Get terraform directory (parent of tests/)
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  TERRAFORM_DIR="$(dirname "${SCRIPT_DIR}")"

  log_info "Terraform directory: ${TERRAFORM_DIR}"

  # Validate prerequisites
  if ! command -v tofu &> /dev/null; then
    log_error "OpenTofu (tofu) is not installed or not in PATH"
    log_error "Install tofu: https://opentofu.org/docs/intro/install/"
    exit 2
  fi

  # Change to terraform directory
  cd "${TERRAFORM_DIR}"

  # Initialize terraform (required for validate)
  # Use -backend=false to avoid needing backend configuration
  log_info "Initializing Terraform (without backend)..."
  if ! tofu init -backend=false &> /dev/null; then
    log_error "Failed to initialize Terraform"
    log_error "This may indicate missing provider configuration or module issues"
    exit 2
  fi

  # Run syntax validation
  log_info "Running syntax validation..."

  if tofu validate; then
    log_success "Syntax validation passed"
    log_success "All Terraform configuration files are syntactically correct"
    exit 0
  else
    log_error "Syntax validation failed"
    log_error "Fix the syntax errors shown above and re-run the test"
    exit 1
  fi
}

# Execute main function
main "$@"
