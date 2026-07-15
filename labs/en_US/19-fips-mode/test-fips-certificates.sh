#!/usr/bin/env bash
#=============================================================================
# Lab 19: Test Fips Certificates
# Test certificate operations under FIPS
#
# Usage: ./test-fips-certificates.sh
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

TEST_DIR="/tmp/fips-cert-test"

print_header "Lab 19: Test FIPS Certificate Operations"

# Check if FIPS is enabled
if [[ -f /proc/sys/crypto/fips_enabled ]]; then
  FIPS_STATUS="$(cat /proc/sys/crypto/fips_enabled)"
  if [[ ${FIPS_STATUS} -ne 1 ]]; then
    print_warning "FIPS mode not enabled"
    echo "This test works best with FIPS enabled"
    echo
  fi
fi

# Create test directory
mkdir -p "${TEST_DIR}"
cd "${TEST_DIR}"

print_info "1. Testing RSA 2048 key generation..."
if openssl genrsa -out rsa-2048.key 2048 2>/dev/null; then
  print_success "RSA 2048 generation successful"
else
  print_error "RSA 2048 generation failed"
fi

echo

print_info "2. Testing ECDSA P-256 key generation..."
if openssl ecparam -genkey -name prime256v1 -out ec-p256.key 2>/dev/null; then
  print_success "ECDSA P-256 generation successful"
else
  print_error "ECDSA P-256 generation failed"
fi

echo

print_info "3. Testing certificate with SHA-256..."
if openssl req -x509 -new -key rsa-2048.key -sha256 \
  -out cert-sha256.pem -days 365 \
  -subj "/CN=fips-test.example.com" \
  -addext "subjectAltName=DNS:fips-test.example.com" 2>/dev/null; then
  print_success "SHA-256 certificate created"
  openssl x509 -in cert-sha256.pem -noout -subject -dates | sed 's/^/  /'
else
  print_error "SHA-256 certificate creation failed"
fi

echo

print_info "4. Testing MD5 (should fail in FIPS)..."
if echo "test" | openssl md5 2>&1 | grep -qi "fips"; then
  print_success "MD5 properly blocked by FIPS"
elif ! echo "test" | openssl md5 &>/dev/null; then
  print_success "MD5 blocked"
else
  print_warning "MD5 not blocked (FIPS not active?)"
fi

echo

print_info "5. Testing certificate verification..."
if openssl x509 -in cert-sha256.pem -noout -text >/dev/null 2>&1; then
  print_success "Certificate validation works"
else
  print_error "Certificate validation failed"
fi

echo

# Cleanup
cd /
rm -rf "${TEST_DIR}"

print_success "FIPS certificate testing complete"
echo
echo "FIPS-approved certificate operations:"
echo "  ✓ RSA 2048/3072/4096 bit keys"
echo "  ✓ ECDSA P-256/384/521 keys"
echo "  ✓ SHA-256/384/512 signatures"
echo "  ✓ AES-128/256-GCM ciphers"
echo
echo "Blocked operations:"
echo "  ✗ MD5 (any use)"
echo "  ✗ SHA-1 signatures"
echo "  ✗ RSA < 2048 bits"
echo "  ✗ RC4, DES, 3DES"
