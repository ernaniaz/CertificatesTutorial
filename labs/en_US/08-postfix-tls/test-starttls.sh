#!/usr/bin/env bash
#=============================================================================
# Lab 08: Test STARTTLS
# Test STARTTLS capability
#
# Usage: ./test-starttls.sh
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

print_header "Lab 08: Testing STARTTLS (Port 25)"

# Test basic SMTP connection
print_info "Testing SMTP connection on port 25..."
if timeout 5 bash -c "echo QUIT | nc localhost 25" 2>/dev/null | grep -q "220"; then
  print_success "SMTP port 25 responding"
else
  print_error "Cannot connect to port 25"
  exit 1
fi

echo

# Test STARTTLS capability
print_info "Testing STARTTLS capability..."
EHLO_RESPONSE="$(timeout 5 bash -c "echo -e 'EHLO localhost\nQUIT' | nc localhost 25" 2>/dev/null)"

if echo "${EHLO_RESPONSE}" | grep -q "STARTTLS"; then
  print_success "STARTTLS advertised"
else
  print_error "STARTTLS not advertised"
  echo "EHLO response:"
  echo "${EHLO_RESPONSE}"
  exit 1
fi

echo

# Test STARTTLS handshake
print_info "Testing STARTTLS handshake..."
STARTTLS_TEST="$(echo "QUIT" | openssl s_client -connect localhost:25 -starttls smtp -brief 2>&1)"

if echo "${STARTTLS_TEST}" | grep -q "Cipher\|Protocol"; then
  print_success "STARTTLS handshake successful"

  # Extract protocol and cipher
  PROTOCOL="$(echo "${STARTTLS_TEST}" | grep "Protocol" | head -1)"
  CIPHER="$(echo "${STARTTLS_TEST}" | grep "Cipher" | head -1)"

  if [[ -n "${PROTOCOL}" ]]; then
    echo " ${PROTOCOL}"
  fi
  if [[ -n "${CIPHER}" ]]; then
    echo " ${CIPHER}"
  fi
else
  print_warning "Could not extract TLS details, but connection may work"
fi

echo

# Test certificate
print_info "Testing certificate..."
CERT_INFO="$(echo "QUIT" | openssl s_client -connect localhost:25 -starttls smtp 2>&1)"

if echo "${CERT_INFO}" | grep -q "Server certificate"; then
  print_success "Certificate presented"

  # Extract subject
  SUBJECT="$(echo "${CERT_INFO}" | grep "subject=" | head -1)"
  if [[ -n "${SUBJECT}" ]]; then
    echo " ${SUBJECT}"
  fi

  # Extract validity
  echo "${CERT_INFO}" | grep -E "Not Before|Not After" | head -2 | sed 's/^/  /'
else
  print_warning "Could not extract certificate details"
fi

echo
print_success "STARTTLS testing complete"
echo
echo "Manual test command:"
echo "  openssl s_client -connect localhost:25 -starttls smtp"
