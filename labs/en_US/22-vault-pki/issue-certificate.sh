#!/usr/bin/env bash
#=============================================================================
# Lab 22: Issue Certificate
# Issue certificates using configured role
#
# Usage: ./issue-certificate.sh
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
readonly CERTS_DIR="${SCRIPT_DIR}/certs"

# Default values
ROLE_NAME="web-server"
COMMON_NAME="${1:-}"
TTL="${2:-24h}"

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

print_header "Lab 22: Issue Certificates"

# --- Step 1: Load Vault connection details ---
print_step "Loading Vault environment"

if [[ -f "${SCRIPT_DIR}/vault-env.sh" ]]; then
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/vault-env.sh"
  print_success "Environment loaded from vault-env.sh"
else
  export VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
  export VAULT_TOKEN="${VAULT_TOKEN:-root}"
fi
echo

# --- Step 2: Verify role and intermediate CA exist ---
print_step "Checking prerequisites"

if ! vault read "pki_int/roles/${ROLE_NAME}" &> /dev/null; then
  error_exit "Role '${ROLE_NAME}' not found. Run ./create-role.sh first"
fi

if ! vault read pki_int/cert/ca &> /dev/null; then
  error_exit "Intermediate CA not found. Run ./configure-intermediate-ca.sh first"
fi

mkdir -p "${CERTS_DIR}"
print_success "PKI role and intermediate CA found"
echo

# --- Step 3: Issue certificate(s) ---
print_step "Issuing certificates"

if [[ -n "${COMMON_NAME}" ]]; then
  cert_names=("${COMMON_NAME}")
  cert_ttls=("${TTL}")
else
  cert_names=("server01.lab.local" "server02.lab.local" "temp.lab.local")
  cert_ttls=("24h" "24h" "1h")
fi

for i in "${!cert_names[@]}"; do
  cn="${cert_names[${i}]}"
  ttl="${cert_ttls[${i}]}"
  cert_base="${CERTS_DIR}/${cn}"

  print_info "Issuing certificate: ${cn} (TTL: ${ttl})..."

  if ! response="$(vault write -format=json "pki_int/issue/${ROLE_NAME}" \
    common_name="${cn}" \
    ttl="${ttl}")"; then
    error_exit "Failed to issue certificate for ${cn}"
  fi

  echo "${response}" | jq -r '.data.certificate' > "${cert_base}.crt"
  echo "${response}" | jq -r '.data.private_key' > "${cert_base}.key"
  echo "${response}" | jq -r '.data.ca_chain[]' > "${cert_base}-chain.crt"
  echo "${response}" | jq -r '.data.issuing_ca' > "${cert_base}-ca.crt"
  cat "${cert_base}.crt" "${cert_base}.key" > "${cert_base}.pem"
  echo "${response}" | jq -r '.data.serial_number' > "${cert_base}.serial"

  chmod 644 "${cert_base}.crt" "${cert_base}.pem" "${cert_base}-chain.crt" "${cert_base}-ca.crt"
  chmod 600 "${cert_base}.key"

  print_success "Certificate issued: ${cn}"
  print_info "  Certificate: ${cert_base}.crt"
  print_info "  Private key: ${cert_base}.key"
  print_info "  Serial: $(cat "${cert_base}.serial")"
  echo
done

if [[ -z "${COMMON_NAME}" ]]; then
  print_success "All test certificates issued"
fi
echo

# --- Step 4: Display certificate summary ---
print_step "Certificate summary"

print_info "Certificates issued:"
if ! ls -lh "${CERTS_DIR}"/*.crt 2>/dev/null | grep -v -- '-chain.crt' | grep -v -- '-ca.crt'; then
  print_warning "No certificates found"
fi
echo
print_info "Total certificates: $(find "${CERTS_DIR}" -maxdepth 1 -name '*.crt' ! -name '*-chain.crt' ! -name '*-ca.crt' 2>/dev/null | wc -l)"
echo

# --- Step 5: Verify certificates with OpenSSL ---
print_step "Verifying certificates with OpenSSL"

for cert_file in "${CERTS_DIR}"/*.crt; do
  if [[ ! (-f "${cert_file}") ]]; then
    continue
  fi
  if [[ "${cert_file}" =~ -chain\.crt$ ]]; then
    continue
  fi
  if [[ "${cert_file}" =~ -ca\.crt$ ]]; then
    continue
  fi

  cert_base="${cert_file%.crt}"
  print_info "Verifying: $(basename "${cert_file}")"

  if [[ -f "${cert_base}-ca.crt" ]] && openssl verify -CAfile "${cert_base}-ca.crt" "${cert_file}" &> /dev/null; then
    print_success "Certificate is valid"
  else
    print_warning "Certificate verification had issues"
  fi

  print_info "Subject and validity:"
  openssl x509 -in "${cert_file}" -noout -subject -dates
done

echo
print_success "Certificate issuance complete!"
echo
echo "Certificate files:"
echo "  *.crt       - Certificate"
echo "  *.key       - Private key"
echo "  *.pem       - Certificate + key bundle"
echo "  *-chain.crt - CA chain"
echo "  *.serial    - Serial number (for revocation)"
echo
echo "Next steps:"
echo "  - Inspect certificate: openssl x509 -in certs/server01.lab.local.crt -noout -text"
echo "  - Use certificate: cp certs/server01.lab.local.* /etc/pki/tls/"
echo "  - Run './revoke-certificate.sh' to test revocation"
