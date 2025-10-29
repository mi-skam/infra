#!/usr/bin/env bash
# ============================================================================
# Drift Detection Script for Hetzner Infrastructure
# ============================================================================
# Purpose: Detects infrastructure drift between Terraform config and actual state
# Usage: ./drift-detection.sh [--help]
# Exit codes: 0 (no drift), 1 (drift detected), 2 (error)
# ============================================================================

set -euo pipefail

# ============================================================================
# Configuration and Constants
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SECRETS_FILE="${REPO_ROOT}/secrets/hetzner.yaml"
TIMESTAMP="$(date +'%Y-%m-%d %H:%M:%S')"

# Exit codes
EXIT_SUCCESS=0
EXIT_DRIFT_DETECTED=1
EXIT_ERROR=2

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No color

# ============================================================================
# Helper Functions
# ============================================================================

print_help() {
  cat <<EOF
Drift Detection Script for Hetzner Infrastructure

USAGE:
  $0 [OPTIONS]

DESCRIPTION:
  Detects infrastructure drift between Terraform configuration and actual
  Hetzner Cloud state by refreshing state and generating a plan.

  This script performs:
  1. Validates prerequisites (Terraform initialized, age key, API token)
  2. Refreshes Terraform state from Hetzner Cloud API
  3. Generates plan to detect changes (tofu plan -detailed-exitcode)
  4. Reports drifted resources with details

OPTIONS:
  --help, -h    Show this help message

EXIT CODES:
  0    No drift detected (infrastructure matches configuration)
  1    Drift detected (resources have changed)
  2    Error (API failure, missing credentials, Terraform errors)

EXAMPLES:
  $0              # Check for drift
  $0 --help       # Show this help

NOTES:
  - This script does NOT modify infrastructure (read-only operations)
  - Safe to run multiple times
  - Requires SOPS age key for decrypting Hetzner API token
  - Designed for CI/CD integration (future Iteration 7)

EOF
}

log_info() {
  echo -e "${BLUE}→${NC} $*"
}

log_success() {
  echo -e "${GREEN}✓${NC} $*"
}

log_warning() {
  echo -e "${YELLOW}⚠${NC} $*"
}

log_error() {
  echo -e "${RED}❌${NC} $*" >&2
}

print_header() {
  echo "═══════════════════════════════════════"
  echo "$*"
  echo "═══════════════════════════════════════"
}

# ============================================================================
# Validation Functions
# ============================================================================

validate_terraform_initialized() {
  if [ ! -f "${SCRIPT_DIR}/.terraform.lock.hcl" ]; then
    log_error "Terraform is not initialized"
    echo "Run 'just tf-init' first to initialize Terraform" >&2
    return 1
  fi
  return 0
}

validate_age_key() {
  local age_key_locations=(
    "${SOPS_AGE_KEY_FILE:-}"
    "${HOME}/.config/sops/age/keys.txt"
    "/etc/sops/age/keys.txt"
  )

  for location in "${age_key_locations[@]}"; do
    if [ -n "$location" ] && [ -f "$location" ]; then
      return 0
    fi
  done

  log_error "SOPS age key not found"
  echo "Checked locations:" >&2
  for location in "${age_key_locations[@]}"; do
    if [ -n "$location" ]; then
      echo "  - $location" >&2
    fi
  done
  echo "" >&2
  echo "Set SOPS_AGE_KEY_FILE environment variable or create key at:" >&2
  echo "  ~/.config/sops/age/keys.txt" >&2
  return 1
}

validate_secrets_file() {
  if [ ! -f "$SECRETS_FILE" ]; then
    log_error "Secrets file not found: $SECRETS_FILE"
    return 1
  fi
  return 0
}

decrypt_hetzner_token() {
  local token
  if ! token=$(sops -d "$SECRETS_FILE" 2>&1 | grep 'hcloud:' | cut -d: -f2 | xargs); then
    log_error "Failed to decrypt Hetzner API token"
    echo "Check SOPS age key is configured correctly" >&2
    return 1
  fi

  if [ -z "$token" ]; then
    log_error "Hetzner API token is empty after decryption"
    echo "Check that secrets/hetzner.yaml contains valid hcloud token" >&2
    return 1
  fi

  echo "$token"
}

# ============================================================================
# Drift Detection Functions
# ============================================================================

refresh_terraform_state() {
  log_info "Refreshing Terraform state from Hetzner Cloud..."

  if ! tofu refresh -no-color > /dev/null 2>&1; then
    log_error "Failed to refresh Terraform state"
    echo "Possible causes:" >&2
    echo "  - Network connectivity issues" >&2
    echo "  - Invalid Hetzner API token" >&2
    echo "  - Hetzner API unavailable" >&2
    return 1
  fi

  log_success "State refreshed successfully"
  return 0
}

