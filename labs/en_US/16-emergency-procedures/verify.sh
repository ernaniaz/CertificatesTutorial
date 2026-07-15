#!/usr/bin/env bash
#=============================================================================
# Lab 16: Verify
# Verification steps
#
# Usage: ./verify.sh
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

print_header "Lab 16: Emergency Procedures Verification"

print_info "1. Checking emergency scripts..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS=(
  "emergency-replacement.sh"
  "self-signed-temp.sh"
  "restore-backup.sh"
  "rollback.sh"
)

for script in "${SCRIPTS[@]}"; do
  if [[ -f "${SCRIPT_DIR}/${script}" && -x "${SCRIPT_DIR}/${script}" ]]; then
    print_success "${script}"
  else
    echo " ${script} (not found or not executable)"
  fi
done

echo

print_info "2. Checking certificate directories..."
for dir in /etc/pki/tls/certs /etc/pki/tls/private; do
  if [[ -d "${dir}" ]]; then
    print_success "${dir}"
  else
    echo " ${dir} (not found)"
  fi
done

echo

print_info "3. Checking for backups..."
BACKUP_COUNT="$(ls -d /root/cert-backup-* 2>/dev/null | wc -l)"
echo "  Found ${BACKUP_COUNT} backup directories"

echo

print_info "4. Checking for emergency certificates..."
for cert in /etc/pki/tls/certs/emergency.crt /etc/pki/tls/certs/temp-*.crt; do
  if [[ -f "${cert}" ]]; then
    echo "  $(basename "${cert}")"
    openssl x509 -in "${cert}" -noout -subject -dates 2>/dev/null | sed 's/^/    /'
  fi
done

echo
print_success "Verification complete"
echo
echo "Emergency procedures ready"
