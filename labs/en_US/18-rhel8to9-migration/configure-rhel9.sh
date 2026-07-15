#!/usr/bin/env bash
#=============================================================================
# Lab 18: Configure Rhel9
# OpenSSL 3.x configuration on upgraded RHEL 9
#
# Usage: ./configure-rhel9.sh
# Prerequisites: RHEL 9, root privileges
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
if [[ ${RHEL_VERSION} -ne 9 ]]; then
  error_exit "Unsupported RHEL version. This script requires RHEL 9 only."
fi

#=============================================================================
# MAIN
#=============================================================================

print_header "Lab 18: RHEL 9 Post-Upgrade Configuration"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

# Check OpenSSL version
print_info "1. Verifying OpenSSL 3.x..."
OPENSSL_VERSION="$(openssl version)"
echo " ${OPENSSL_VERSION}"

if echo "${OPENSSL_VERSION}" | grep -q "OpenSSL 3"; then
  echo -e " ${GREEN}✓ OpenSSL 3.x detected${NC}"
else
  echo -e " ${YELLOW}⚠ Unexpected OpenSSL version${NC}"
fi

echo

# Check crypto-policy
print_info "2. Checking crypto-policy..."
POLICY="$(update-crypto-policies --show 2>/dev/null)"
echo "  Current: ${POLICY}"

echo

# Check certificates
print_info "3. Validating certificates with OpenSSL 3.x..."
CERT_ERRORS=0

for cert in /etc/pki/tls/certs/*.crt; do
  if [[ -f "${cert}" ]]; then
    if ! openssl x509 -in "${cert}" -noout 2>/dev/null; then
      echo -e " ${RED}✗ $(basename "${cert}")${NC}"
      ((CERT_ERRORS+=1))
    fi
  fi
done

if [[ ${CERT_ERRORS} -eq 0 ]]; then
  echo -e " ${GREEN}✓ All certificates valid under OpenSSL 3.x${NC}"
else
  echo -e " ${RED}✗ ${CERT_ERRORS} certificates have issues${NC}"
fi

echo

# Check for legacy provider need
print_info "4. Checking legacy algorithm usage..."
if [[ -f /etc/pki/tls/openssl.cnf ]] && grep -qP '^[^#]*legacy\s*=' /etc/pki/tls/openssl.cnf; then
  echo -e " ${YELLOW}⚠ Legacy provider enabled${NC}"
  echo "    Review if still needed"
else
  echo -e " ${GREEN}✓ Using default provider only${NC}"
fi

echo

# Test services
print_info "5. Testing services..."
for svc in httpd nginx postfix; do
  if systemctl is-active ${svc} &>/dev/null; then
    echo -e " ${GREEN}✓ ${svc} running${NC}"
  elif systemctl list-unit-files | grep -q "^${svc}.service"; then
    echo -e " ${YELLOW}⚠ ${svc} installed but not running${NC}"
  fi
done

echo

print_success "RHEL 9 post-upgrade configuration review complete"
echo
echo "Next steps:"
echo "  1. Test all TLS connections"
echo "  2. Run ./validate-migration.sh"
echo "  3. Monitor for deprecation warnings"
echo

if [[ ${CERT_ERRORS} -gt 0 ]]; then
  print_warning "Certificate issues detected"
  echo "Consider regenerating affected certificates"
fi
