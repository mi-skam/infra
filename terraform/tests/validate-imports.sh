#!/usr/bin/env bash
#
# Terraform Import Script Validation Test
#
# Validates the terraform/import.sh script by:
# 1. Checking bash syntax (bash -n)
# 2. Verifying import commands reference correct resource types
#
# Exit codes:
#   0 - Import script validation passed
#   1 - Import script validation failed
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
  print_header "Import Script Validation"

  # Get terraform directory (parent of tests/)
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  TERRAFORM_DIR="$(dirname "${SCRIPT_DIR}")"
  IMPORT_SCRIPT="${TERRAFORM_DIR}/import.sh"

  log_info "Terraform directory: ${TERRAFORM_DIR}"
  log_info "Import script: ${IMPORT_SCRIPT}"

  # Check if import script exists
  if [ ! -f "${IMPORT_SCRIPT}" ]; then
    log_error "Import script not found: ${IMPORT_SCRIPT}"
    exit 2
  fi

  # Validate bash syntax
  log_info "Validating bash syntax..."
  if bash -n "${IMPORT_SCRIPT}"; then
    log_success "Bash syntax is valid"
  else
    log_error "Bash syntax validation failed"
    log_error "Fix syntax errors in ${IMPORT_SCRIPT}"
    exit 1
  fi

  # Verify import commands reference correct resources
  log_info "Validating import commands..."

  FAILED=0

  # Expected import commands
  declare -A EXPECTED_IMPORTS=(
    ["hcloud_network.homelab"]="Network resource"
    ["hcloud_network_subnet.homelab_subnet"]="Network subnet resource"
    ["hcloud_server.mail_prod_nbg"]="Mail server resource"
    ["hcloud_server.syncthing_prod_hel"]="Syncthing server resource"
    ["hcloud_server.test_dev_nbg"]="Test server resource"
  )

  # Check each expected import command
  for resource in "${!EXPECTED_IMPORTS[@]}"; do
    if grep -q "tofu import ${resource}" "${IMPORT_SCRIPT}"; then
      log_success "Found import command: ${resource} (${EXPECTED_IMPORTS[$resource]})"
    else
      log_error "Missing import command: ${resource} (${EXPECTED_IMPORTS[$resource]})"
      FAILED=1
    fi
  done

  # Return result
  if [ ${FAILED} -eq 0 ]; then
    log_success "Import script validation passed"
    log_success "All expected import commands are present"
    exit 0
  else
    log_error "Import script validation failed"
    log_error "Some expected import commands are missing"
    log_error "Review ${IMPORT_SCRIPT} and add missing commands"
    exit 1
  fi
}

# Execute main function
main "$@"
