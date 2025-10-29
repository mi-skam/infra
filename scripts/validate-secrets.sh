#!/usr/bin/env bash
# Infrastructure Secrets Validation Script
# Validates SOPS-encrypted secret files against JSON Schema definitions
# Part of: Iteration I2 (Secrets Management Hardening)

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCHEMA_FILE="${REPO_ROOT}/docs/schemas/secrets_schema.yaml"
SECRETS_DIR="${REPO_ROOT}/secrets"

# SOPS age key locations (check in order) - expanded at runtime
get_age_key_locations() {
  local locations=()

  # Check SOPS_AGE_KEY_FILE if set
  if [[ -n "${SOPS_AGE_KEY_FILE:-}" ]]; then
    locations+=("${SOPS_AGE_KEY_FILE}")
  fi

  # User-specific location
  locations+=("${HOME}/.config/sops/age/keys.txt")

  # System-wide location
  locations+=("/etc/sops/age/keys.txt")

  printf '%s\n' "${locations[@]}"
}

# Required secret files to validate
EXISTING_FILES=(
  "hetzner.yaml"
  "storagebox.yaml"
)

PLANNED_FILES=(
  "users.yaml"
  "ssh-keys.yaml"
  "pgp-keys.yaml"
)

# Exit codes
EXIT_SUCCESS=0
EXIT_VALIDATION_ERROR=1
EXIT_MISSING_FILES_OR_KEYS=2

# Color output (if terminal supports it)
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  NC='\033[0m' # No Color
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  BOLD=''
  NC=''
fi

# ============================================================================
# USAGE DOCUMENTATION
# ============================================================================

