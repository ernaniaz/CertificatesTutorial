#!/usr/bin/env bash
#=============================================================================
# Lab 18: Check Compatibility
# Identify potential issues
#
# Usage: ./check-compatibility.sh
# Prerequisites: RHEL 8
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

print_header "Lab 18: RHEL 9 Compatibility Check"

ISSUES=0
WARNINGS=0

print_info "Compatibility Analysis:"
echo

# Check 1: OpenSSL version
echo -n "1. OpenSSL 1.1.1 detected: "
if openssl version | grep -q "1.1.1"; then
  print_success ""
else
  print_warning "(unexpected version)"
fi

# Check 2: Certificates with SANs
echo -n "2. Certificates have SANs: "
SANS_OK=0
SANS_TOTAL=0
for cert in /etc/pki/tls/certs/*.crt; do
  if [[ -f "${cert}" ]] && openssl x509 -in "${cert}" -noout -text >/dev/null 2>&1; then
    ((SANS_TOTAL+=1))
    if openssl x509 -in "${cert}" -noout -ext subjectAltName 2>/dev/null | grep -q "DNS:"; then
      ((SANS_OK+=1))
    fi
  fi
done

if [[ ${SANS_TOTAL} -eq 0 ]]; then
  print_warning "N/A"
elif [[ ${SANS_OK} -eq ${SANS_TOTAL} ]]; then
  print_success ""
else
  print_warning "(${SANS_OK}/${SANS_TOTAL})"
  ((WARNINGS+=1))
fi

# Check 3: Key sizes
echo -n "3. Strong key sizes (2048+): "
WEAK_COUNT=0
for cert in /etc/pki/tls/certs/*.crt; do
  if [[ -f "${cert}" ]]; then
    KEY_SIZE="$(openssl x509 -in "${cert}" -noout -text 2>/dev/null | grep "Public-Key:" | grep -oP '\d+' | head -1)"
    if [[ -n "${KEY_SIZE}" && ${KEY_SIZE} -lt 2048 ]]; then
      ((WEAK_COUNT+=1))
    fi
  fi
done

if [[ ${WEAK_COUNT} -eq 0 ]]; then
  print_success ""
else
  print_error "(${WEAK_COUNT} weak keys)"
  ((ISSUES+=1))
fi

# Check 4: No SHA-1
echo -n "4. No SHA-1 signatures: "
SHA1_COUNT=0
for cert in /etc/pki/tls/certs/*.crt; do
  if [[ -f "${cert}" ]] && openssl x509 -in "${cert}" -noout -text 2>/dev/null | grep -q "sha1WithRSAEncryption"; then
    ((SHA1_COUNT+=1))
  fi
done

if [[ ${SHA1_COUNT} -eq 0 ]]; then
  print_success ""
else
  print_error "(${SHA1_COUNT} SHA-1 certs)"
  ((ISSUES+=1))
fi

echo

print_info "RHEL 9 Changes to Expect:"
echo "  - OpenSSL 3.x (provider architecture)"
echo "  - Stricter certificate validation"
echo "  - SANs required (CN-only deprecated)"
echo "  - Legacy algorithms need explicit enabling"
echo

if [[ ${ISSUES} -eq 0 && ${WARNINGS} -eq 0 ]]; then
  print_success "System appears ready for RHEL 9"
elif [[ ${ISSUES} -eq 0 ]]; then
  print_warning "Minor issues: ${WARNINGS} warnings"
  echo "  Review warnings before migration"
else
  print_error "Critical issues: ${ISSUES}"
  echo "  Resolve before migrating to RHEL 9"
fi
