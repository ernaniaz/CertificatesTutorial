#!/usr/bin/env bash
#=============================================================================
# Lab 05: Trust verification
# Verify that custom CA is trusted by the system
#
# Usage: ./verify-trust.sh
# Prerequisites: RHEL 7, 8, 9, 10
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
if [[ ${RHEL_VERSION} -lt 7 || ${RHEL_VERSION} -gt 10 ]]; then
  error_exit "Unsupported RHEL version. This script requires RHEL 7, 8, 9 or 10."
fi

#=============================================================================
# MAIN
#=============================================================================

OUTPUT_DIR="output"
CA_CERT="${OUTPUT_DIR}/test-ca.crt"
CA_KEY="${OUTPUT_DIR}/test-ca.key"
TEST_KEY="${OUTPUT_DIR}/test-server.key"
TEST_CERT="${OUTPUT_DIR}/test-server.crt"

print_header "Lab 05: Verifying CA Trust"

# Check prerequisites
if [[ ! -f "${CA_CERT}" || ! -f "${CA_KEY}" ]]; then
  print_error "Error: CA files not found"
  exit 1
fi

# Generate a test server key
print_info "Creating test server certificate signed by custom CA..."
openssl genpkey -algorithm RSA -out "${TEST_KEY}" -pkeyopt rsa_keygen_bits:2048 2>/dev/null

# Generate test certificate signed by custom CA
openssl req -new -key "${TEST_KEY}" \
  -subj "/C=US/ST=State/O=Lab/CN=test.example.com" | \
openssl x509 -req -sha256 -days 365 \
  -CA "${CA_CERT}" -CAkey "${CA_KEY}" -CAcreateserial \
  -out "${TEST_CERT}" 2>/dev/null

print_success "Test certificate created"
echo

# Test 1: Verify with system trust (should succeed if CA is trusted)
print_info "Test 1: Verifying with system trust store..."
if openssl verify "${TEST_CERT}" &>/dev/null; then
  print_success "SUCCESS: Certificate verified with system trust"
  echo "  Your custom CA is trusted by the system!"
else
  print_warning "FAILED: Certificate not trusted by system"
  echo "  Did you run ./update-trust.sh?"
fi
echo

# Test 2: Verify with explicit CA (should always succeed)
print_info "Test 2: Verifying with explicit CA..."
if openssl verify -CAfile "${CA_CERT}" "${TEST_CERT}" &>/dev/null; then
  print_success "SUCCESS: Certificate verified with explicit CA"
else
  print_error "FAILED: This should not happen"
  exit 1
fi
echo

# Test 3: Check if CA is in bundle
print_info "Test 3: Checking if CA is in system bundle..."
if grep -q "Lab Test Root CA" /etc/pki/tls/certs/ca-bundle.crt 2>/dev/null; then
  print_success "SUCCESS: CA found in system bundle"
else
  print_warning "WARNING: CA not found in system bundle"
  echo "  Run: sudo ./update-trust.sh"
fi
echo

print_success "Trust verification complete"
