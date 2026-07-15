#!/usr/bin/env bash
#=============================================================================
# Lab 17: Assess Rhel7
# Pre-migration assessment
#
# Usage: ./assess-rhel7.sh
# Prerequisites: RHEL 7
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
if [[ ${RHEL_VERSION} -ne 7 ]]; then
  error_exit "Unsupported RHEL version. This script requires RHEL 7 only."
fi

#=============================================================================
# MAIN
#=============================================================================

print_header "Lab 17: RHEL 7 Certificate Assessment"

print_info "1. System Version:"
cat /etc/redhat-release
echo

print_info "2. Installed Certificates:"
echo "System certificates in /etc/pki/tls/certs:"
ls -lh /etc/pki/tls/certs/*.crt /etc/pki/tls/certs/*.pem 2>/dev/null | wc -l | xargs echo "  Certificate files:"

echo
echo "Checking for SHA-1 certificates..."
SHA1_COUNT=0
for cert in /etc/pki/tls/certs/*.crt /etc/pki/tls/certs/*.pem; do
  if [[ -f "${cert}" ]]; then
    if openssl x509 -in "${cert}" -noout -text 2>/dev/null | grep -q "sha1WithRSAEncryption"; then
      echo -e " ${YELLOW}⚠ SHA-1: $(basename "${cert}")${NC}"
      ((SHA1_COUNT+=1))
    fi
  fi
done

if [[ ${SHA1_COUNT} -eq 0 ]]; then
  echo -e " ${GREEN}✓ No SHA-1 certificates found${NC}"
else
  echo -e " ${RED}✗ Found ${SHA1_COUNT} SHA-1 certificates (will need replacement in RHEL 8)${NC}"
fi

echo

print_info "3. Services Using Certificates:"
SERVICES=("httpd" "nginx" "postfix" "slapd" "postgresql")
for svc in "${SERVICES[@]}"; do
  if systemctl list-unit-files | grep -q "^${svc}.service"; then
    STATUS="$(systemctl is-active ${svc} 2>/dev/null || echo "inactive")"
    if [[ ${STATUS} == active ]]; then
      echo -e " ${GREEN}✓${svc} (active)${NC}"
    else
      echo "   ${svc} (inactive)"
    fi
  fi
done

echo

print_info "4. TLS Configurations:"
echo "Apache configurations with SSL:"
grep -r "SSLProtocol\|SSLCipherSuite" /etc/httpd/conf* 2>/dev/null | wc -l | xargs echo "  Manual TLS configs:"

echo

print_info "5. Trust Store:"
CA_COUNT="$(ls /etc/pki/ca-trust/source/anchors/*.crt 2>/dev/null | wc -l)"
echo "  Custom CA certificates: ${CA_COUNT}"

echo

print_info "Assessment Summary:"
echo "  RHEL 7 system ready for migration assessment"
echo
print_warning "Pre-Migration Actions Needed:"
echo "  1. Backup all certificates"
if [[ ${SHA1_COUNT} -gt 0 ]]; then
  echo "  2. Replace SHA-1 certificates before migration"
fi
echo "  3. Document service configurations"
echo "  4. Test current functionality"
echo
echo "Next step: Run ./backup-certificates.sh"
