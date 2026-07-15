#!/usr/bin/env bash
#=============================================================================
# Lab 22: Install Vault
# Download and install HashiCorp Vault
#
# Usage: ./install-vault.sh
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

# Vault configuration
readonly VAULT_VERSION="1.15.4"
readonly VAULT_URL="https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip"

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

print_header "Lab 22: Install Vault"

print_success "RHEL ${RHEL_VERSION} detected"
echo

# --- Step 1: Check existing installation ---
print_step "Checking for existing Vault installation"

if command -v vault &> /dev/null; then
  existing_version="$(vault version | head -n1)"
  print_warning "Vault already installed: ${existing_version}"
  read -p "Reinstall? (y/N): " -n 1 -r
  echo
  if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
    print_info "Using existing installation"
    echo
    print_info "Vault is ready to use"
    echo
    echo "Quick commands:"
    echo "  vault version         - Show Vault version"
    echo "  vault --help          - Show help"
    echo
    echo "Next steps:"
    echo "  - Run './start-vault-dev.sh' to start Vault in dev mode"
    echo "  - Run 'vault server --help' for server options"
    exit 0
  fi
fi

print_success "Proceeding with Vault installation"
echo

# --- Step 2: Install dependencies ---
print_step "Installing dependencies"

# unzip and jq are required to extract the binary and parse JSON in later labs
if ! command -v unzip &> /dev/null; then
  sudo dnf install -y unzip
fi

if ! command -v curl &> /dev/null; then
  sudo dnf install -y curl
fi

if ! command -v jq &> /dev/null; then
  sudo dnf install -y jq
fi

print_success "Dependencies installed"
echo

# --- Step 3: Detect architecture and download Vault ---
print_step "Downloading Vault ${VAULT_VERSION}"

vault_arch="amd64"
if [[ "$(uname -m)" == "aarch64" ]] || [[ "$(uname -m)" == "arm64" ]]; then
  vault_arch="arm64"
fi

vault_download_url="https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_${vault_arch}.zip"
print_info "Architecture: ${vault_arch}"
print_info "Download URL: ${vault_download_url}"

temp_dir="$(mktemp -d)"
if ! curl -sSL -o "${temp_dir}/vault.zip" "${vault_download_url}"; then
  rm -rf "${temp_dir}"
  error_exit "Failed to download Vault from releases.hashicorp.com"
fi

print_success "Vault downloaded"
echo

# --- Step 4: Install Vault binary ---
print_step "Installing Vault to /usr/local/bin"

if ! unzip -q "${temp_dir}/vault.zip" -d "${temp_dir}"; then
  rm -rf "${temp_dir}"
  error_exit "Failed to extract Vault archive"
fi

chmod +x "${temp_dir}/vault"
if ! sudo mv "${temp_dir}/vault" /usr/local/bin/vault; then
  rm -rf "${temp_dir}"
  error_exit "Failed to install Vault binary"
fi

rm -rf "${temp_dir}"
print_success "Vault installed to /usr/local/bin/vault"
echo

# --- Step 5: Verify installation ---
print_step "Verifying installation"

if ! command -v vault &> /dev/null; then
  error_exit "Vault installation failed — binary not found in PATH"
fi

installed_version="$(vault version)"
print_success "Vault version: ${installed_version}"
echo

# --- Step 6: Display usage instructions ---
print_step "Installation complete"

print_info "Vault is ready to use"
echo
echo "Quick commands:"
echo "  vault version         - Show Vault version"
echo "  vault --help          - Show help"
echo
echo "Next steps:"
echo "  - Run './start-vault-dev.sh' to start Vault in dev mode"
echo "  - Run 'vault server --help' for server options"
