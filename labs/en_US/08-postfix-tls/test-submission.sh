#!/usr/bin/env bash
#=============================================================================
# Lab 08: Test Submission
# Test submission port with mandatory TLS
#
# Usage: ./test-submission.sh
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

print_header "Lab 08: Testing Submission Port (587)"

# Test submission port listening
print_info "Testing submission port 587..."
if ss -tlnp | grep -q ':587'; then
  print_success "Port 587 listening"
else
  print_error "Port 587 not listening"
  echo "Check master.cf configuration"
  exit 1
fi

echo

# Test EHLO on submission port
print_info "Testing EHLO on submission port..."
EHLO_RESPONSE="$(timeout 5 bash -c "echo -e 'EHLO localhost\nQUIT' | nc localhost 587" 2>/dev/null)"

if echo "${EHLO_RESPONSE}" | grep -q "220"; then
  print_success "Submission port responding"
else
  print_error "Submission port not responding correctly"
  exit 1
fi

# Check for STARTTLS
if echo "${EHLO_RESPONSE}" | grep -q "STARTTLS"; then
  print_success "STARTTLS available"
fi

# Check for AUTH
if echo "${EHLO_RESPONSE}" | grep -q "AUTH"; then
  print_success "AUTH methods advertised"
fi

echo

# Test TLS connection on submission port
print_info "Testing TLS on submission port..."
TLS_TEST="$(echo "QUIT" | openssl s_client -connect localhost:587 -starttls smtp -brief 2>&1)"

if echo "${TLS_TEST}" | grep -q "Cipher\|Protocol"; then
  print_success "TLS connection successful"

  # Extract protocol
  PROTOCOL="$(echo "${TLS_TEST}" | grep "Protocol" | head -1)"
  if [[ -n "${PROTOCOL}" ]]; then
    echo " ${PROTOCOL}"
  fi

  # Extract cipher
  CIPHER="$(echo "${TLS_TEST}" | grep "Cipher" | head -1)"
  if [[ -n "${CIPHER}" ]]; then
    echo " ${CIPHER}"
  fi
else
  print_warning "TLS test inconclusive"
fi

echo

# Check TLS security level
print_info "Checking TLS security level..."
TLS_LEVEL="$(postconf -h smtpd_tls_security_level 2>/dev/null || echo "not set")"
echo "  smtpd_tls_security_level: ${TLS_LEVEL}"

# Check if submission has encrypt requirement
if grep -q "smtpd_tls_security_level=encrypt" /etc/postfix/master.cf; then
  print_success "Submission port requires encryption"
else
  print_warning "Submission port may not require encryption"
fi

echo
print_success "Submission port testing complete"
echo
echo "Manual test commands:"
echo "  openssl s_client -connect localhost:587 -starttls smtp"
echo "  telnet localhost 587"
