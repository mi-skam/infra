#!/usr/bin/env bash
#
# Terraform Output Validation Test
#
# Validates that Terraform outputs are correctly defined by checking:
# 1. tofu output -json can execute successfully
# 2. Required outputs exist: network_id, network_ip_range, servers, ansible_inventory
#
# Exit codes:
#   0 - Output validation passed
#   1 - Output validation failed
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
  print_header "Terraform Output Validation"

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

  if ! command -v jq &> /dev/null; then
    log_error "jq is not installed or not in PATH"
    log_error "Install jq: https://stedolan.github.io/jq/download/"
    exit 2
  fi

  # Change to terraform directory
  cd "${TERRAFORM_DIR}"

  # Check if state file exists (outputs require state)
  if [ ! -f "terraform.tfstate" ]; then
    log_info "No state file found - validating output definitions only"
    
    # Initialize terraform
    log_info "Initializing Terraform (without backend)..."
    if ! tofu init -backend=false &> /dev/null; then
      log_error "Failed to initialize Terraform"
      exit 2
    fi
    
    # Validate that outputs are defined in configuration
    log_info "Checking output definitions in configuration files..."
    
    FAILED=0
    
    # Check if outputs.tf exists
    if [ ! -f "outputs.tf" ]; then
      log_error "outputs.tf file not found"
      exit 2
    fi
    
    # Expected outputs
    declare -a EXPECTED_OUTPUTS=(
      "network_id"
      "network_ip_range"
      "servers"
      "ansible_inventory"
    )
    
    # Check each expected output in outputs.tf
    for output in "${EXPECTED_OUTPUTS[@]}"; do
      if grep -q "^output \"${output}\"" outputs.tf; then
        log_success "Found output definition: ${output}"
      else
        log_error "Missing output definition: ${output}"
        FAILED=1
      fi
    done
    
    # Return result
    if [ ${FAILED} -eq 0 ]; then
      log_success "Output validation passed"
      log_success "All expected outputs are defined in outputs.tf"
      log_info "Note: Output values cannot be checked without terraform.tfstate"
      exit 0
    else
      log_error "Output validation failed"
      log_error "Some expected outputs are missing from outputs.tf"
      exit 1
    fi
  fi

  # State file exists - validate actual outputs
  log_info "State file found - validating output values..."

  # Get outputs as JSON
  OUTPUT_JSON=$(tofu output -json 2>&1) || {
    log_error "Failed to get outputs"
    echo "${OUTPUT_JSON}"
    exit 2
  }

  # Validate expected outputs exist
  log_info "Validating expected outputs..."

  FAILED=0

  # Expected outputs
  declare -a EXPECTED_OUTPUTS=(
    "network_id"
    "network_ip_range"
    "servers"
    "ansible_inventory"
  )

  # Check each expected output
  for output in "${EXPECTED_OUTPUTS[@]}"; do
    if echo "${OUTPUT_JSON}" | jq -e ".${output}" &> /dev/null; then
      log_success "Found output: ${output}"
    else
      log_error "Missing output: ${output}"
      FAILED=1
    fi
  done

  # Validate servers output structure
  if echo "${OUTPUT_JSON}" | jq -e '.servers.value.mail_prod_nbg' &> /dev/null; then
    log_success "Servers output contains mail_prod_nbg"
  else
    log_error "Servers output missing mail_prod_nbg"
    FAILED=1
  fi

  if echo "${OUTPUT_JSON}" | jq -e '.servers.value.syncthing_prod_hel' &> /dev/null; then
    log_success "Servers output contains syncthing_prod_hel"
  else
    log_error "Servers output missing syncthing_prod_hel"
    FAILED=1
  fi

  if echo "${OUTPUT_JSON}" | jq -e '.servers.value.test_dev_nbg' &> /dev/null; then
    log_success "Servers output contains test_dev_nbg"
  else
    log_error "Servers output missing test_dev_nbg"
    FAILED=1
  fi

  # Return result
  if [ ${FAILED} -eq 0 ]; then
    log_success "Output validation passed"
    log_success "All expected outputs exist and have correct structure"
    exit 0
  else
    log_error "Output validation failed"
    log_error "Some expected outputs are missing or malformed"
    exit 1
  fi
}

# Execute main function
main "$@"