detect_drift() {
  log_info "Detecting drift..."

  local plan_output
  local plan_exit_code

  # Capture plan output and exit code
  plan_output=$(tofu plan -detailed-exitcode -no-color 2>&1) || plan_exit_code=$?

  case ${plan_exit_code:-0} in
    0)
      # No changes needed
      return 0
      ;;
    1)
      # Error occurred
      log_error "Error during Terraform plan"
      echo "$plan_output" >&2
      return 2
      ;;
    2)
      # Changes detected (drift)
      echo "$plan_output"
      return 1
      ;;
    *)
      log_error "Unexpected exit code from Terraform plan: ${plan_exit_code}"
      return 2
      ;;
  esac
}

parse_drift_summary() {
  local plan_output="$1"
  local resources_to_add=0
  local resources_to_change=0
  local resources_to_destroy=0

  # Parse plan output for resource counts
  if echo "$plan_output" | grep -q "Plan:"; then
    resources_to_add=$(echo "$plan_output" | grep "Plan:" | grep -oE '[0-9]+ to add' | grep -oE '[0-9]+' || echo "0")
    resources_to_change=$(echo "$plan_output" | grep "Plan:" | grep -oE '[0-9]+ to change' | grep -oE '[0-9]+' || echo "0")
    resources_to_destroy=$(echo "$plan_output" | grep "Plan:" | grep -oE '[0-9]+ to destroy' | grep -oE '[0-9]+' || echo "0")
  fi

  echo "Resources to add: ${resources_to_add}"
  echo "Resources to change: ${resources_to_change}"
  echo "Resources to destroy: ${resources_to_destroy}"
}

extract_drifted_resources() {
  local plan_output="$1"

  # Extract resource changes from plan output
  echo "$plan_output" | awk '
    /Terraform will perform the following actions:/ { in_changes=1; next }
    /Plan:/ { in_changes=0 }
    in_changes && /^[[:space:]]*[#~+-]/ { print }
  '
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
  # Handle help flag
  if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    print_help
    exit $EXIT_SUCCESS
  fi

  echo "[$TIMESTAMP] Starting drift detection..."
  echo ""

  # Section 1: Prerequisites validation
  log_info "Validating prerequisites..."

  if ! validate_terraform_initialized; then
    exit $EXIT_ERROR
  fi
  log_success "Terraform initialized"

  if ! validate_age_key; then
    exit $EXIT_ERROR
  fi
  log_success "SOPS age key found"

  if ! validate_secrets_file; then
    exit $EXIT_ERROR
  fi

  # Section 2: Decrypt Hetzner API token
  local hcloud_token
  if ! hcloud_token=$(decrypt_hetzner_token); then
    exit $EXIT_ERROR
  fi
  log_success "Hetzner API token decrypted"

  # Export token for Terraform
  export TF_VAR_hcloud_token="$hcloud_token"

  # Change to terraform directory
  cd "$SCRIPT_DIR"

  # Section 3: Refresh state
  if ! refresh_terraform_state; then
    exit $EXIT_ERROR
  fi

  # Section 4: Detect drift
  local drift_output
  local drift_exit_code

  drift_output=$(detect_drift 2>&1) || drift_exit_code=$?

  echo ""

  case ${drift_exit_code:-0} in
    0)
      # No drift
      log_success "No drift detected - infrastructure matches configuration"
      echo ""
      print_header "Drift Detection Summary"
      echo "Timestamp: $(date +'%Y-%m-%d %H:%M:%S')"
      echo "Status: NO DRIFT"
      echo ""
      echo "Infrastructure is in sync with Terraform configuration."
      exit $EXIT_SUCCESS
      ;;
    1)
      # Drift detected
      log_warning "DRIFT DETECTED"
      echo ""
      print_header "Drifted Resources"
      echo ""

      # Extract and display drifted resources
      local drifted_resources
      drifted_resources=$(extract_drifted_resources "$drift_output")

      if [ -n "$drifted_resources" ]; then
        echo "$drifted_resources"
      else
        # Fallback: show full plan output if parsing fails
        echo "$drift_output"
      fi

      echo ""
      print_header "Drift Detection Summary"
      echo "Timestamp: $(date +'%Y-%m-%d %H:%M:%S')"
      echo "Status: DRIFT DETECTED"
      echo ""
      parse_drift_summary "$drift_output"
      echo ""
      echo "Recommended action: Review changes and run 'just tf-apply' to align"
      echo "infrastructure with configuration, or update configuration to match"
      echo "current infrastructure state."
      exit $EXIT_DRIFT_DETECTED
      ;;
    2)
      # Error during detection
      log_error "Error during drift detection"
      echo "$drift_output" >&2
      exit $EXIT_ERROR
      ;;
    *)
      log_error "Unexpected exit code: ${drift_exit_code}"
      exit $EXIT_ERROR
      ;;
  esac
}

# Run main function
main "$@"
