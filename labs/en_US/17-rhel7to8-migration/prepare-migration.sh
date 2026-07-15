#!/usr/bin/env bash
#=============================================================================
# Lab 17: Prepare Migration
# Migration readiness verification
#
# Usage: ./prepare-migration.sh
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

print_header "Lab 17: Migration Preparation"

ISSUES=0

print_info "Migration Readiness Checklist:"
echo

# Check 1: Backup exists
echo -n "1. Certificate backup created: "
if ls /root/rhel7-cert-backup-*.tar.gz 2>/dev/null | grep -q .; then
  print_success ""
else
  print_error "(run ./backup-certificates.sh)"
  ((ISSUES+=1))
fi

# Check 2: SHA-1 certificates
echo -n "2. No SHA-1 certificates: "
SHA1_FOUND=0
for cert in /etc/pki/tls/certs/*.crt; do
  if [[ -f "${cert}" ]] && openssl x509 -in "${cert}" -noout -text 2>/dev/null | grep -q "sha1WithRSAEncryption"; then
    SHA1_FOUND=1
    break
  fi
done

if [[ ${SHA1_FOUND} -eq 0 ]]; then
  print_success ""
else
  print_warning "(SHA-1 certs should be replaced)"
fi

# Check 3: Certificates not expired
echo -n "3. All certificates valid: "
EXPIRED=0
for cert in /etc/pki/tls/certs/*.crt; do
  if [[ -f "${cert}" ]] && ! openssl x509 -in "${cert}" -noout -checkend 0 2>/dev/null; then
    EXPIRED=1
    break
  fi
done

if [[ ${EXPIRED} -eq 0 ]]; then
  print_success ""
else
  print_error "(expired certificates found)"
  ((ISSUES+=1))
fi

# Check 4: Services documented
echo -n "4. Service configurations backed up: "
if ls /root/rhel7-cert-backup-*/configs/ 2>/dev/null | grep -q .; then
  print_success ""
else
  print_warning "(recommended)"
fi

echo
print_info "Known Compatibility Issues:"
echo
echo "TLS 1.0/1.1:"
echo "  - RHEL 8 disables by default"
echo "  - Use LEGACY policy if old clients needed"
echo
echo "SHA-1 Signatures:"
echo "  - Blocked in DEFAULT policy"
echo "  - Replace or use LEGACY policy"
echo
echo "Manual TLS Configs:"
echo "  - Remove SSLProtocol directives"
echo "  - Remove SSLCipherSuite directives"
echo "  - Let crypto-policies handle these"
echo

if [[ ${ISSUES} -eq 0 ]]; then
  print_success "System ready for migration to RHEL 8"
else
  print_error "Resolve ${ISSUES} critical issues before migration"
fi

echo
echo "After RHEL 8 upgrade, run: ./configure-rhel8.sh"
