#!/usr/bin/env bash
#=============================================================================
# Lab 22: Start Vault Dev
# Start Vault server in development mode
#
# Usage: ./start-vault-dev.sh
# Prerequisites: RHEL 8, 9, 10
#=============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable

#=============================================================================
# CONFIGURATION
#=============================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

# Script directory
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Vault configuration
readonly VAULT_ADDR="http://127.0.0.1:8200"

#=============================================================================
# HELPER FUNCTIONS
#=============================================================================

print_header ()
{
  local text="${1}"
  local width=57
  local padding=$(( width - ${#text} ))
  local pad=""
  if [[ ${padding} -gt 0 ]]; then
    pad="$(printf '%*s' "${padding}" '')"
  fi
  echo
  echo -e "${CYAN}┌─$(printf '─%.0s' $(seq 1 ${width}))─┐${NC}"
  echo -e "${CYAN}│${NC} ${BOLD}${text}${NC}${pad} ${CYAN}│${NC}"
  echo -e "${CYAN}└─$(printf '─%.0s' $(seq 1 ${width}))─┘${NC}"
  echo
}

print_step ()
{
  echo
  echo -e "  ${BOLD}▸ ${1}${NC}"
}

print_success ()
{
  echo -e "  ${GREEN}✓${NC} ${1}"
}

print_error ()
{
  echo -e "  ${RED}✗${NC} ${1}"
}

print_warning ()
{
  echo -e "  ${YELLOW}⚠${NC} ${1}"
}

print_info ()
{
  echo -e "  ${BLUE}ℹ${NC} ${1}"
}

error_exit ()
{
  print_error "${1}"
  exit 1
}

trap 'error_exit "Error occurred on line ${LINENO}"' ERR

#=============================================================================
# RHEL VERSION CHECK
#=============================================================================

if ! grep -q '^ID="rhel"$' /etc/os-release 2>/dev/null; then
  error_exit "This script requires Red Hat Enterprise Linux (RHEL)."
fi
readonly RHEL_VERSION="$(grep -oP '^VERSION_ID="\K[0-9]+' /etc/os-release 2>/dev/null)"
if [[ ${RHEL_VERSION} -lt 8 || ${RHEL_VERSION} -gt 10 ]]; then
  error_exit "Unsupported RHEL version. This script requires RHEL 8, 9 or 10."
fi

#=============================================================================
# MAIN
#=============================================================================

print_header "Lab 22: Start Vault (Dev Mode)"

# --- Step 1: Check Vault is installed ---
print_step "Checking prerequisites"

if ! command -v vault &> /dev/null; then
  error_exit "Vault not found. Run ./install-vault.sh first"
fi

print_success "Vault found: $(vault version | head -n1)"
echo

# --- Step 2: Check for existing Vault process ---
print_step "Checking for existing Vault process"

if pgrep -x vault > /dev/null; then
  print_warning "Vault is already running"
  print_info "To stop existing Vault: pkill vault"
  read -p "Kill existing Vault and start new? (y/N): " -n 1 -r
  echo
  if [[ ${REPLY} =~ ^[Yy]$ ]]; then
    pkill vault || true
    sleep 2
  else
    exit 0
  fi
fi

print_success "No conflicting Vault process"
echo

# --- Step 3: Start Vault in dev mode ---
print_step "Starting Vault in dev mode"

print_warning "Dev mode is NOT for production!"
print_info "Dev mode stores all data in memory and auto-unseals with a known root token"
echo

# Background process keeps the lab terminal free while Vault serves requests
nohup vault server -dev \
  -dev-root-token-id="root" \
  -dev-listen-address="127.0.0.1:8200" \
  > "${SCRIPT_DIR}/vault.log" 2>&1 &

vault_pid="${!}"
print_success "Vault started with PID: ${vault_pid}"
echo

# --- Step 4: Wait for Vault to become ready ---
print_step "Waiting for Vault to be ready"

max_attempts=30
attempt=0
while [[ ${attempt} -lt ${max_attempts} ]]; do
  if VAULT_ADDR="${VAULT_ADDR}" vault status &> /dev/null; then
    print_success "Vault is ready"
    break
  fi
  sleep 1
  attempt=$((attempt + 1))
done

if [[ ${attempt} -ge ${max_attempts} ]]; then
  error_exit "Vault failed to start — check vault.log for details"
fi
echo

# --- Step 5: Save connection details for other lab scripts ---
print_step "Saving configuration to vault-env.sh"

cat > "${SCRIPT_DIR}/vault-env.sh" <<EOF
#!/usr/bin/env bash
# Vault environment variables for Lab 22
# Source this file: source vault-env.sh

export VAULT_ADDR='${VAULT_ADDR}'
export VAULT_TOKEN='root'
export VAULT_PID='${vault_pid}'
EOF

chmod +x "${SCRIPT_DIR}/vault-env.sh"
print_success "Configuration saved to vault-env.sh"
echo

# --- Step 6: Export environment and verify status ---
print_step "Verifying Vault status"

export VAULT_ADDR="${VAULT_ADDR}"
export VAULT_TOKEN="root"

if ! vault status; then
  error_exit "Vault status check failed"
fi

print_success "Vault is running and unsealed"
echo

# --- Step 7: Display access information ---
print_step "Vault access information"

print_warning "IMPORTANT: Save these credentials!"
echo
print_info "Vault Address: ${VAULT_ADDR}"
print_info "Root Token: root"
print_info "Process PID: ${vault_pid}"
echo
print_warning "Dev Mode Warnings:"
echo "  - All data stored in memory (lost on restart)"
echo "  - Vault runs unsealed"
echo "  - Root token is 'root' (insecure)"
echo "  - DO NOT use in production!"
echo
print_info "To configure your shell:"
echo "  source vault-env.sh"
echo
echo "Next steps:"
echo "  1. Source environment: source vault-env.sh"
echo "  2. Run './enable-pki.sh' to enable PKI secrets engine"
echo
print_info "Vault logs: tail -f vault.log"