show_help() {
  cat <<EOF
${BOLD}Infrastructure Secrets Validation Script${NC}

${BOLD}USAGE:${NC}
  $0 [OPTIONS]

${BOLD}DESCRIPTION:${NC}
  Validates SOPS-encrypted secret files against the schema defined in
  docs/schemas/secrets_schema.yaml. The script decrypts secrets using SOPS,
  validates structure and content, and reports any violations.

${BOLD}OPTIONS:${NC}
  -h, --help              Show this help message
  -v, --verbose           Enable verbose output (show all checks)
  --skip-planned          Skip validation for planned (not-yet-created) files

${BOLD}EXIT CODES:${NC}
  0                       All secrets validated successfully
  1                       Validation error (invalid structure, missing fields, wrong types)
  2                       Missing required files or age encryption key

${BOLD}REQUIREMENTS:${NC}
  - sops (SOPS encryption tool)
  - jq (JSON processor)
  - age private key at one of:
    * \$SOPS_AGE_KEY_FILE
    * ~/.config/sops/age/keys.txt
    * /etc/sops/age/keys.txt

${BOLD}SECRET FILES VALIDATED:${NC}
  EXISTING (must pass):
    - secrets/hetzner.yaml       (Hetzner Cloud API token)
    - secrets/storagebox.yaml    (Storage Box credentials)

  PLANNED (skipped if missing):
    - secrets/users.yaml         (User password hashes)
    - secrets/ssh-keys.yaml      (SSH private keys)
    - secrets/pgp-keys.yaml      (PGP private keys)

${BOLD}EXAMPLES:${NC}
  # Validate all existing secrets
  $0

  # Verbose output with detailed checks
  $0 --verbose

  # Skip planned files (only validate existing)
  $0 --skip-planned

${BOLD}SCHEMA LOCATION:${NC}
  ${SCHEMA_FILE}

${BOLD}DOCUMENTATION:${NC}
  See CLAUDE.md for secrets management procedures and security notes.

EOF
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log_info() {
  echo -e "${BLUE}ℹ${NC} $*" >&2
}

log_success() {
  echo -e "${GREEN}✓${NC} $*" >&2
}

log_warning() {
  echo -e "${YELLOW}⚠${NC} $*" >&2
}

log_error() {
  echo -e "${RED}✗${NC} $*" >&2
}

log_verbose() {
  if [[ "${VERBOSE:-0}" -eq 1 ]]; then
    echo -e "${BLUE}  →${NC} $*" >&2
  fi
}

# ============================================================================
# PREREQUISITE CHECKS
# ============================================================================

check_dependencies() {
  log_verbose "Checking for required tools..."

  local missing_tools=()

  if ! command -v sops &>/dev/null; then
    missing_tools+=("sops")
  fi

  if ! command -v jq &>/dev/null; then
    missing_tools+=("jq")
  fi

  if [[ ${#missing_tools[@]} -gt 0 ]]; then
    log_error "Missing required tools: ${missing_tools[*]}"
    log_error "Install with: nix develop (from repository root)"
    return 1
  fi

  log_verbose "All required tools are available"
  return 0
}

find_age_key() {
  log_verbose "Searching for age private key..."

  while IFS= read -r key_path; do
    log_verbose "Checking: ${key_path}"
    if [[ -n "${key_path}" ]] && [[ -f "${key_path}" ]]; then
      log_verbose "Found age key at: ${key_path}"
      echo "${key_path}"
      return 0
    fi
  done < <(get_age_key_locations)

  log_error "Age private key not found in any of these locations:"
  while IFS= read -r key_path; do
    if [[ -n "${key_path}" ]]; then
      log_error "  - ${key_path}"
    fi
  done < <(get_age_key_locations)
  log_error ""
  log_error "To fix: Copy your age private key to one of the above locations"
  log_error "Example: cp /path/to/age-key.txt ~/.config/sops/age/keys.txt"
  return 1
}

check_schema_file() {
  log_verbose "Checking for schema file..."

  if [[ ! -f "${SCHEMA_FILE}" ]]; then
    log_error "Schema file not found: ${SCHEMA_FILE}"
    log_error "This file should be created by task I2.T1"
    return 1
  fi

  log_verbose "Schema file found: ${SCHEMA_FILE}"
  return 0
}

# ============================================================================
# DECRYPTION FUNCTIONS
# ============================================================================

decrypt_secret_file() {
  local secret_file="$1"
  local temp_file
  local temp_error

  temp_file=$(mktemp)
  temp_error=$(mktemp)

  # Decrypt and convert to JSON format for easier processing with jq
  if ! sops -d --output-type json "${secret_file}" > "${temp_file}" 2>"${temp_error}"; then
    log_error "Failed to decrypt: ${secret_file}"
    if [[ "${VERBOSE:-0}" -eq 1 ]]; then
      log_error "  SOPS error: $(cat "${temp_error}")"
    fi
    rm -f "${temp_file}" "${temp_error}"
    return 1
  fi

  rm -f "${temp_error}"
  echo "${temp_file}"
  return 0
}

# ============================================================================
# VALIDATION FUNCTIONS
# ============================================================================

validate_hetzner_secrets() {
  local decrypted_file="$1"
  local errors=0

  log_verbose "Validating Hetzner Cloud secrets structure..."

  # Check required field: hcloud
  if ! jq -e '.hcloud' "${decrypted_file}" &>/dev/null; then
    log_error "  [hetzner.yaml] Missing required field: hcloud"
    ((errors++))
  else
    local hcloud_token
    hcloud_token=$(jq -r '.hcloud // empty' "${decrypted_file}")

    # Check token is a string (not null)
    if [[ "${hcloud_token}" == "null" ]] || [[ -z "${hcloud_token}" ]]; then
      log_error "  [hetzner.yaml] Field 'hcloud' is empty or null"
      ((errors++))
    # Check token length (must be exactly 64 characters)
    elif [[ ${#hcloud_token} -ne 64 ]]; then
      log_error "  [hetzner.yaml] Field 'hcloud' must be 64 characters (found: ${#hcloud_token})"
      ((errors++))
    # Check token format (alphanumeric only)
    elif ! [[ "${hcloud_token}" =~ ^[A-Za-z0-9]{64}$ ]]; then
      log_error "  [hetzner.yaml] Field 'hcloud' contains invalid characters (must be alphanumeric)"
      ((errors++))
    else
      log_verbose "  Field 'hcloud': valid (64-char alphanumeric token)"
    fi
  fi

  # Check for additional properties (should only have 'hcloud')
  local field_count
  field_count=$(jq '. | keys | length' "${decrypted_file}")
  if [[ "${field_count}" -gt 1 ]]; then
    log_warning "  [hetzner.yaml] Contains additional properties (expected only 'hcloud')"
    local extra_fields
    extra_fields=$(jq -r '. | keys | .[] | select(. != "hcloud")' "${decrypted_file}" | tr '\n' ' ')
    log_warning "  Additional fields: ${extra_fields}"
  fi

  return "${errors}"
}

validate_storagebox_secrets() {
  local decrypted_file="$1"
  local errors=0

  log_verbose "Validating Storage Box secrets structure..."

  # Check top-level structure
  if ! jq -e '.storagebox' "${decrypted_file}" &>/dev/null; then
    log_error "  [storagebox.yaml] Missing required top-level field: storagebox"
    return 1
  fi

  # Check required fields
  local required_fields=("username" "password" "host" "mount_point")
  for field in "${required_fields[@]}"; do
    local value
    value=$(jq -r ".storagebox.${field} // empty" "${decrypted_file}")

    if [[ "${value}" == "null" ]] || [[ -z "${value}" ]]; then
      log_error "  [storagebox.yaml] Missing required field: storagebox.${field}"
      ((errors++))
    else
      # Validate field-specific patterns
      case "${field}" in
        username)
          if ! [[ "${value}" =~ ^u[0-9]+-sub[0-9]+$ ]]; then
            log_error "  [storagebox.yaml] Field 'username' has invalid format (expected: uXXXXXX-subN)"
            ((errors++))
          elif [[ ${#value} -lt 8 ]] || [[ ${#value} -gt 32 ]]; then
            log_error "  [storagebox.yaml] Field 'username' length out of range (8-32 chars)"
            ((errors++))
          else
            log_verbose "  Field 'username': valid (${value})"
          fi
          ;;
        password)
          if ! [[ "${value}" =~ ^[A-Za-z0-9]{12,64}$ ]]; then
            log_error "  [storagebox.yaml] Field 'password' has invalid format (expected: 12-64 alphanumeric chars)"
            ((errors++))
          else
            log_verbose "  Field 'password': valid (${#value} chars)"
          fi
          ;;
        host)
          if ! [[ "${value}" =~ ^u[0-9]+\.your-storagebox\.de$ ]]; then
            log_error "  [storagebox.yaml] Field 'host' has invalid format (expected: uXXXXXX.your-storagebox.de)"
            ((errors++))
          else
            log_verbose "  Field 'host': valid (${value})"
          fi
          ;;
        mount_point)
          if ! [[ "${value}" =~ ^/[a-zA-Z0-9/_-]+$ ]]; then
            log_error "  [storagebox.yaml] Field 'mount_point' has invalid format (expected: absolute path)"
            ((errors++))
          elif [[ ${#value} -gt 255 ]]; then
            log_error "  [storagebox.yaml] Field 'mount_point' too long (max 255 chars)"
            ((errors++))
          else
            log_verbose "  Field 'mount_point': valid (${value})"
          fi
          ;;
      esac
    fi
  done

  return "${errors}"
}

validate_users_secrets() {
  local decrypted_file="$1"
  local errors=0

  log_verbose "Validating user password secrets structure..."

  # Check top-level structure
  if ! jq -e '.users' "${decrypted_file}" &>/dev/null; then
    log_error "  [users.yaml] Missing required top-level field: users"
    return 1
  fi

  # Check that at least one user exists
  local user_count
  user_count=$(jq '.users | keys | length' "${decrypted_file}")
  if [[ "${user_count}" -eq 0 ]]; then
    log_error "  [users.yaml] No users defined (must have at least one)"
    ((errors++))
    return "${errors}"
  fi

  # Validate each user
  local usernames
  usernames=$(jq -r '.users | keys | .[]' "${decrypted_file}")

  while IFS= read -r username; do
    # Validate username format
    if ! [[ "${username}" =~ ^[a-z][a-z0-9_-]{2,31}$ ]]; then
      log_error "  [users.yaml] Invalid username format: ${username} (expected: lowercase, 3-32 chars)"
      ((errors++))
      continue
    fi

    # Check password_hash field
    local password_hash
    password_hash=$(jq -r ".users.\"${username}\".password_hash // empty" "${decrypted_file}")

    if [[ "${password_hash}" == "null" ]] || [[ -z "${password_hash}" ]]; then
      log_error "  [users.yaml] User '${username}': missing required field 'password_hash'"
      ((errors++))
    else
      # Validate password hash format (bcrypt or sha512crypt)
      local bcrypt_pattern='^\$2[aby]?\$[0-9]{2}\$[./A-Za-z0-9]{53}$'
      local sha512_pattern='^\$6\$[./A-Za-z0-9]{1,16}\$[./A-Za-z0-9]{86}$'

      if [[ "${password_hash}" =~ ${bcrypt_pattern} ]] || [[ "${password_hash}" =~ ${sha512_pattern} ]]; then
        log_verbose "  User '${username}': valid password hash"
      else
        log_error "  [users.yaml] User '${username}': invalid password hash format (expected bcrypt or sha512crypt)"
        ((errors++))
      fi

      # Check minimum length
      if [[ ${#password_hash} -lt 60 ]]; then
        log_error "  [users.yaml] User '${username}': password hash too short (min 60 chars)"
        ((errors++))
      fi
    fi
  done <<< "${usernames}"

  return "${errors}"
}

validate_ssh_keys_secrets() {
  local decrypted_file="$1"
  local errors=0

  log_verbose "Validating SSH keys secrets structure..."

  # Check top-level structure
  if ! jq -e '.ssh_keys' "${decrypted_file}" &>/dev/null; then
    log_error "  [ssh-keys.yaml] Missing required top-level field: ssh_keys"
    return 1
  fi

  # Check that at least one key exists
  local key_count
  key_count=$(jq '.ssh_keys | keys | length' "${decrypted_file}")
  if [[ "${key_count}" -eq 0 ]]; then
    log_error "  [ssh-keys.yaml] No SSH keys defined (must have at least one)"
    ((errors++))
    return "${errors}"
  fi

  # Validate each key
  local key_names
  key_names=$(jq -r '.ssh_keys | keys | .[]' "${decrypted_file}")

  while IFS= read -r key_name; do
    # Validate key name format
    if ! [[ "${key_name}" =~ ^[a-z][a-z0-9_-]{2,63}$ ]]; then
      log_error "  [ssh-keys.yaml] Invalid key name format: ${key_name}"
      ((errors++))
      continue
    fi

    # Check required fields
    local private_key
    private_key=$(jq -r ".ssh_keys.\"${key_name}\".private_key // empty" "${decrypted_file}")
    local key_type
    key_type=$(jq -r ".ssh_keys.\"${key_name}\".key_type // empty" "${decrypted_file}")

    # Validate private_key
    if [[ "${private_key}" == "null" ]] || [[ -z "${private_key}" ]]; then
      log_error "  [ssh-keys.yaml] Key '${key_name}': missing required field 'private_key'"
      ((errors++))
    else
      # Check for valid SSH key format markers
      if [[ "${private_key}" =~ ^-----BEGIN\ (OPENSSH|RSA|EC|DSA)\ PRIVATE\ KEY----- ]]; then
        log_verbose "  Key '${key_name}': valid private key format"
      else
        log_error "  [ssh-keys.yaml] Key '${key_name}': invalid private key format (missing BEGIN marker)"
        ((errors++))
      fi

      # Check minimum length
      if [[ ${#private_key} -lt 100 ]]; then
        log_error "  [ssh-keys.yaml] Key '${key_name}': private key too short (min 100 chars)"
        ((errors++))
      fi
    fi

    # Validate key_type
    if [[ "${key_type}" == "null" ]] || [[ -z "${key_type}" ]]; then
      log_error "  [ssh-keys.yaml] Key '${key_name}': missing required field 'key_type'"
      ((errors++))
    elif [[ ! "${key_type}" =~ ^(rsa|ed25519|ecdsa|dsa)$ ]]; then
      log_error "  [ssh-keys.yaml] Key '${key_name}': invalid key_type '${key_type}' (expected: rsa, ed25519, ecdsa, dsa)"
      ((errors++))
    else
      log_verbose "  Key '${key_name}': valid key_type (${key_type})"
    fi
  done <<< "${key_names}"

  return "${errors}"
}

validate_pgp_keys_secrets() {
  local decrypted_file="$1"
  local errors=0

  log_verbose "Validating PGP keys secrets structure..."

  # Check top-level structure
  if ! jq -e '.pgp_keys' "${decrypted_file}" &>/dev/null; then
    log_error "  [pgp-keys.yaml] Missing required top-level field: pgp_keys"
    return 1
  fi

  # Check that at least one key exists
  local key_count
  key_count=$(jq '.pgp_keys | keys | length' "${decrypted_file}")
  if [[ "${key_count}" -eq 0 ]]; then
    log_error "  [pgp-keys.yaml] No PGP keys defined (must have at least one)"
    ((errors++))
    return "${errors}"
  fi

  # Validate each key
  local key_names
  key_names=$(jq -r '.pgp_keys | keys | .[]' "${decrypted_file}")

  while IFS= read -r key_name; do
    # Validate key name format
    if ! [[ "${key_name}" =~ ^[a-z][a-z0-9_-]{2,63}$ ]]; then
      log_error "  [pgp-keys.yaml] Invalid key name format: ${key_name}"
      ((errors++))
      continue
    fi

    # Check required fields
    local private_key
    private_key=$(jq -r ".pgp_keys.\"${key_name}\".private_key // empty" "${decrypted_file}")
    local key_id
    key_id=$(jq -r ".pgp_keys.\"${key_name}\".key_id // empty" "${decrypted_file}")

    # Validate private_key
    if [[ "${private_key}" == "null" ]] || [[ -z "${private_key}" ]]; then
      log_error "  [pgp-keys.yaml] Key '${key_name}': missing required field 'private_key'"
      ((errors++))
    else
      # Check for valid PGP key format marker
      if [[ "${private_key}" =~ ^-----BEGIN\ PGP\ PRIVATE\ KEY\ BLOCK----- ]]; then
        log_verbose "  Key '${key_name}': valid PGP private key format"
      else
        log_error "  [pgp-keys.yaml] Key '${key_name}': invalid private key format (missing PGP BEGIN marker)"
        ((errors++))
      fi

      # Check minimum length
      if [[ ${#private_key} -lt 100 ]]; then
        log_error "  [pgp-keys.yaml] Key '${key_name}': private key too short (min 100 chars)"
        ((errors++))
      fi
    fi

    # Validate key_id
    if [[ "${key_id}" == "null" ]] || [[ -z "${key_id}" ]]; then
      log_error "  [pgp-keys.yaml] Key '${key_name}': missing required field 'key_id'"
      ((errors++))
    elif ! [[ "${key_id}" =~ ^(0x)?[A-Fa-f0-9]{16,40}$ ]]; then
      log_error "  [pgp-keys.yaml] Key '${key_name}': invalid key_id format (expected: 16-40 hex chars, optional 0x prefix)"
      ((errors++))
    elif [[ ${#key_id} -lt 16 ]] || [[ ${#key_id} -gt 42 ]]; then
      log_error "  [pgp-keys.yaml] Key '${key_name}': key_id length out of range (16-42 chars)"
      ((errors++))
    else
      log_verbose "  Key '${key_name}': valid key_id (${key_id})"
    fi
  done <<< "${key_names}"

  return "${errors}"
}

validate_secret_file() {
  local secret_filename="$1"
  local secret_path="${SECRETS_DIR}/${secret_filename}"
  local validation_errors=0

  log_info "Validating: ${secret_filename}"

  # Check if file exists
  if [[ ! -f "${secret_path}" ]]; then
    log_warning "  File not found (planned for future implementation)"
    return 0  # Not an error for planned files
  fi

  # Decrypt the file
  local decrypted_file
  if ! decrypted_file=$(decrypt_secret_file "${secret_path}"); then
    log_error "  Decryption failed"
    return 1
  fi

  # Ensure cleanup on exit
  trap "rm -f '${decrypted_file}'" EXIT

  # Validate based on file type
  case "${secret_filename}" in
    hetzner.yaml)
      validate_hetzner_secrets "${decrypted_file}"
      validation_errors=$?
      ;;
    storagebox.yaml)
      validate_storagebox_secrets "${decrypted_file}"
      validation_errors=$?
      ;;
    users.yaml)
      validate_users_secrets "${decrypted_file}"
      validation_errors=$?
      ;;
    ssh-keys.yaml)
      validate_ssh_keys_secrets "${decrypted_file}"
      validation_errors=$?
      ;;
    pgp-keys.yaml)
      validate_pgp_keys_secrets "${decrypted_file}"
      validation_errors=$?
      ;;
    *)
      log_warning "  Unknown secret file type (no validation rules defined)"
      ;;
  esac

  # Clean up decrypted file
  rm -f "${decrypted_file}"
  trap - EXIT

  if [[ ${validation_errors} -eq 0 ]]; then
    log_success "  All checks passed"
  else
    log_error "  Found ${validation_errors} validation error(s)"
  fi

  return "${validation_errors}"
}

# ============================================================================
# MAIN VALIDATION WORKFLOW
# ============================================================================

main() {
  local skip_planned=0
  local verbose=0

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help)
        show_help
        exit 0
        ;;
      -v|--verbose)
        verbose=1
        export VERBOSE=1
        shift
        ;;
      --skip-planned)
        skip_planned=1
        shift
        ;;
      *)
        log_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit "${EXIT_VALIDATION_ERROR}"
        ;;
    esac
  done

  echo -e "${BOLD}Infrastructure Secrets Validation${NC}"
  echo ""

  # Step 1: Check dependencies
  if ! check_dependencies; then
    exit "${EXIT_MISSING_FILES_OR_KEYS}"
  fi

  # Step 2: Check for age key
  if ! AGE_KEY_PATH=$(find_age_key); then
    exit "${EXIT_MISSING_FILES_OR_KEYS}"
  fi
  export SOPS_AGE_KEY_FILE="${AGE_KEY_PATH}"

  # Step 3: Check schema file
  if ! check_schema_file; then
    exit "${EXIT_MISSING_FILES_OR_KEYS}"
  fi

  echo ""
  log_info "Starting validation..."
  echo ""

  # Step 4: Validate existing files (must pass)
  local total_errors=0
  local file_errors=0
  for secret_file in "${EXISTING_FILES[@]}"; do
    validate_secret_file "${secret_file}"
    file_errors=$?
    total_errors=$((total_errors + file_errors))
  done

  # Step 5: Validate planned files (if not skipped)
  if [[ ${skip_planned} -eq 0 ]]; then
    for secret_file in "${PLANNED_FILES[@]}"; do
      validate_secret_file "${secret_file}"
      file_errors=$?
      total_errors=$((total_errors + file_errors))
    done
  fi

  # Step 6: Report final status
  echo ""
  echo -e "${BOLD}Validation Summary${NC}"
  echo "─────────────────────────────────────"

  if [[ ${total_errors} -eq 0 ]]; then
    log_success "All secrets validated successfully"
    exit "${EXIT_SUCCESS}"
  else
    log_error "Validation failed with ${total_errors} error(s)"
    echo ""
    log_info "Review the errors above and fix the secret files"
    log_info "Edit secrets with: sops secrets/<filename>.yaml"
    exit "${EXIT_VALIDATION_ERROR}"
  fi
}

# Run main function
main "$@"
