#!/usr/bin/env bash
#=============================================================================
# Lab 16: Rollback
# Quickly roll back to previous certificates
#
# Usage: ./rollback.sh
# Prerequisites: RHEL 7, 8, 9, 10, root privileges
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

CERT_DIR="/etc/pki/tls/certs"
KEY_DIR="/etc/pki/tls/private"

print_header "Lab 16: Rollback Certificate Changes"

# Check if running as root
if [[ ${EUID} -ne 0 ]]; then
  error_exit "Error: This script must be run as root (use sudo)"
  exit 1
fi

print_info "Searching for backup files..."
echo

# Find .backup and .old files
echo "Certificate backups:"
if ! find "${CERT_DIR}" -name "*.backup" -o -name "*.old" 2>/dev/null; then
  echo "None found"
fi
echo

echo "Private key backups:"
if ! find "${KEY_DIR}" -name "*.backup" -o -name "*.old" 2>/dev/null; then
  echo "None found"
fi
echo

read -p "Enter certificate file to rollback (without .backup/.old): " CERT_BASE

if [[ -z "${CERT_BASE}" ]]; then
  echo "No file specified"
  exit 1
fi

# Try to find backup
BACKUP_FILE=""
if [[ -f "${CERT_DIR}/${CERT_BASE}.backup" ]]; then
  BACKUP_FILE="${CERT_DIR}/${CERT_BASE}.backup"
elif [[ -f "${CERT_DIR}/${CERT_BASE}.old" ]]; then
  BACKUP_FILE="${CERT_DIR}/${CERT_BASE}.old"
else
  print_error "No backup found for ${CERT_BASE}"
  exit 1
fi

echo
echo "Found backup: ${BACKUP_FILE}"
echo
echo "Backup certificate info:"
if ! openssl x509 -in "${BACKUP_FILE}" -noout -subject -dates 2>/dev/null; then
  echo "Could not read certificate"
fi
echo

read -p "Rollback to this certificate? (y/N): " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
  echo "Rollback cancelled"
  exit 0
fi

echo
print_info "Rolling back..."

# Save current as .rollback
if [[ -f "${CERT_DIR}/${CERT_BASE}" ]]; then
  cp "${CERT_DIR}/${CERT_BASE}" "${CERT_DIR}/${CERT_BASE}.rollback"
  print_success "Current saved as ${CERT_BASE}.rollback"
fi

# Restore backup
cp "${BACKUP_FILE}" "${CERT_DIR}/${CERT_BASE}"
print_success "Certificate rolled back"

# Try to rollback key too
KEY_BASE="${CERT_BASE%.crt}.key"
if [[ -f "${KEY_DIR}/${KEY_BASE}.backup" ]]; then
  cp "${KEY_DIR}/${KEY_BASE}" "${KEY_DIR}/${KEY_BASE}.rollback" 2>/dev/null || true
  cp "${KEY_DIR}/${KEY_BASE}.backup" "${KEY_DIR}/${KEY_BASE}"
  chmod 600 "${KEY_DIR}/${KEY_BASE}"
  print_success "Private key rolled back"
elif [[ -f "${KEY_DIR}/${KEY_BASE}.old" ]]; then
  cp "${KEY_DIR}/${KEY_BASE}" "${KEY_DIR}/${KEY_BASE}.rollback" 2>/dev/null || true
  cp "${KEY_DIR}/${KEY_BASE}.old" "${KEY_DIR}/${KEY_BASE}"
  chmod 600 "${KEY_DIR}/${KEY_BASE}"
  print_success "Private key rolled back"
fi

echo
print_success "Rollback complete"
echo
echo "Restart services to apply changes"
echo
echo "If rollback didn't work, restore from .rollback files:"
echo "  cp ${CERT_DIR}/${CERT_BASE}.rollback ${CERT_DIR}/${CERT_BASE}"
