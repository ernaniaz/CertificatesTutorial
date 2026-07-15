#!/usr/bin/env bash
#=============================================================================
# Lab 19: Test Fips Compliance
# Test certificate operations in FIPS mode
#
# Usage: ./test-fips-compliance.sh
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

OUTPUT_DIR="/tmp/fips-test-$(date +%s)"

print_header "Lab 19: FIPS Compliance Testing"

# Create output directory
mkdir -p "${OUTPUT_DIR}"
cd "${OUTPUT_DIR}"

print_info "1. Testing FIPS-compliant key generation..."

# RSA 2048 (should work)
if openssl genrsa -out rsa2048.key 2048 2>/dev/null; then
  echo -e " ${GREEN}✓ RSA 2048-bit key generated${NC}"
else
  echo -e " ${RED}✗ RSA 2048 failed${NC}"
fi

# RSA 1024 (should fail in FIPS)
if openssl genrsa -out rsa1024.key 1024 2>/dev/null; then
  echo -e " ${YELLOW}⚠ RSA 1024-bit succeeded (FIPS may not be active)${NC}"
else
  echo -e " ${GREEN}✓ RSA 1024 correctly blocked${NC}"
fi

echo

print_info "2. Testing FIPS-compliant certificate generation..."

# SHA-256 (should work)
if openssl req -x509 -newkey rsa:2048 -sha256 -nodes \
  -keyout sha256.key -out sha256.crt -days 30 \
  -subj "/CN=fips-test" 2>/dev/null; then
  echo -e " ${GREEN}✓ SHA-256 certificate created${NC}"
else
  echo -e " ${RED}✗ SHA-256 certificate failed${NC}"
fi

echo

print_info "3. Testing blocked algorithms..."

# MD5 (should fail)
if echo "test" | openssl dgst -md5 >/dev/null 2>&1; then
  echo -e " ${YELLOW}⚠ MD5 works (FIPS may not be enforcing)${NC}"
else
  echo -e " ${GREEN}✓ MD5 correctly blocked${NC}"
fi

# SHA-1 (should fail for signatures in FIPS)
if echo "test" | openssl dgst -sha1 >/dev/null 2>&1; then
  echo -e " ${YELLOW}⚠ SHA-1 hash works (allowed for hashing, not signatures)${NC}"
else
  echo -e " ${GREEN}✓ SHA-1 blocked${NC}"
fi

echo

print_info "4. Testing TLS compliance..."

# Check available ciphers
CIPHER_COUNT="$(openssl ciphers -v 2>/dev/null | wc -l)"
echo "  Available ciphers: ${CIPHER_COUNT}"
echo "  (FIPS mode restricts to approved ciphers only)"

echo

# Display FIPS-approved ciphers (sample)
echo "  Sample FIPS ciphers:"
if ! openssl ciphers -v 'FIPS' 2>/dev/null | head -5 | sed 's/^/    /'; then
  echo "    Could not list FIPS ciphers"
fi

echo

# Cleanup
cd /
rm -rf "${OUTPUT_DIR}"

print_success "FIPS compliance testing complete"
echo

if [[ -f /proc/sys/crypto/fips_enabled && "$(cat /proc/sys/crypto/fips_enabled)" == "1" ]]; then
  print_success "System is FIPS compliant"
else
  print_warning "System is NOT in FIPS mode"
fi
