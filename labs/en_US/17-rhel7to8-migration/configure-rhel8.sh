#!/usr/bin/env bash
#=============================================================================
# Lab 17: Configure Rhel8
# Certificate configuration on upgraded RHEL 8
#
# Usage: ./configure-rhel8.sh
# Prerequisites: RHEL 8, root privileges
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
if [[ ${RHEL_VERSION} -ne 8 ]]; then
  error_exit "Unsupported RHEL version. This script requires RHEL 8 only."
fi

#=============================================================================
# MAIN
#=============================================================================

print_header "Lab 17: RHEL 8 Post-Upgrade Configuration"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

# Check current crypto-policy
print_info "1. Checking crypto-policy..."
POLICY="$(update-crypto-policies --show 2>/dev/null || echo "UNKNOWN")"
echo "  Current policy: ${POLICY}"

if [[ ${POLICY} == DEFAULT ]]; then
  echo -e " ${GREEN}✓ Using DEFAULT policy${NC}"
elif [[ ${POLICY} == LEGACY ]]; then
  echo -e " ${YELLOW}⚠ Using LEGACY policy (for compatibility)${NC}"
fi

echo

# Update service configurations
print_info "2. Updating service configurations..."

# Apache
if [[ -d /etc/httpd/conf.d ]]; then
  echo "  Checking Apache configs..."
  if grep -r "^[^#]*SSLProtocol" /etc/httpd/conf* 2>/dev/null | grep -q .; then
    echo -e "   ${YELLOW}⚠ Found manual SSLProtocol directives${NC}"
    echo "      Consider removing to use crypto-policies"
  else
    echo -e "   ${GREEN}✓ No manual TLS protocol settings${NC}"
  fi
fi

# NGINX
if [[ -d /etc/nginx ]]; then
  echo "  Checking NGINX configs..."
  if grep -r "ssl_protocols" /etc/nginx/ 2>/dev/null | grep -v "^#" | grep -q .; then
    echo -e "   ${YELLOW}⚠ Found manual ssl_protocols directives${NC}"
    echo "      NGINX still requires explicit protocol settings"
  fi
fi

echo

# Verify certificates
print_info "3. Verifying certificates..."
CERT_COUNT=0
VALID_COUNT=0

for cert in /etc/pki/tls/certs/*.crt; do
  if [[ -f "${cert}" ]]; then
    ((CERT_COUNT+=1))
    if openssl x509 -in "${cert}" -noout -checkend 0 2>/dev/null; then
      ((VALID_COUNT+=1))
    fi
  fi
done

echo "  Total certificates: ${CERT_COUNT}"
echo "  Valid certificates: ${VALID_COUNT}"

if [[ ${CERT_COUNT} -eq ${VALID_COUNT} ]]; then
  echo -e " ${GREEN}✓ All certificates valid${NC}"
else
  echo -e " ${RED}✗ Some certificates expired or invalid${NC}"
fi

echo

# Test services
print_info "4. Testing services..."
SERVICES=("httpd" "nginx" "postfix")
for svc in "${SERVICES[@]}"; do
  if systemctl is-active ${svc} &>/dev/null; then
    echo -e " ${GREEN}✓ ${svc} running${NC}"
  elif systemctl list-unit-files | grep -q "^${svc}.service"; then
    echo -e " ${YELLOW}⚠ ${svc} installed but not running${NC}"
  fi
done

echo

print_success "RHEL 8 post-upgrade configuration complete"
echo
echo "Next steps:"
echo "  1. Test all services thoroughly"
echo "  2. Run ./validate-migration.sh"
echo "  3. Monitor logs for issues"
echo
echo "If compatibility issues arise:"
echo "  sudo update-crypto-policies --set LEGACY"
